/*
 * The native side of ent_audio: miniaudio, compiled here, and a small Web Audio graph on top of it, which the Dart
 * bindings drive (lib/src/bindings.dart).
 *
 * The graph renders in quanta of 128 frames, as Web Audio does. Each node renders at most once per quantum, pulled
 * by the nodes it feeds; the destination pulls the graph, and every started source renders even when nothing pulls
 * it, so that its playhead moves and it ends on time. Dart calls and rendering take the context's lock in turn.
 *
 * Nodes belong to their context. A node whose Dart handle is gone is freed once it can no longer be heard: a source
 * that has ended or can no longer start. Buffers are counted: a buffer lives while a Dart handle or a source holds it.
 */

#include <float.h>
#include <limits.h>
#include <math.h>

#define MINIAUDIO_IMPLEMENTATION
#include "../third_party/miniaudio/miniaudio.h"

#if defined(_WIN32)
#define ENT_EXPORT __declspec(dllexport)
#else
#define ENT_EXPORT __attribute__((visibility("default")))
#endif

#define ENT_QUANTUM 128
#define ENT_CHANNELS 8

/* Decoded or created audio: `channels` planes of `length` frames, one after another. */
typedef struct ent_buffer {
	int32_t references;
	uint32_t channels;
	uint32_t rate;
	uint64_t length;
	float *data;
} ent_buffer;

enum { ENT_DESTINATION, ENT_SOURCE, ENT_GAIN, ENT_PANNER, ENT_LISTENER, ENT_ANALYSER };

enum { ENT_UNSCHEDULED, ENT_SCHEDULED, ENT_PLAYING, ENT_FINISHED };

/* The parameters of a node: indices into ent_node.params. */
enum { ENT_PLAYBACK_RATE = 0, ENT_DETUNE = 1, ENT_GAIN_VALUE = 0 };

enum { ENT_SET_VALUE, ENT_LINEAR_RAMP, ENT_SET_TARGET };

/* A panner's distance models. */
enum { ENT_LINEAR, ENT_INVERSE, ENT_EXPONENTIAL };

/* An automation event; `fresh` marks one inserted since the last rendering, whose time may still be clamped. */
typedef struct ent_event {
	int type;
	int fresh;
	float value;
	double time;
	double constant;
} ent_event;

/* A parameter: its value between quanta, its range, whether it changes per frame, and its automation events. */
typedef struct ent_param {
	float value;
	float min;
	float max;
	int audio;
	ent_event *events;
	uint32_t count;
	uint32_t capacity;
} ent_param;

/* An analyser's ring of the latest frames, its FFT size and its last analysis: magnitudes and when it was made. */
#define ENT_RING 32768

typedef struct ent_analysis {
	float ring[ENT_RING];
	uint32_t write;
	uint32_t size;
	float *magnitudes;
	double time;
} ent_analysis;

typedef struct ent_context ent_context;
typedef struct ent_node ent_node;

struct ent_node {
	ent_context *context;
	int kind;
	int32_t id;
	int held;
	ent_node **inputs;
	uint32_t inputCount;
	uint32_t inputCapacity;

	/* The last quantum rendered, plus one, and its output. */
	uint64_t quantum;
	uint32_t channels;
	float output[ENT_CHANNELS][ENT_QUANTUM];

	ent_param params[9];

	/* A source: its buffer, loop, schedule (in seconds) and playhead (in buffer frames). */
	ent_buffer *buffer;
	int loop;
	double loopStart;
	double loopEnd;
	int state;
	int reported;
	double start;
	double offset;
	double duration;
	double stop;
	double index;
	double played;

	/* A panner: its distance model and cone. */
	int distanceModel;
	double refDistance;
	double maxDistance;
	double rolloffFactor;
	double coneInnerAngle;
	double coneOuterAngle;
	double coneOuterGain;

	/* An analyser: its ring of frames and its last analysis. */
	ent_analysis *analysis;
};

struct ent_context {
	ma_mutex lock;
	int32_t references;
	uint32_t rate;
	uint32_t channels;
	uint64_t quantum;
	ent_node *destination;

	/* The listener, as a node outside the graph holding its nine parameters, and their values in this quantum. */
	ent_node *listener;
	float listenerValues[9][ENT_QUANTUM];
	ent_node **nodes;
	uint32_t count;
	uint32_t capacity;
	int32_t next;
	void (*ended)(int32_t id);
};

/*
 * Parameter automation, following Chromium's AudioParam timeline for the events ent uses (setting the value, linear
 * ramps and approaches to a target): the same event list, the same rules for events in the past, and the same
 * arithmetic, so that values equal Chrome's. The caller holds the context's lock.
 */

/* Constants of Chromium's timeline: a target is reached after ten time constants, or within exp(-10) of it. */
#define ENT_CONVERGE 10.0f
#define ENT_THRESHOLD 4.539992976248485e-05f

static void ent_param_init(ent_param *param, float value, int audio) {
	param->value = value;
	param->min = -FLT_MAX;
	param->max = FLT_MAX;
	param->audio = audio;
}

static float ent_param_clamp(const ent_param *param, float value) {
	return fminf(fmaxf(value, param->min), param->max);
}

/* Removes the first `count` events, always leaving one. */
static void ent_param_remove(ent_param *param, uint32_t count) {
	if (param->count <= 1) {
		return;
	}

	uint32_t removed = count < param->count - 1 ? count : param->count - 1;
	memmove(param->events, param->events + removed, (param->count - removed) * sizeof(ent_event));
	param->count -= removed;
}

/* Whether `event` still applies at `frame`, given the event after it. */
static int ent_event_current(const ent_event *event, const ent_event *next, double frame, double rate) {
	if (next == NULL) {
		return 1;
	}

	if (next->time * rate >= frame) {
		return 1;
	}

	double at = event->time * rate;

	if (event->type != ENT_SET_VALUE) {
		return 0;
	}

	return at <= frame && frame < at + 1;
}

static int ent_param_converged(float value, float target, double time, double start, double constant) {
	if (time > start + ENT_CONVERGE * constant) {
		return 1;
	}

	if (target == 0) {
		return fabsf(value) < ENT_THRESHOLD;
	}

	return fabsf(target - value) < ENT_THRESHOLD * fabsf(value);
}

static int ent_param_put(ent_param *param, uint32_t index, ent_event event) {
	if (param->count == param->capacity) {
		uint32_t capacity = param->capacity ? param->capacity * 2 : 8;
		ent_event *events = ma_realloc(param->events, capacity * sizeof(ent_event), NULL);

		if (events == NULL) {
			return MA_OUT_OF_MEMORY;
		}

		param->events = events;
		param->capacity = capacity;
	}

	memmove(param->events + index + 1, param->events + index, (param->count - index) * sizeof(ent_event));
	event.fresh = 1;
	param->events[index] = event;
	param->count++;
	return 0;
}

/* Inserts an event after the events at the same time or earlier, dropping the events that no longer apply. */
static int ent_param_insert(ent_context *context, ent_param *param, ent_event event, float initial) {
	double frame = (double)(context->quantum * ENT_QUANTUM);
	double now = frame / context->rate;
	uint32_t skipped = 0;

	for (uint32_t i = 0; i < param->count; i++) {
		const ent_event *next = i + 1 < param->count ? &param->events[i + 1] : NULL;

		if (ent_event_current(&param->events[i], next, frame, context->rate)) {
			break;
		}

		skipped++;
	}

	ent_param_remove(param, skipped);

	/* A ramp with nothing before it starts from the value it was scheduled at. */
	if (param->count == 0 && event.type == ENT_LINEAR_RAMP) {
		ent_event start = {ENT_SET_VALUE, 0, initial, now, 0};
		int result = ent_param_put(param, 0, start);

		if (result != 0) {
			return result;
		}
	}

	uint32_t index = param->count;

	if (index > 0 && param->events[index - 1].time > event.time) {
		index = 0;

		while (param->events[index].time <= event.time) {
			index++;
		}
	}

	return ent_param_put(param, index, event);
}

/* Moves fresh events scheduled before `time` to it, keeping the list in time order. */
static void ent_param_clamp_fresh(ent_param *param, double time) {
	int moved = 0;

	for (uint32_t i = 0; i < param->count; i++) {
		ent_event *event = &param->events[i];

		if (event->fresh && event->time < time) {
			event->time = time;
			moved = 1;
		}

		event->fresh = 0;
	}

	if (!moved) {
		return;
	}

	for (uint32_t i = 1; i < param->count; i++) {
		ent_event event = param->events[i];
		uint32_t k = i;

		while (k > 0 && param->events[k - 1].time > event.time) {
			param->events[k] = param->events[k - 1];
			k--;
		}

		param->events[k] = event;
	}
}

static void ent_fill(float *values, size_t from, size_t to, float value) {
	for (size_t i = from; i < to; i++) {
		values[i] = value;
	}
}

/*
 * The parameter's values for frames [start, end), written to `values`; `value` is its value before them. `control` is
 * the rate a target's discrete time constant is computed for: the sample rate, or that of quanta for one value per
 * quantum. Returns the last value.
 */
static float ent_param_values(ent_param *param, size_t start, size_t end, float value, float *values, double rate,
	double control) {
	size_t n = end - start;

	if (param->count == 0 || end / rate <= param->events[0].time) {
		ent_fill(values, 0, n, value);
		return ent_param_clamp(param, values[n - 1]);
	}

	ent_param_clamp_fresh(param, start / rate);

	/* Every event in the past: the value holds, or a target's approach goes on until it converges. */
	ent_event *last = &param->events[param->count - 1];

	if (last->time + 1.5 * ENT_QUANTUM / rate < start / rate) {
		int done = 1;

		if (last->type == ENT_SET_TARGET) {
			if (ent_param_converged(value, last->value, start / rate, last->time, last->constant)) {
				value = last->value;
			} else {
				done = 0;
			}
		}

		if (done) {
			ent_fill(values, 0, n, value);
			ent_param_remove(param, param->count);
			return ent_param_clamp(param, value);
		}
	}

	size_t frame = start;
	size_t written = 0;
	double first = param->events[0].time;

	if (first > start / rate) {
		size_t to = end;
		double at = ceil(first * rate);

		if (end > at) {
			to = (size_t)at;
		}

		written = to - start < n ? to - start : n;
		ent_fill(values, 0, written, value);
		frame += written;
	}

	float current = value;
	uint32_t skipped = 0;

	for (uint32_t i = 0; i < param->count && written < n; i++) {
		ent_event *event = &param->events[i];
		ent_event *next = i + 1 < param->count ? &param->events[i + 1] : NULL;

		if (!ent_event_current(event, next, (double)frame, rate)) {
			skipped++;
			continue;
		}

		/* A target followed by a ramp: the ramp starts where the approach has got to. */
		if (event->type == ENT_SET_TARGET && next != NULL && next->type == ENT_LINEAR_RAMP) {
			double from = fmin(fmax(frame / rate, event->time), next->time);

			if (fabs(2 * rate * event->time - 2.0 * frame + 1) <= 1) {
				current = event->value + (current - event->value) * exp(-(from - event->time) / event->constant);
			} else {
				float discrete = (float)(1 - exp(-1 / (control * event->constant)));
				current += (event->value - current) * discrete;
			}

			ent_event replaced = {ENT_SET_VALUE, 0, current, from, 0};
			*event = replaced;
		}

		float value1 = event->value;
		double time1 = event->time;
		float value2 = next != NULL ? next->value : value1;
		double time2 = next != NULL ? next->time : end / rate + 1;
		size_t fillEnd = end > time2 * rate ? (size_t)ceil(time2 * rate) : end;
		size_t fill = fillEnd - start < n ? fillEnd - start : n;

		if (next != NULL && next->type == ENT_LINEAR_RAMP) {
			double delta = time2 - time1;
			float k = delta <= FLT_MIN ? 0 : (float)(1 / delta);
			float change = value2 - value1;

			for (; written < fill; written++) {
				float x = (float)((frame / rate - time1) * k);
				current = value1 + x * change;
				values[written] = current;
				frame++;
			}

			continue;
		}

		if (event->type != ENT_SET_TARGET) {
			frame = fillEnd;
			current = event->value;
			ent_fill(values, written, fill, current);
			written = fill;
			continue;
		}

		float target = value1;
		float constant = (float)event->constant;
		float discrete = (float)(1 - exp(-1 / (control * constant)));
		double at = time1 * rate;

		if (at <= frame && frame < at + 1) {
			current = target + (current - target) * exp(-(frame / rate - time1) / constant);
		} else {
			current += (target - current) * discrete;
		}

		if (ent_param_converged(current, target, frame / rate, time1, constant)) {
			frame += fill - written;
			ent_fill(values, written, fill, target);
			written = fill;
			continue;
		}

		for (; written < fill; written++) {
			values[written] = current;
			current += (target - current) * discrete;
		}

		if (written >= 1) {
			current = values[written - 1];
		}

		frame = fillEnd;
	}

	ent_param_remove(param, skipped);
	ent_fill(values, written, n, current);

	for (size_t i = 0; i < n; i++) {
		values[i] = ent_param_clamp(param, values[i]);
	}

	return values[n - 1];
}

/* The value of a parameter read once per quantum, at its start, which also becomes the parameter's value. */
static float ent_param_final(ent_context *context, ent_param *param) {
	size_t start = context->quantum * ENT_QUANTUM;
	float value = param->value;

	if (param->count > 0 && (double)start / context->rate >= param->events[0].time) {
		ent_param_values(param, start, start + 1, value, &value, context->rate, (double)context->rate / ENT_QUANTUM);
	}

	param->value = ent_param_clamp(param, value);
	return param->value;
}

/* Whether a parameter changes within the coming quantum, so that it needs a value per frame. */
static int ent_param_accurate(ent_context *context, ent_param *param) {
	if (param->count == 0) {
		return 0;
	}

	double now = (double)(context->quantum * ENT_QUANTUM) / context->rate;
	double later = (double)((context->quantum + 1) * ENT_QUANTUM) / context->rate;
	const ent_event *first = &param->events[0];

	if (first->time > later && first->type != ENT_LINEAR_RAMP) {
		return 0;
	}

	if (param->count >= 2) {
		return 1;
	}

	if (first->type == ENT_SET_TARGET) {
		return first->time <= later;
	}

	return !(first->time < now);
}

/* A value per frame of the coming quantum; the last becomes the parameter's value. */
static void ent_param_timeline(ent_context *context, ent_param *param, float *values) {
	size_t start = context->quantum * ENT_QUANTUM;
	param->value = ent_param_values(param, start, start + ENT_QUANTUM, param->value, values, context->rate,
		context->rate);
}

/*
 * A time in frames, snapped to the nearest whole frame when it is within rounding error of it, so that a time made by
 * dividing a frame count by the rate converts back to that count.
 */
static double ent_frame(double time, double rate) {
	double frame = time * rate;
	double whole = round(frame);

	if (fabs(frame - whole) <= fmax(whole, 1.0) * 10.0 * 2.220446049250313e-16) {
		return whole;
	}

	return frame;
}

/* Adds one hold on a buffer. */
ENT_EXPORT void ent_buffer_retain(ent_buffer *buffer) {
	__atomic_add_fetch(&buffer->references, 1, __ATOMIC_RELAXED);
}

/* Drops one hold on a buffer and frees it with the last one. */
ENT_EXPORT void ent_buffer_release(void *pointer) {
	ent_buffer *buffer = pointer;

	if (__atomic_sub_fetch(&buffer->references, 1, __ATOMIC_ACQ_REL) == 0) {
		ma_free(buffer->data, NULL);
		ma_free(buffer, NULL);
	}
}

/* A silent buffer held once by the caller, or NULL when memory runs out. */
ENT_EXPORT ent_buffer *ent_buffer_create(uint32_t channels, uint64_t length, uint32_t rate) {
	ent_buffer *buffer = ma_malloc(sizeof(ent_buffer), NULL);

	if (buffer == NULL) {
		return NULL;
	}

	buffer->data = ma_calloc(channels * length > 0 ? channels * length * sizeof(float) : 1, NULL);

	if (buffer->data == NULL) {
		ma_free(buffer, NULL);
		return NULL;
	}

	buffer->references = 1;
	buffer->channels = channels;
	buffer->rate = rate;
	buffer->length = length;
	return buffer;
}

ENT_EXPORT float *ent_buffer_data(ent_buffer *buffer) {
	return buffer->data;
}

ENT_EXPORT uint32_t ent_buffer_channels(ent_buffer *buffer) {
	return buffer->channels;
}

ENT_EXPORT uint32_t ent_buffer_rate(ent_buffer *buffer) {
	return buffer->rate;
}

ENT_EXPORT uint64_t ent_buffer_length(ent_buffer *buffer) {
	return buffer->length;
}

/*
 * Decodes WAV, FLAC or MP3 data into a buffer held once by the caller, keeping the file's channels and converting to
 * `rate` (0 keeps the file's rate too). Returns 0 on success, otherwise miniaudio's error code.
 */
ENT_EXPORT int ent_buffer_decode(const void *data, size_t size, uint32_t rate, ent_buffer **out) {
	ma_decoder_config config = ma_decoder_config_init(ma_format_f32, 0, rate);
	ma_decoder decoder;
	ma_result result = ma_decoder_init_memory(data, size, &config, &decoder);

	if (result != MA_SUCCESS) {
		return result;
	}

	uint32_t channels = decoder.outputChannels;
	uint64_t capacity = 4096;
	uint64_t length = 0;
	float *frames = ma_malloc(capacity * channels * sizeof(float), NULL);

	for (;;) {
		if (frames == NULL) {
			ma_decoder_uninit(&decoder);
			return MA_OUT_OF_MEMORY;
		}

		uint64_t read = 0;
		result = ma_decoder_read_pcm_frames(&decoder, frames + length * channels, capacity - length, &read);
		length += read;

		if (result != MA_SUCCESS) {
			break;
		}

		if (length == capacity) {
			capacity *= 2;
			float *grown = ma_realloc(frames, capacity * channels * sizeof(float), NULL);

			if (grown == NULL) {
				ma_free(frames, NULL);
			}

			frames = grown;
		}
	}

	uint32_t decoded = decoder.outputSampleRate;
	ma_decoder_uninit(&decoder);

	if (result != MA_AT_END) {
		ma_free(frames, NULL);
		return result;
	}

	ent_buffer *buffer = ent_buffer_create(channels, length, decoded);

	if (buffer == NULL) {
		ma_free(frames, NULL);
		return MA_OUT_OF_MEMORY;
	}

	for (uint32_t c = 0; c < channels; c++) {
		for (uint64_t i = 0; i < length; i++) {
			buffer->data[c * length + i] = frames[i * channels + c];
		}
	}

	ma_free(frames, NULL);
	*out = buffer;
	return MA_SUCCESS;
}

static ent_node *ent_node_create(ent_context *context, int kind) {
	ent_node *node = ma_calloc(sizeof(ent_node), NULL);

	if (node == NULL) {
		return NULL;
	}

	if (context->count == context->capacity) {
		uint32_t capacity = context->capacity ? context->capacity * 2 : 16;
		ent_node **nodes = ma_realloc(context->nodes, capacity * sizeof(ent_node *), NULL);

		if (nodes == NULL) {
			ma_free(node, NULL);
			return NULL;
		}

		context->nodes = nodes;
		context->capacity = capacity;
	}

	context->nodes[context->count++] = node;
	context->references++;
	node->context = context;
	node->kind = kind;
	node->id = ++context->next;
	node->channels = 1;
	return node;
}

/* Removes `input` from the inputs of `node`; returns whether it was there. */
static int ent_node_unlink(ent_node *node, ent_node *input) {
	for (uint32_t i = 0; i < node->inputCount; i++) {
		if (node->inputs[i] == input) {
			node->inputs[i] = node->inputs[--node->inputCount];
			return 1;
		}
	}

	return 0;
}

static void ent_node_free(ent_node *node) {
	if (node->buffer != NULL) {
		ent_buffer_release(node->buffer);
	}

	for (int p = 0; p < 9; p++) {
		ma_free(node->params[p].events, NULL);
	}

	if (node->analysis != NULL) {
		ma_free(node->analysis->magnitudes, NULL);
		ma_free(node->analysis, NULL);
	}

	ma_free(node->inputs, NULL);
	ma_free(node, NULL);
}

/*
 * Whether a node with no Dart handle can no longer be heard: a source that has ended or can no longer start, or another
 * node with nothing feeding it.
 */
static int ent_node_silent(ent_node *node) {
	if (node->kind == ENT_DESTINATION || node->kind == ENT_LISTENER) {
		return 0;
	}

	if (node->kind != ENT_SOURCE) {
		return node->inputCount == 0;
	}

	return node->state == ENT_UNSCHEDULED || node->state == ENT_FINISHED;
}

/*
 * Frees the nodes that have no Dart handle and can no longer be heard, or, with `all`, every node without a Dart
 * handle; the caller holds the lock.
 */
static void ent_context_collect(ent_context *context, int all) {
	uint32_t i = 0;

	while (i < context->count) {
		ent_node *node = context->nodes[i];

		if (node->held) {
			i++;
			continue;
		}

		if (!all && !ent_node_silent(node)) {
			i++;
			continue;
		}

		for (uint32_t k = 0; k < context->count; k++) {
			ent_node_unlink(context->nodes[k], node);
		}

		context->nodes[i] = context->nodes[--context->count];
		context->references--;
		ent_node_free(node);
	}
}

static void ent_context_free(ent_context *context) {
	for (uint32_t i = 0; i < context->count; i++) {
		ent_node *node = context->nodes[i];

		ent_node_free(node);
	}

	ma_free(context->nodes, NULL);
	ma_mutex_uninit(&context->lock);
	ma_free(context, NULL);
}

/*
 * A context rendering `channels` channels at `rate` frames per second, held once by the caller. `ended` is called with
 * a source's id when it ends.
 */
ENT_EXPORT ent_context *ent_context_create(uint32_t rate, uint32_t channels, void (*ended)(int32_t id)) {
	ent_context *context = ma_calloc(sizeof(ent_context), NULL);

	if (context == NULL) {
		return NULL;
	}

	if (ma_mutex_init(&context->lock) != MA_SUCCESS) {
		ma_free(context, NULL);
		return NULL;
	}

	context->rate = rate;
	context->channels = channels;
	context->ended = ended;
	context->references = 1;
	context->destination = ent_node_create(context, ENT_DESTINATION);
	context->listener = ent_node_create(context, ENT_LISTENER);

	if (context->destination == NULL || context->listener == NULL) {
		ent_context_free(context);
		return NULL;
	}

	/* The destination and the listener go with the context, so they do not hold it. */
	context->references = 1;
	context->destination->held = 1;
	context->destination->channels = channels;
	context->listener->held = 1;

	/* At the origin, facing -z with +y up. */
	float listener[9] = {0, 0, 0, 0, 0, -1, 0, 1, 0};

	for (int p = 0; p < 9; p++) {
		ent_param_init(&context->listener->params[p], listener[p], 1);
	}

	return context;
}

/*
 * Drops the caller's hold on a context: the nodes without a Dart handle go with it, and the context is freed once the
 * handles of the others are gone too.
 */
ENT_EXPORT void ent_context_release(void *pointer) {
	ent_context *context = pointer;
	ma_mutex_lock(&context->lock);
	ent_context_collect(context, 1);
	int32_t references = --context->references;
	ma_mutex_unlock(&context->lock);

	if (references == 0) {
		ent_context_free(context);
	}
}

ENT_EXPORT ent_node *ent_context_destination(ent_context *context) {
	return context->destination;
}

/* The node holding the listener's parameters: position, forward and up, x, y and z each. */
ENT_EXPORT ent_node *ent_context_listener(ent_context *context) {
	return context->listener;
}

/* The context's time in seconds: the start of the next quantum. */
ENT_EXPORT double ent_context_time(ent_context *context) {
	ma_mutex_lock(&context->lock);
	double time = (double)(context->quantum * ENT_QUANTUM) / context->rate;
	ma_mutex_unlock(&context->lock);
	return time;
}

/* Drops the Dart handle of a node; the node goes once it can no longer be heard. */
ENT_EXPORT void ent_node_release(void *pointer) {
	ent_node *node = pointer;
	ent_context *context = node->context;
	ma_mutex_lock(&context->lock);
	node->held = 0;
	ent_context_collect(context, 0);
	int32_t references = context->references;
	ma_mutex_unlock(&context->lock);

	if (references == 0) {
		ent_context_free(context);
	}
}

ENT_EXPORT int32_t ent_node_id(ent_node *node) {
	return node->id;
}

/* Feeds `node` into `destination`; a connection made twice counts once. */
ENT_EXPORT int ent_node_connect(ent_node *node, ent_node *destination) {
	ent_context *context = node->context;
	int result = 0;
	ma_mutex_lock(&context->lock);
	ent_node_unlink(destination, node);

	if (destination->inputCount == destination->inputCapacity) {
		uint32_t capacity = destination->inputCapacity ? destination->inputCapacity * 2 : 4;
		ent_node **inputs = ma_realloc(destination->inputs, capacity * sizeof(ent_node *), NULL);

		if (inputs == NULL) {
			result = MA_OUT_OF_MEMORY;
		} else {
			destination->inputs = inputs;
			destination->inputCapacity = capacity;
		}
	}

	if (result == 0) {
		destination->inputs[destination->inputCount++] = node;
	}

	ma_mutex_unlock(&context->lock);
	return result;
}

/* Stops feeding `node` into `destination`, or into every node when `destination` is NULL. */
ENT_EXPORT void ent_node_disconnect(ent_node *node, ent_node *destination) {
	ent_context *context = node->context;
	ma_mutex_lock(&context->lock);

	if (destination != NULL) {
		ent_node_unlink(destination, node);
	} else {
		for (uint32_t i = 0; i < context->count; i++) {
			ent_node_unlink(context->nodes[i], node);
		}
	}

	ma_mutex_unlock(&context->lock);
}

/* Sets a parameter's value now: `param.value = value`, which also schedules it at the current time. */
ENT_EXPORT int ent_param_set(ent_node *node, int32_t index, double value) {
	ent_context *context = node->context;
	ent_param *param = &node->params[index];
	ma_mutex_lock(&context->lock);
	param->value = ent_param_clamp(param, (float)value);

	ent_event event = {ENT_SET_VALUE, 0, param->value, (double)(context->quantum * ENT_QUANTUM) / context->rate, 0};
	int result = ent_param_insert(context, param, event, param->value);
	ma_mutex_unlock(&context->lock);
	return result;
}

/* The parameter's value as last computed. */
ENT_EXPORT double ent_param_get(ent_node *node, int32_t index) {
	ma_mutex_lock(&node->context->lock);
	double value = node->params[index].value;
	ma_mutex_unlock(&node->context->lock);
	return value;
}

/* `linearRampToValueAtTime( value, end )`. */
ENT_EXPORT int ent_param_ramp(ent_node *node, int32_t index, double value, double end) {
	ent_context *context = node->context;
	ent_param *param = &node->params[index];
	ma_mutex_lock(&context->lock);

	double now = (double)(context->quantum * ENT_QUANTUM) / context->rate;
	ent_event event = {ENT_LINEAR_RAMP, 0, (float)value, fmax(end, now), 0};
	int result = ent_param_insert(context, param, event, param->value);
	ma_mutex_unlock(&context->lock);
	return result;
}

/* `setTargetAtTime( target, start, constant )`; a zero constant sets the value at `start`. */
ENT_EXPORT int ent_param_target(ent_node *node, int32_t index, double target, double start, double constant) {
	ent_context *context = node->context;
	ent_param *param = &node->params[index];
	ma_mutex_lock(&context->lock);

	double now = (double)(context->quantum * ENT_QUANTUM) / context->rate;
	ent_event event = {constant == 0 ? ENT_SET_VALUE : ENT_SET_TARGET, 0, (float)target, fmax(start, now), constant};
	int result = ent_param_insert(context, param, event, param->value);
	ma_mutex_unlock(&context->lock);
	return result;
}

/* `setValueAtTime( value, time )`, which the deprecated `setPosition` and `setOrientation` use. */
ENT_EXPORT int ent_param_at(ent_node *node, int32_t index, double value, double time) {
	ent_context *context = node->context;
	ent_param *param = &node->params[index];
	ma_mutex_lock(&context->lock);

	double now = (double)(context->quantum * ENT_QUANTUM) / context->rate;
	ent_event event = {ENT_SET_VALUE, 0, (float)value, fmax(time, now), 0};
	int result = ent_param_insert(context, param, event, param->value);
	ma_mutex_unlock(&context->lock);
	return result;
}

/* A panner at the origin facing +x, with Web Audio's default distance model and no cone. */
ENT_EXPORT ent_node *ent_panner_create(ent_context *context) {
	ma_mutex_lock(&context->lock);
	ent_context_collect(context, 0);
	ent_node *node = ent_node_create(context, ENT_PANNER);

	if (node != NULL) {
		node->held = 1;
		node->channels = 2;

		float values[6] = {0, 0, 0, 1, 0, 0};

		for (int p = 0; p < 6; p++) {
			ent_param_init(&node->params[p], values[p], 1);
		}

		node->distanceModel = ENT_INVERSE;
		node->refDistance = 1;
		node->maxDistance = 10000;
		node->rolloffFactor = 1;
		node->coneInnerAngle = 360;
		node->coneOuterAngle = 360;
		node->coneOuterGain = 0;
	}

	ma_mutex_unlock(&context->lock);
	return node;
}

/*
 * Sets a panner's distance model (0 linear, 1 inverse, 2 exponential), reference distance, maximum distance, rolloff
 * factor, cone inner angle, cone outer angle and cone outer gain.
 */
ENT_EXPORT void ent_panner_set(ent_node *node, int32_t model, double ref, double max, double rolloff, double inner,
	double outer, double gain) {
	ma_mutex_lock(&node->context->lock);
	node->distanceModel = model;
	node->refDistance = ref;
	node->maxDistance = max;
	node->rolloffFactor = rolloff;
	node->coneInnerAngle = inner;
	node->coneOuterAngle = outer;
	node->coneOuterGain = gain;
	ma_mutex_unlock(&node->context->lock);
}

/* A gain node, with its gain at 1. */
ENT_EXPORT ent_node *ent_gain_create(ent_context *context) {
	ma_mutex_lock(&context->lock);
	ent_context_collect(context, 0);
	ent_node *node = ent_node_create(context, ENT_GAIN);

	if (node != NULL) {
		node->held = 1;
		ent_param_init(&node->params[ENT_GAIN_VALUE], 1, 1);
	}

	ma_mutex_unlock(&context->lock);
	return node;
}

ENT_EXPORT ent_node *ent_source_create(ent_context *context) {
	ma_mutex_lock(&context->lock);
	ent_context_collect(context, 0);
	ent_node *node = ent_node_create(context, ENT_SOURCE);

	if (node != NULL) {
		node->held = 1;
		ent_param_init(&node->params[ENT_PLAYBACK_RATE], 1, 0);
		ent_param_init(&node->params[ENT_DETUNE], 0, 0);
		node->duration = INFINITY;
		node->stop = INFINITY;
	}

	ma_mutex_unlock(&context->lock);
	return node;
}

ENT_EXPORT void ent_source_buffer(ent_node *node, ent_buffer *buffer) {
	ma_mutex_lock(&node->context->lock);
	ent_buffer_retain(buffer);

	if (node->buffer != NULL) {
		ent_buffer_release(node->buffer);
	}

	node->buffer = buffer;
	node->channels = buffer->channels;
	ma_mutex_unlock(&node->context->lock);
}

ENT_EXPORT void ent_source_loop(ent_node *node, int32_t loop, double start, double end) {
	ma_mutex_lock(&node->context->lock);
	node->loop = loop;
	node->loopStart = start;
	node->loopEnd = end;
	ma_mutex_unlock(&node->context->lock);
}

/* Schedules playback at `when`, from `offset`, for `duration` seconds of the buffer (negative: to its end). */
ENT_EXPORT void ent_source_start(ent_node *node, double when, double offset, double duration) {
	ent_context *context = node->context;
	ma_mutex_lock(&context->lock);
	double now = (double)(context->quantum * ENT_QUANTUM) / context->rate;
	node->start = fmax(when, now);
	node->offset = offset;
	node->duration = duration < 0 ? INFINITY : duration;
	node->state = ENT_SCHEDULED;
	ma_mutex_unlock(&context->lock);
}

ENT_EXPORT void ent_source_stop(ent_node *node, double when) {
	ent_context *context = node->context;
	ma_mutex_lock(&context->lock);
	double now = (double)(context->quantum * ENT_QUANTUM) / context->rate;
	node->stop = fmax(when, now);
	ma_mutex_unlock(&context->lock);
}

/* One sample of a channel at a fractional playhead, interpolated linearly with the frame after it. */
static float ent_source_sample(const float *data, uint64_t length, double index, int wrap, double start, double end) {
	uint64_t i = (uint64_t)index;
	double f = index - (double)i;

	if (f == 0) {
		return data[i];
	}

	uint64_t next = i + 1;

	if (wrap && index < end && (double)next >= end) {

		/* Crossing the loop's end: the frame after it is the loop's first. */
		double wrapped = index + 1 - (end - start);
		next = wrapped > 0 ? (uint64_t)wrapped : 0;
	} else if (next >= length) {

		/* Past the last frame: extrapolated from the last two. */
		if (i == 0) {
			return data[i];
		}

		return (float)(data[i] + (data[i] - data[i - 1]) * f);
	}

	if (next >= length) {
		next = length - 1;
	}

	return (float)((1.0 - f) * data[i] + f * data[next]);
}

static void ent_source_finish(ent_node *node) {
	node->state = ENT_FINISHED;
}

/* Renders one quantum of a source. */
static void ent_source_render(ent_node *node, uint64_t quantum) {
	ent_context *context = node->context;
	ent_buffer *buffer = node->buffer;
	uint32_t channels = node->channels;

	for (uint32_t c = 0; c < channels; c++) {
		memset(node->output[c], 0, sizeof(node->output[c]));
	}

	if (node->state == ENT_UNSCHEDULED || node->state == ENT_FINISHED) {
		return;
	}

	if (buffer == NULL || buffer->length == 0) {
		ent_source_finish(node);
		return;
	}

	double first = (double)(quantum * ENT_QUANTUM);
	double startFrame = ceil(ent_frame(node->start, context->rate));
	double stopFrame = isinf(node->stop) ? INFINITY : ceil(ent_frame(node->stop, context->rate));

	if (stopFrame <= first) {
		ent_source_finish(node);
		return;
	}

	if (startFrame >= first + ENT_QUANTUM) {
		return;
	}

	double length = (double)buffer->length;
	double duration = (double)buffer->length / buffer->rate;
	double rate = (double)buffer->rate / context->rate * ent_param_final(context, &node->params[ENT_PLAYBACK_RATE]);
	rate *= pow(2, ent_param_final(context, &node->params[ENT_DETUNE]) / 1200.0f);

	/* The loop, in buffer frames: the whole buffer unless the loop points make a valid part of it. */
	double loopStart = 0;
	double loopEnd = length;

	if (node->loop) {
		double start = fmin(fmax(node->loopStart, 0), duration);
		double end = node->loopEnd == 0 ? duration : fmin(fmax(node->loopEnd, 0), duration);

		if (start < end) {
			if (start > 0) {
				loopStart = ent_frame(start, buffer->rate);
			}

			if (end < duration) {
				loopEnd = ent_frame(end, buffer->rate);
			}
		}

		if (loopStart >= loopEnd) {
			loopStart = 0;
			loopEnd = length;
		}
	}

	double span = loopEnd - loopStart;

	if (fabs(rate) > span) {
		return;
	}

	uint32_t from = startFrame > first ? (uint32_t)(startFrame - first) : 0;

	if (node->state == ENT_SCHEDULED) {
		node->state = ENT_PLAYING;
		node->index = ent_frame(fmin(node->offset, duration), buffer->rate);

		/* A start between two frames begins at the next one, with the playhead moved on by the difference. */
		double late = startFrame - node->start * context->rate;

		if (rate != 0 && late > 0) {
			node->index += late * rate;
			node->played += fabs(late * rate);
		}
	}

	if (node->loop) {
		if (rate >= 0 && node->index >= loopEnd) {
			node->index = loopStart;
		}

		if (rate < 0 && node->index < loopStart) {
			node->index = loopStart;
		}
	}

	double limit = isinf(node->duration) ? INFINITY : node->duration * buffer->rate;

	for (uint32_t i = from; i < ENT_QUANTUM; i++) {
		if (first + i >= stopFrame || node->played >= limit) {
			ent_source_finish(node);
			return;
		}

		double index = node->index;

		if (!node->loop && (index >= length || index < 0)) {
			ent_source_finish(node);
			return;
		}

		if (index >= 0 && index < length) {
			for (uint32_t c = 0; c < channels; c++) {
				const float *data = buffer->data + c * buffer->length;
				node->output[c][i] = ent_source_sample(data, buffer->length, index, node->loop, loopStart, loopEnd);
			}
		}

		node->index += rate;
		node->played += fabs(rate);

		if (!node->loop) {
			if (node->index >= length || node->index < 0) {
				ent_source_finish(node);
				return;
			}
		} else if (rate >= 0 && node->index >= loopEnd) {
			node->index = loopStart + fmod(node->index - loopEnd, span);
		} else if (rate < 0 && node->index < loopStart) {
			node->index = loopEnd - fmod(loopStart - node->index, span);
		}
	}
}

static void ent_node_render(ent_node *node, uint64_t quantum);

/* Sums the inputs of a node into its output over `channels` channels, mixing each input up or down as speakers. */
static void ent_node_mix(ent_node *node, uint64_t quantum, uint32_t channels) {
	node->channels = channels;

	for (uint32_t c = 0; c < channels; c++) {
		memset(node->output[c], 0, sizeof(node->output[c]));
	}

	for (uint32_t k = 0; k < node->inputCount; k++) {
		ent_node *input = node->inputs[k];
		ent_node_render(input, quantum);

		uint32_t count = input->channels;

		for (uint32_t i = 0; i < ENT_QUANTUM; i++) {
			if (count == 1 && channels == 2) {
				node->output[0][i] += input->output[0][i];
				node->output[1][i] += input->output[0][i];
			} else if (count == 2 && channels == 1) {
				node->output[0][i] += 0.5f * (input->output[0][i] + input->output[1][i]);
			} else {
				for (uint32_t c = 0; c < channels && c < count; c++) {
					node->output[c][i] += input->output[c][i];
				}
			}
		}
	}
}

/* The channels a node mixing its inputs as Web Audio's "max" mode renders: those of its widest input, at least one. */
static uint32_t ent_node_widest(ent_node *node, uint64_t quantum) {
	uint32_t channels = 1;

	for (uint32_t k = 0; k < node->inputCount; k++) {
		ent_node_render(node->inputs[k], quantum);

		if (node->inputs[k]->channels > channels) {
			channels = node->inputs[k]->channels;
		}
	}

	return channels;
}

/* Renders one quantum of a gain node: its mixed inputs times the gain, per frame while the gain changes. */
static void ent_gain_render(ent_node *node, uint64_t quantum) {
	ent_context *context = node->context;
	ent_param *gain = &node->params[ENT_GAIN_VALUE];
	ent_node_mix(node, quantum, ent_node_widest(node, quantum));

	if (node->inputCount == 0) {
		return;
	}

	if (ent_param_accurate(context, gain)) {
		float values[ENT_QUANTUM];
		ent_param_timeline(context, gain, values);

		for (uint32_t c = 0; c < node->channels; c++) {
			for (uint32_t i = 0; i < ENT_QUANTUM; i++) {
				node->output[c][i] *= values[i];
			}
		}

		return;
	}

	float value = ent_param_final(context, gain);

	for (uint32_t c = 0; c < node->channels; c++) {
		for (uint32_t i = 0; i < ENT_QUANTUM; i++) {
			node->output[c][i] = value == 0 ? 0 : node->output[c][i] * value;
		}
	}
}

/*
 * The panner and the listener, following Chromium's PannerHandler with its equal-power panner: positions and
 * directions in 32-bit floats as its vector math has them, the azimuth and elevation of the source as the listener
 * hears it, the distance and cone gains, and a value per frame whenever a position or direction changes within the
 * quantum.
 */

typedef struct ent_vector {
	float x;
	float y;
	float z;
} ent_vector;

static ent_vector ent_minus(ent_vector a, ent_vector b) {
	ent_vector v = {a.x - b.x, a.y - b.y, a.z - b.z};
	return v;
}

static double ent_length_squared(ent_vector v) {
	return (double)v.x * v.x + (double)v.y * v.y + (double)v.z * v.z;
}

static float ent_length(ent_vector v) {
	return (float)sqrt(ent_length_squared(v));
}

static float ent_dot(ent_vector a, ent_vector b) {
	return a.x * b.x + a.y * b.y + a.z * b.z;
}

static ent_vector ent_cross(ent_vector a, ent_vector b) {
	double x = a.x;
	double y = a.y;
	double z = a.z;
	ent_vector v = {(float)(y * b.z - z * b.y), (float)(z * b.x - x * b.z), (float)(x * b.y - y * b.x)};
	return v;
}

/* Scales a vector to length 1, unless it is too short to have a direction; returns whether it had one. */
static int ent_normalize(ent_vector *v) {
	double squared = ent_length_squared(*v);

	if (squared < 1.0e-6 * 1.0e-6) {
		return 0;
	}

	float length = (float)sqrt(squared);
	v->x /= length;
	v->y /= length;
	v->z /= length;
	return 1;
}

static float ent_degrees(float radians) {
	return radians * (180 / (float)M_PI);
}

static float ent_angle(ent_vector a, ent_vector b) {
	return ent_degrees(acosf(fmaxf(fminf(ent_dot(a, b) / ent_length(a) / ent_length(b), 1.f), -1.f)));
}

static double ent_finite(double x) {
	return isfinite(x) ? x : 0.0;
}

/* The azimuth and elevation, in degrees, of a source at `position` as a listener at `listener` hears it. */
static void ent_direction(double *azimuth, double *elevation, ent_vector position, ent_vector listener,
	ent_vector forward, ent_vector up) {
	ent_vector source = ent_minus(position, listener);

	if (!ent_normalize(&source)) {
		*azimuth = 0;
		*elevation = 0;
		return;
	}

	ent_vector right = ent_cross(forward, up);
	ent_normalize(&right);

	ent_vector ahead = forward;
	ent_normalize(&ahead);

	ent_vector above = ent_cross(right, ahead);
	float projection = ent_dot(source, above);
	ent_vector projected = {source.x - above.x * projection, source.y - above.y * projection,
		source.z - above.z * projection};
	ent_normalize(&projected);

	double angle = ent_finite(ent_degrees(acosf(fminf(fmaxf(ent_dot(projected, right), -1.0f), 1.0f))));

	if (ent_dot(projected, ahead) < 0.0) {
		angle = 360.0 - angle;
	}

	if (angle >= 0.0 && angle <= 270.0) {
		angle = 90.0 - angle;
	} else {
		angle = 450.0 - angle;
	}

	double height = ent_finite(90 - ent_angle(source, above));

	if (height > 90.0) {
		height = 180.0 - height;
	} else if (height < -90.0) {
		height = -180.0 - height;
	}

	*azimuth = angle;
	*elevation = height;
}

/* The gain for a source at `distance` by the panner's distance model. */
static double ent_distance_gain(const ent_node *node, double distance) {
	double ref = node->refDistance;
	double rolloff = node->rolloffFactor;

	if (node->distanceModel == ENT_LINEAR) {
		double near = fmin(ref, node->maxDistance);
		double far = fmax(ref, node->maxDistance);
		distance = fmin(fmax(distance, near), far);

		if (near == far) {
			return 1 - rolloff;
		}

		return 1.0 - fmin(fmax(rolloff, 0.0), 1.0) * (distance - near) / (far - near);
	}

	if (ref == 0) {
		return 0;
	}

	distance = fmax(distance, ref);

	if (node->distanceModel == ENT_INVERSE) {
		return ref / (ref + fmax(rolloff, 0.0) * (distance - ref));
	}

	return pow(distance / ref, -fmax(rolloff, 0.0));
}

/* The gain for a listener at `listener` from a source at `position` facing `orientation`, by the panner's cone. */
static double ent_cone_gain(const ent_node *node, ent_vector position, ent_vector orientation, ent_vector listener) {
	int none = orientation.x == 0 && orientation.y == 0 && orientation.z == 0;

	if (none || (node->coneInnerAngle == 360.0 && node->coneOuterAngle == 360.0)) {
		return 1.0;
	}

	double angle = fabs(ent_angle(ent_minus(listener, position), orientation));
	double inner = fabs(node->coneInnerAngle) / 2.0;
	double outer = fabs(node->coneOuterAngle) / 2.0;

	if (angle <= inner) {
		return 1.0;
	}

	if (angle >= outer) {
		return node->coneOuterGain;
	}

	double x = (angle - inner) / (outer - inner);
	return (1.0 - x) + node->coneOuterGain * x;
}

static float ent_panner_gain(const ent_node *node, ent_vector position, ent_vector orientation, ent_vector listener) {
	double distance = ent_length(ent_minus(position, listener));
	return (float)(ent_distance_gain(node, distance) * ent_cone_gain(node, position, orientation, listener));
}

/*
 * The equal-power gains of the left and right channels for `azimuth`, which is first folded into [-90, 90]; returns
 * the folded azimuth.
 */
static double ent_equal_power(double azimuth, uint32_t channels, double *left, double *right) {
	azimuth = fmin(fmax(azimuth, -180.0), 180.0);

	if (azimuth < -90.0) {
		azimuth = -180.0 - azimuth;
	} else if (azimuth > 90.0) {
		azimuth = 180.0 - azimuth;
	}

	double position = 0.0;

	if (channels == 1) {
		position = (azimuth + 90.0) / 180.0;
	} else if (azimuth <= 0) {
		position = (azimuth + 90.0) / 90.0;
	} else {
		position = azimuth / 90.0;
	}

	*left = cos(M_PI / 2 * position);
	*right = sin(M_PI / 2 * position);
	return azimuth;
}

/* Pans frame `i` of `in` (`channels` channels) into the panner's stereo output. */
static void ent_pan(ent_node *node, float in[2][ENT_QUANTUM], uint32_t channels, uint32_t i, double azimuth) {
	double left = 0;
	double right = 0;
	double folded = ent_equal_power(azimuth, channels, &left, &right);

	if (channels == 1) {
		node->output[0][i] = (float)(in[0][i] * left);
		node->output[1][i] = (float)(in[0][i] * right);
	} else if (folded <= 0) {
		node->output[0][i] = (float)(in[0][i] + in[1][i] * left);
		node->output[1][i] = (float)(in[1][i] * right);
	} else {
		node->output[0][i] = (float)(in[0][i] * left);
		node->output[1][i] = (float)(in[1][i] + in[0][i] * right);
	}
}

/* Computes the listener's position, forward and up for every frame of the quantum, once per quantum. */
static void ent_listener_update(ent_context *context) {
	ent_node *listener = context->listener;

	if (listener->quantum == context->quantum + 1) {
		return;
	}

	listener->quantum = context->quantum + 1;

	for (int p = 0; p < 9; p++) {
		ent_param_timeline(context, &listener->params[p], context->listenerValues[p]);
	}
}

static int ent_params_accurate(ent_context *context, ent_node *node, int count) {
	for (int p = 0; p < count; p++) {
		if (ent_param_accurate(context, &node->params[p])) {
			return 1;
		}
	}

	return 0;
}

/* Renders one quantum of a panner: its inputs mixed to at most two channels, panned and scaled to stereo. */
static void ent_panner_render(ent_node *node, uint64_t quantum) {
	ent_context *context = node->context;
	ent_node *listener = context->listener;
	uint32_t channels = ent_node_widest(node, quantum) > 1 ? 2 : 1;
	float in[2][ENT_QUANTUM];

	ent_node_mix(node, quantum, channels);
	memcpy(in[0], node->output[0], sizeof(in[0]));
	memcpy(in[1], node->output[channels - 1], sizeof(in[1]));
	node->channels = 2;

	if (ent_params_accurate(context, node, 6) || ent_params_accurate(context, listener, 9)) {
		float values[6][ENT_QUANTUM];
		float (*heard)[ENT_QUANTUM] = context->listenerValues;

		ent_listener_update(context);

		for (int p = 0; p < 6; p++) {
			ent_param_timeline(context, &node->params[p], values[p]);
		}

		for (uint32_t i = 0; i < ENT_QUANTUM; i++) {
			ent_vector position = {values[0][i], values[1][i], values[2][i]};
			ent_vector orientation = {values[3][i], values[4][i], values[5][i]};
			ent_vector at = {heard[0][i], heard[1][i], heard[2][i]};
			ent_vector forward = {heard[3][i], heard[4][i], heard[5][i]};
			ent_vector up = {heard[6][i], heard[7][i], heard[8][i]};
			double azimuth = 0;
			double elevation = 0;

			ent_direction(&azimuth, &elevation, position, at, forward, up);
			ent_pan(node, in, channels, i, azimuth);

			float gain = ent_panner_gain(node, position, orientation, at);
			node->output[0][i] *= gain;
			node->output[1][i] *= gain;
		}

		return;
	}

	float v[15];

	for (int p = 0; p < 6; p++) {
		v[p] = ent_param_final(context, &node->params[p]);
	}

	for (int p = 0; p < 9; p++) {
		v[6 + p] = ent_param_final(context, &listener->params[p]);
	}

	ent_vector position = {v[0], v[1], v[2]};
	ent_vector orientation = {v[3], v[4], v[5]};
	ent_vector at = {v[6], v[7], v[8]};
	ent_vector forward = {v[9], v[10], v[11]};
	ent_vector up = {v[12], v[13], v[14]};
	double azimuth = 0;
	double elevation = 0;

	ent_direction(&azimuth, &elevation, position, at, forward, up);

	for (uint32_t i = 0; i < ENT_QUANTUM; i++) {
		ent_pan(node, in, channels, i, azimuth);
	}

	float gain = ent_panner_gain(node, position, orientation, at);

	if (gain == 1) {
		return;
	}

	for (uint32_t i = 0; i < ENT_QUANTUM; i++) {
		node->output[0][i] = gain == 0 ? 0 : node->output[0][i] * gain;
		node->output[1][i] = gain == 0 ? 0 : node->output[1][i] * gain;
	}
}

/*
 * The analyser, following Chromium's AnalyserHandler and RealtimeAnalyser: its input passes through unchanged and,
 * mixed down to one channel, fills a ring of the latest 32768 frames. An analysis takes the latest `size` frames
 * through a Blackman window and an FFT, and smooths the magnitudes with those of the previous analysis.
 */

/* Writes the mixed-down input of this quantum into the ring. */
static void ent_analyser_write(ent_node *node) {
	ent_analysis *analysis = node->analysis;

	for (uint32_t i = 0; i < ENT_QUANTUM; i++) {
		float sample = node->output[0][i];

		if (node->channels == 2) {
			sample = 0.5f * (node->output[0][i] + node->output[1][i]);
		}

		analysis->ring[(analysis->write + i) % ENT_RING] = sample;
	}

	analysis->write = (analysis->write + ENT_QUANTUM) % ENT_RING;
}

static void ent_analyser_render(ent_node *node, uint64_t quantum) {
	ent_node_mix(node, quantum, ent_node_widest(node, quantum));
	ent_analyser_write(node);
}

/* An in-place radix-2 FFT of `n` complex values. */
static void ent_fft(double *re, double *im, uint32_t n) {
	for (uint32_t i = 1, j = 0; i < n; i++) {
		uint32_t bit = n >> 1;

		for (; j & bit; bit >>= 1) {
			j ^= bit;
		}

		j ^= bit;

		if (i < j) {
			double t = re[i];
			re[i] = re[j];
			re[j] = t;
			t = im[i];
			im[i] = im[j];
			im[j] = t;
		}
	}

	for (uint32_t length = 2; length <= n; length <<= 1) {
		double angle = -2 * M_PI / length;

		for (uint32_t start = 0; start < n; start += length) {
			for (uint32_t k = 0; k < length / 2; k++) {
				double wr = cos(angle * k);
				double wi = sin(angle * k);
				uint32_t a = start + k;
				uint32_t b = a + length / 2;
				double xr = re[b] * wr - im[b] * wi;
				double xi = re[b] * wi + im[b] * wr;
				re[b] = re[a] - xr;
				im[b] = im[a] - xi;
				re[a] += xr;
				im[a] += xi;
			}
		}
	}
}

/* Analyses the latest frames unless this quantum was analysed already, leaving the magnitudes in the analysis. */
static int ent_analyse(ent_node *node, double smoothing) {
	ent_context *context = node->context;
	ent_analysis *analysis = node->analysis;
	double now = (double)(context->quantum * ENT_QUANTUM) / context->rate;

	if (now <= analysis->time) {
		return 0;
	}

	analysis->time = now;

	uint32_t n = analysis->size;
	double *re = ma_malloc(n * 2 * sizeof(double), NULL);

	if (re == NULL) {
		return MA_OUT_OF_MEMORY;
	}

	double *im = re + n;

	for (uint32_t i = 0; i < n; i++) {
		float sample = analysis->ring[(analysis->write + ENT_RING - n + i) % ENT_RING];
		double x = (double)i / (double)n;
		double window = 0.5 * (1 - 0.16) - 0.5 * cos(2 * M_PI * x) + 0.5 * 0.16 * cos(2 * M_PI * 2.0 * x);

		re[i] = sample * (float)window;
		im[i] = 0;
	}

	ent_fft(re, im, n);

	double k = fmin(fmax(smoothing, 0.0), 1.0);

	for (uint32_t i = 0; i < n / 2; i++) {

		/* The FFT's results are kept as 32-bit floats, and bin 0 has no imaginary part. */
		double magnitude = hypot((float)re[i], i == 0 ? 0 : (float)im[i]) / n;
		float value = (float)(k * analysis->magnitudes[i] + (1 - k) * magnitude);

		analysis->magnitudes[i] = isfinite(value) ? value : 0;
	}

	ma_free(re, NULL);
	return 0;
}

/* An analyser with an FFT of 2048 frames. */
ENT_EXPORT ent_node *ent_analyser_create(ent_context *context) {
	ent_analysis *analysis = ma_calloc(sizeof(ent_analysis), NULL);
	float *magnitudes = ma_calloc(1024 * sizeof(float), NULL);

	if (analysis == NULL || magnitudes == NULL) {
		ma_free(analysis, NULL);
		ma_free(magnitudes, NULL);
		return NULL;
	}

	analysis->size = 2048;
	analysis->magnitudes = magnitudes;
	analysis->time = -1;

	ma_mutex_lock(&context->lock);
	ent_context_collect(context, 0);
	ent_node *node = ent_node_create(context, ENT_ANALYSER);

	if (node != NULL) {
		node->held = 1;
		node->analysis = analysis;
	}

	ma_mutex_unlock(&context->lock);

	if (node == NULL) {
		ma_free(magnitudes, NULL);
		ma_free(analysis, NULL);
	}

	return node;
}

/* Sets the FFT size, a power of two from 32 to 32768; a new size starts the smoothing over. */
ENT_EXPORT int ent_analyser_size(ent_node *node, uint32_t size) {
	ent_analysis *analysis = node->analysis;
	int result = 0;
	ma_mutex_lock(&node->context->lock);

	if (size != analysis->size) {
		float *magnitudes = ma_calloc(size / 2 * sizeof(float), NULL);

		if (magnitudes == NULL) {
			result = MA_OUT_OF_MEMORY;
		} else {
			ma_free(analysis->magnitudes, NULL);
			analysis->magnitudes = magnitudes;
			analysis->size = size;
		}
	}

	ma_mutex_unlock(&node->context->lock);
	return result;
}

/* The magnitudes in decibels, as `getFloatFrequencyData`, into `out` of `count` values. */
ENT_EXPORT int ent_analyser_decibels(ent_node *node, double smoothing, float *out, uint32_t count) {
	ma_mutex_lock(&node->context->lock);
	int result = ent_analyse(node, smoothing);

	for (uint32_t i = 0; i < count && i < node->analysis->size / 2; i++) {
		out[i] = 20 * log10f(node->analysis->magnitudes[i]);
	}

	ma_mutex_unlock(&node->context->lock);
	return result;
}

/* The magnitudes scaled from [min, max] decibels to [0, 255], as `getByteFrequencyData`. */
ENT_EXPORT int ent_analyser_bytes(ent_node *node, double smoothing, double min, double max, uint8_t *out,
	uint32_t count) {
	ma_mutex_lock(&node->context->lock);
	int result = ent_analyse(node, smoothing);
	double scale = max == min ? 1.0 : 1.0 / (max - min);

	for (uint32_t i = 0; i < count && i < node->analysis->size / 2; i++) {
		double decibels = 20 * log10f(node->analysis->magnitudes[i]);
		double scaled = UCHAR_MAX * (decibels - min) * scale;

		out[i] = (uint8_t)fmin(fmax(scaled, 0), UCHAR_MAX);
	}

	ma_mutex_unlock(&node->context->lock);
	return result;
}

static void ent_node_render(ent_node *node, uint64_t quantum) {
	if (node->quantum == quantum + 1) {
		return;
	}

	node->quantum = quantum + 1;

	if (node->kind == ENT_SOURCE) {
		ent_source_render(node, quantum);
	} else if (node->kind == ENT_GAIN) {
		ent_gain_render(node, quantum);
	} else if (node->kind == ENT_PANNER) {
		ent_panner_render(node, quantum);
	} else if (node->kind == ENT_ANALYSER) {
		ent_analyser_render(node, quantum);
	} else {
		ent_node_mix(node, quantum, node->context->channels);
	}
}

/* Renders one quantum into the destination's output and reports the sources that ended in it. */
static void ent_context_step(ent_context *context) {
	uint64_t quantum = context->quantum;
	ent_node_render(context->destination, quantum);

	for (uint32_t i = 0; i < context->count; i++) {
		ent_node *node = context->nodes[i];

		/* Started sources and analysers render even when nothing pulls them, as in Chrome. */
		if (node->kind == ENT_SOURCE && node->state != ENT_UNSCHEDULED) {
			ent_node_render(node, quantum);
		}

		if (node->kind == ENT_ANALYSER) {
			ent_node_render(node, quantum);
		}

		if (node->kind == ENT_SOURCE && node->state == ENT_FINISHED && !node->reported) {
			node->reported = 1;

			if (context->ended != NULL) {
				context->ended(node->id);
			}
		}
	}

	context->quantum++;
}

/* Renders `quanta` quanta into `out`: per channel, `quanta * 128` frames, one channel after another. */
ENT_EXPORT void ent_context_render(ent_context *context, float *out, uint32_t quanta) {
	uint64_t frames = (uint64_t)quanta * ENT_QUANTUM;

	for (uint32_t q = 0; q < quanta; q++) {
		ma_mutex_lock(&context->lock);
		ent_context_step(context);

		for (uint32_t c = 0; c < context->channels; c++) {
			memcpy(out + c * frames + q * ENT_QUANTUM, context->destination->output[c], ENT_QUANTUM * sizeof(float));
		}

		ma_mutex_unlock(&context->lock);
	}

	ma_mutex_lock(&context->lock);
	ent_context_collect(context, 0);
	ma_mutex_unlock(&context->lock);
}

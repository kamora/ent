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

enum { ENT_DESTINATION, ENT_SOURCE };

enum { ENT_UNSCHEDULED, ENT_SCHEDULED, ENT_PLAYING, ENT_FINISHED };

/* The parameters of a source: indices into ent_node.params. */
enum { ENT_PLAYBACK_RATE, ENT_DETUNE };

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

	/* Parameter values are 32-bit floats, as in Web Audio. */
	float params[2];

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
};

struct ent_context {
	ma_mutex lock;
	int32_t references;
	uint32_t rate;
	uint32_t channels;
	uint64_t quantum;
	ent_node *destination;
	ent_node **nodes;
	uint32_t count;
	uint32_t capacity;
	int32_t next;
	void (*ended)(int32_t id);
};

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

/* Whether a node with no Dart handle can no longer be heard. */
static int ent_node_silent(ent_node *node) {
	if (node->kind != ENT_SOURCE) {
		return 0;
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

		if (node->buffer != NULL) {
			ent_buffer_release(node->buffer);
		}

		context->nodes[i] = context->nodes[--context->count];
		context->references--;
		ma_free(node->inputs, NULL);
		ma_free(node, NULL);
	}
}

static void ent_context_free(ent_context *context) {
	for (uint32_t i = 0; i < context->count; i++) {
		ent_node *node = context->nodes[i];

		if (node->buffer != NULL) {
			ent_buffer_release(node->buffer);
		}

		ma_free(node->inputs, NULL);
		ma_free(node, NULL);
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

	if (context->destination == NULL) {
		ent_context_free(context);
		return NULL;
	}

	/* The destination goes with the context, so it does not hold it. */
	context->references = 1;
	context->destination->held = 1;
	context->destination->channels = channels;
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

ENT_EXPORT void ent_param_set(ent_node *node, int32_t param, double value) {
	ma_mutex_lock(&node->context->lock);
	node->params[param] = (float)value;
	ma_mutex_unlock(&node->context->lock);
}

ENT_EXPORT double ent_param_get(ent_node *node, int32_t param) {
	ma_mutex_lock(&node->context->lock);
	double value = node->params[param];
	ma_mutex_unlock(&node->context->lock);
	return value;
}

ENT_EXPORT ent_node *ent_source_create(ent_context *context) {
	ma_mutex_lock(&context->lock);
	ent_context_collect(context, 0);
	ent_node *node = ent_node_create(context, ENT_SOURCE);

	if (node != NULL) {
		node->held = 1;
		node->params[ENT_PLAYBACK_RATE] = 1;
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
	double rate = (double)buffer->rate / context->rate * node->params[ENT_PLAYBACK_RATE];
	rate *= pow(2, node->params[ENT_DETUNE] / 1200.0f);

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

static void ent_node_render(ent_node *node, uint64_t quantum) {
	if (node->quantum == quantum + 1) {
		return;
	}

	node->quantum = quantum + 1;

	if (node->kind == ENT_SOURCE) {
		ent_source_render(node, quantum);
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

		if (node->kind == ENT_SOURCE && node->state != ENT_UNSCHEDULED) {
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

/*
 * The native side of ent_audio: miniaudio, compiled here, and the functions the Dart bindings call
 * (lib/src/bindings.dart).
 */

#define MINIAUDIO_IMPLEMENTATION
#include "../third_party/miniaudio/miniaudio.h"

#if defined(_WIN32)
#define ENT_EXPORT __declspec(dllexport)
#else
#define ENT_EXPORT __attribute__((visibility("default")))
#endif

/*
 * Decodes WAV, FLAC or MP3 data into interleaved 32-bit float frames, keeping the file's channels and converting
 * to `rate` (0 keeps the file's rate too). On success it returns 0 and fills the outputs; `*samples` is freed with
 * ent_audio_free. Otherwise it returns miniaudio's error code.
 */
ENT_EXPORT int ent_audio_decode(const void *data, size_t size, uint32_t rate, uint32_t *channels, uint32_t *rateOut,
	uint64_t *frames, float **samples) {
	ma_decoder_config config = ma_decoder_config_init(ma_format_f32, 0, rate);
	ma_decoder decoder;
	ma_result result = ma_decoder_init_memory(data, size, &config, &decoder);

	if (result != MA_SUCCESS) {
		return result;
	}

	uint32_t count = decoder.outputChannels;
	uint64_t capacity = 4096;
	uint64_t length = 0;
	float *buffer = ma_malloc(capacity * count * sizeof(float), NULL);

	for (;;) {
		if (buffer == NULL) {
			ma_decoder_uninit(&decoder);
			return MA_OUT_OF_MEMORY;
		}

		uint64_t read = 0;
		result = ma_decoder_read_pcm_frames(&decoder, buffer + length * count, capacity - length, &read);
		length += read;

		if (result != MA_SUCCESS) {
			break;
		}

		if (length == capacity) {
			capacity *= 2;
			float *grown = ma_realloc(buffer, capacity * count * sizeof(float), NULL);

			if (grown == NULL) {
				ma_free(buffer, NULL);
			}

			buffer = grown;
		}
	}

	*rateOut = decoder.outputSampleRate;
	ma_decoder_uninit(&decoder);

	if (result != MA_AT_END) {
		ma_free(buffer, NULL);
		return result;
	}

	*channels = count;
	*frames = length;
	*samples = buffer;
	return MA_SUCCESS;
}

/* Frees what ent_audio_decode allocated. */
ENT_EXPORT void ent_audio_free(void *pointer) {
	ma_free(pointer, NULL);
}

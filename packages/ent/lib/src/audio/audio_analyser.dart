part of '../../ent.dart';

/// This class can be used to analyse audio data.
///
/// ```dart
/// // create an AudioListener and add it to the camera
/// final listener = AudioListener();
/// camera.add(listener);
///
/// // create an Audio source
/// final sound = Audio(listener);
///
/// // load a sound and set it as the Audio object's buffer
/// final audioLoader = AudioLoader();
/// audioLoader.load('sounds/ambient.ogg', (buffer) {
/// 	sound.setBuffer(buffer);
/// 	sound.setLoop(true);
/// 	sound.setVolume(0.5);
/// 	sound.play();
/// });
///
/// // create an AudioAnalyser, passing in the sound and desired fftSize
/// final analyser = AudioAnalyser(sound, 32);
///
/// // get the average frequency of the sound
/// final data = analyser.getAverageFrequency();
/// ```
class AudioAnalyser {
  /// Constructs a new audio analyzer for [audio]. [fftSize] (default `2048`) is the window size in samples
  /// that is used when performing a Fast Fourier Transform (FFT) to get frequency domain data.
  AudioAnalyser(Audio audio, [int fftSize = 2048]) : analyser = audio.context.createAnalyser() {
    analyser.fftSize = fftSize;

    data = Uint8List(analyser.frequencyBinCount);

    audio.getOutput().connect(analyser);
  }

  /// The analyser node.
  final WebAudioAnalyserNode analyser;

  /// Holds the analyzed data.
  late Uint8List data;

  /// Returns an array with frequency data of the audio.
  ///
  /// Each item in the array represents the decibel value for a specific frequency. The frequencies are
  /// spread linearly from 0 to 1/2 of the sample rate. For example, for 48000 sample rate, the last item of
  /// the array will represent the decibel value for 24000 Hz.
  Uint8List getFrequencyData() {
    analyser.getByteFrequencyData(data);

    return data;
  }

  /// Returns the average of the frequencies returned by [getFrequencyData].
  double getAverageFrequency() {
    var value = 0;
    final data = getFrequencyData();

    for (var i = 0; i < data.length; i++) {
      value += data[i];
    }

    return value / data.length;
  }
}

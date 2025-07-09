import 'dart:math';
import 'dart:typed_data';

/// Enumeration of different audio intensity calculation methods.
enum AudioIntensityMethod {
  /// Root Mean Square - provides smooth, averaged intensity values
  rms,

  /// Peak amplitude - most responsive to loud sounds
  peak,

  /// Average absolute value - balanced between RMS and peak
  averageAbsolute,

  /// Logarithmic RMS - RMS with logarithmic scaling for better perception
  logarithmicRms,

  /// Logarithmic peak - Peak with logarithmic scaling
  logarithmicPeak,
}

/// Calculates the audio intensity from a PCM 16-bit audio stream.
///
/// The function takes a [Uint8List] of PCM 16-bit audio data in little-endian
/// format and mono channel.
///
/// [method] determines the calculation approach used.
/// [sensitivity] adjusts the responsiveness (1.0 = normal, >1.0 = more sensitive).
/// [smoothing] applies smoothing to reduce noise (0.0 = no smoothing, 1.0 = max smoothing).
///
/// The function returns a double between 0 and 1, representing the intensity
/// of the audio.
double getAudioIntensityFromPcm16(
  Uint8List bytes, {
  AudioIntensityMethod method = AudioIntensityMethod.logarithmicPeak,
  double sensitivity = 1.0,
}) {
  if (bytes.length % 2 != 0) {
    throw ArgumentError('Byte length must be even for 16-bit PCM data.');
  }

  final int sampleCount = bytes.length ~/ 2;
  if (sampleCount == 0) return 0.0;

  // Convert bytes to normalized samples
  final List<double> samples = _convertBytesToSamples(bytes);

  // Calculate intensity based on selected method
  double intensity;
  switch (method) {
    case AudioIntensityMethod.rms:
      intensity = _calculateRms(samples);
      break;
    case AudioIntensityMethod.peak:
      intensity = _calculatePeak(samples);
      break;
    case AudioIntensityMethod.averageAbsolute:
      intensity = _calculateAverageAbsolute(samples);
      break;
    case AudioIntensityMethod.logarithmicRms:
      intensity = _calculateLogarithmicRms(samples);
      break;
    case AudioIntensityMethod.logarithmicPeak:
      intensity = _calculateLogarithmicPeak(samples);
      break;
  }

  // Apply sensitivity adjustment
  intensity = _applySensitivity(intensity, sensitivity);

  // Ensure the intensity is between 0 and 1
  return intensity.clamp(0.0, 1.0);
}

/// Converts PCM 16-bit bytes to normalized samples in range [-1.0, 1.0].
List<double> _convertBytesToSamples(Uint8List bytes) {
  final List<double> samples = [];

  for (int i = 0; i < bytes.length; i += 2) {
    // Combine two bytes to form a 16-bit sample in little-endian format.
    // bytes[i] is the least significant byte.
    int sample = bytes[i] | (bytes[i + 1] << 8);

    // Convert to signed 16-bit integer.
    if (sample >= 0x8000) {
      sample = sample - 0x10000;
    }

    // Normalize the sample to range [-1.0, 1.0]
    double normalizedSample = sample / 32768.0;
    samples.add(normalizedSample);
  }

  return samples;
}

/// Calculates Root Mean Square (RMS) intensity.
/// Provides smooth, averaged intensity values.
double _calculateRms(List<double> samples) {
  double sumOfSquares = 0.0;

  for (double sample in samples) {
    sumOfSquares += sample * sample;
  }

  return sqrt(sumOfSquares / samples.length);
}

/// Calculates peak amplitude intensity.
/// Most responsive to loud sounds.
double _calculatePeak(List<double> samples) {
  double maxAmplitude = 0.0;

  for (double sample in samples) {
    double amplitude = sample.abs();
    if (amplitude > maxAmplitude) {
      maxAmplitude = amplitude;
    }
  }

  return maxAmplitude;
}

/// Calculates average absolute value intensity.
/// Balanced between RMS and peak methods.
double _calculateAverageAbsolute(List<double> samples) {
  double sum = 0.0;

  for (double sample in samples) {
    sum += sample.abs();
  }

  return sum / samples.length;
}

/// Calculates logarithmic RMS intensity.
/// RMS with logarithmic scaling for better human perception.
double _calculateLogarithmicRms(List<double> samples) {
  double rms = _calculateRms(samples);
  return _applyLogarithmicScaling(rms);
}

/// Calculates logarithmic peak intensity.
/// Peak with logarithmic scaling for better human perception.
double _calculateLogarithmicPeak(List<double> samples) {
  double peak = _calculatePeak(samples);
  return _applyLogarithmicScaling(peak);
}

/// Applies logarithmic scaling to convert linear amplitude to perceptual intensity.
/// Uses decibel conversion with proper normalization.
double _applyLogarithmicScaling(double linearValue) {
  if (linearValue <= 0.0) return 0.0;

  // Convert to decibels (20 * log10(amplitude))
  double db = 20 * log(linearValue) / ln10;

  // Normalize from typical range [-60dB to 0dB] to [0.0 to 1.0]
  // -60dB represents very quiet, 0dB represents maximum
  const double minDb = -60.0;
  const double maxDb = 0.0;

  // Clamp and normalize
  db = db.clamp(minDb, maxDb);
  double normalized = (db - minDb) / (maxDb - minDb);

  return normalized;
}

/// Applies sensitivity adjustment to the intensity value.
/// Values > 1.0 make the intensity more sensitive, < 1.0 less sensitive.
double _applySensitivity(double intensity, double sensitivity) {
  if (sensitivity == 1.0) return intensity;

  // Apply power curve for sensitivity adjustment
  return pow(intensity, 1.0 / sensitivity).toDouble();
}

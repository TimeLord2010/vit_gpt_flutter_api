import 'dart:math';
import 'dart:typed_data';

/// Calculates the intensity of an audio unit in decibels.
///
/// [value] should be a negative number representing the decibels. This value
/// should not be above [maximum] or below [minimum].
double getAudioIntensity({
  required double value,
  double maximum = 0,
  double minimum = -70,
}) {
  assert(value <= 0);
  assert(value <= maximum);
  assert(value >= minimum);

  var percent = (value - minimum) / (maximum - minimum);

  // Limits the percentage to 0 and 1.
  if (percent < 0) {
    percent = 0;
  } else if (percent > 1) {
    percent = 1;
  }

  return percent;
}

/// Calculates the audio intensity from a PCM 16-bit audio stream.
///
/// The function takes a [Uint8List] of PCM 16-bit audio data in little-endian
/// format and mono channel.
///
/// The function returns a double between 0 and 1, representing the intensity
/// of the audio.
double getAudioIntensityFromPcm16(Uint8List bytes) {
  if (bytes.length % 2 != 0) {
    throw ArgumentError('Byte length must be even for 16-bit PCM data.');
  }

  final int sampleCount = bytes.length ~/ 2;
  if (sampleCount == 0) return 0.0;

  double sumOfSquares = 0.0;

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

    // Accumulate the square of the sample
    sumOfSquares += normalizedSample * normalizedSample;
  }

  // Calculate RMS (Root Mean Square)
  double rms = sqrt(sumOfSquares / sampleCount);

  // Ensure the intensity is between 0 and 1
  // RMS should already be in this range, but clamp to be safe.
  return rms.clamp(0.0, 1.0);
}

import 'package:flutter_test/flutter_test.dart';
import 'package:vit_gpt_flutter_api/features/usecases/audio/get_audio_intensity.dart';

void main() {
  double calc(double value) {
    return getAudioIntensity(
      value: value,
      maximum: 0,
      minimum: -100,
    );
  }

  group('get audio intensity', () {
    test('should return 1', () {
      expect(calc(0), 1);
    });

    test('should return 0', () {
      expect(calc(-100), 0);
    });

    test('should return 0.5', () {
      expect(calc(-50), equals(0.5));
    });

    test('should return 0.75', () {
      expect(calc(-25), equals(0.75));
    });

    test('should default to 1 for values greater than the maximum', () {
      expect(calc(10), 1);
    });

    test('should default to 0 for values smaller than the minimum', () {
      expect(calc(-200), 0);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Pitch Shifter Core Frequency Math Tests', () {
    test('Standard 440 Hz frequency ratio should equal 1.0', () {
      const double standardHz = 440.0;
      const double targetHz = 440.0;
      final double ratio = targetHz / standardHz;

      expect(ratio, equals(1.0));
    });

    test('432 Hz target ratio calculation should match theoretical value', () {
      const double standardHz = 440.0;
      const double targetHz = 432.0;
      final double ratio = targetHz / standardHz;

      // 432 / 440 ≈ 0.9818181818181818
      expect(ratio, closeTo(0.9818, 0.0001));
    });

    test('528 Hz target ratio calculation should match theoretical value', () {
      const double standardHz = 440.0;
      const double targetHz = 528.0;
      final double ratio = targetHz / standardHz;

      // 528 / 440 = 1.2
      expect(ratio, equals(1.2));
    });

    test('FFmpeg asetrate and atempo scaling factors calculation', () {
      const double targetHz = 432.0;
      const double standardHz = 440.0;

      final double ratio = targetHz / standardHz;

      // Calculate speed ratio & sample rate
      const double baseSampleRate = 44100.0;
      final double targetSampleRate = baseSampleRate * ratio;
      final double targetTempo = 1.0 / ratio;

      expect(targetSampleRate, closeTo(43298.18, 0.1));
      expect(targetTempo, closeTo(1.0185, 0.0001));
    });
  });
}

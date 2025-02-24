import 'dart:typed_data';

import 'package:record/record.dart';
import 'package:vit_gpt_dart_api/vit_gpt_dart_api.dart';

import '../../usecases/audio/get_audio_intensity.dart';

class VitAudioRecorder extends AudioRecorderModel {
  final _recorder = AudioRecorder();

  @override
  Future<double> get amplitude async {
    var amp = await _recorder.getAmplitude();
    return _calcFromAmp(amp);
  }

  @override
  Future<void> dispose() async {
    await _recorder.dispose();
  }

  @override
  Stream<double> onAmplitude([Duration? duration]) {
    duration ??= const Duration(milliseconds: 200);
    var stream = onRawAmplitude(duration);
    return stream.map((raw) => getAudioIntensity(value: raw));
  }

  @override
  Future<bool> requestPermission() async {
    var hasPermission = await _recorder.hasPermission();
    return hasPermission;
  }

  @override
  Future<void> start() async {
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.wav),
      path: '${VitGptConfiguration.internalFilesDirectory.path}/myInput.wav',
    );
  }

  Future<Stream<Uint8List>> startStream() {
    return _recorder.startStream(RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 24000,
      echoCancel: true,
    ));
  }

  @override
  Future<String?> stop() async {
    var result = _recorder.stop();
    return result;
  }

  @override
  Stream<double> onRawAmplitude([Duration? duration]) {
    duration ??= const Duration(milliseconds: 200);
    var stream = _recorder.onAmplitudeChanged(duration);
    return stream.map((x) {
      var current = x.current;
      //logger.debug('Audio intensity: $current');
      return current;
    });
  }

  Future<bool> isRecording() {
    return _recorder.isRecording();
  }
}

double _calcFromAmp(Amplitude amp) {
  var current = amp.current;
  var value = getAudioIntensity(
    value: current,
    maximum: -5,
    minimum: -70,
  );
  // logger.debug('Audio intensity ($current): $value');
  return value;
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:vit_gpt_dart_api/vit_gpt_dart_api.dart' as api;
import 'package:vit_gpt_flutter_api/data/vit_gpt_configuration.dart';

class SoLoudAudioPlayer extends api.SimpleAudioPlayer {
  final String path;
  final player = SoLoud.instance;
  final bool isAsset;

  SoLoudAudioPlayer(
    this.path, {
    this.isAsset = false,
  });

  AudioSource? source;
  SoundHandle? soundHandle;
  Duration? totalDuration;

  @override
  Future<void> play() async {
    if (!player.isInitialized) {
      await player.init(
        automaticCleanup: true,
      );
    }

    if (path.startsWith('data:')) {
      final base64String = path.split(',').last;
      final pcmBytes = base64Decode(base64String);

      final wavData = _createWavFromPcm(pcmBytes);

      source = await player.loadMem('audio', wavData);
    } else if (isAsset) {
      source = await player.loadAsset(path);
    } else {
      source = await player.loadFile(path);
    }

    totalDuration = player.getLength(source!);

    soundHandle = await player.play(source!);

    var completer = Completer();

    Timer.periodic(Duration(milliseconds: 100), (t) {
      try {
        var position = player.getPosition(soundHandle!);
        if (position >= totalDuration! || position == Duration.zero) {
          t.cancel();
          completer.complete();
        }
      } on Exception catch (e) {
        VitGptFlutterConfiguration.logger.e('Error in play', error: e);
        t.cancel();
        completer.completeError(e);
      }
    });

    return completer.future;
  }

  @override
  Future<void> stop() async {
    await dispose();
  }

  @override
  Future<void> dispose() async {
    if (source != null) {
      await player.disposeSource(source!);
    }
    source = null;
    soundHandle = null;
  }

  @override
  Future<void> pause() async {
    var handle = soundHandle;
    if (handle == null) return;
    player.setPause(handle, true);
  }

  @override
  double get positionInSeconds {
    var handle = soundHandle;
    if (handle == null) return 0;
    return player.getPosition(handle).inMilliseconds / 1000;
  }

  int get positionInMs {
    var handle = soundHandle;
    if (handle == null) return 0;
    return player.getPosition(handle).inMilliseconds;
  }

  @override
  api.PlayerState get state {
    var handle = soundHandle;
    if (handle == null) return api.PlayerState.stopped;

    var isPaused = player.getPause(handle);
    if (isPaused) return api.PlayerState.paused;

    return api.PlayerState.playing;
  }

  @override
  Stream<double>? getVolumeIntensity() {
    return null;
  }

  @override
  Future<void> seekTo(Duration position) async {
    if (soundHandle == null || totalDuration == null) {
      debugPrint('Cannot seek: audio not playing');
      return;
    }

    Duration clampedPosition;
    if (position < Duration.zero) {
      clampedPosition = Duration.zero;
    } else if (position > totalDuration!) {
      clampedPosition = totalDuration!;
    } else {
      clampedPosition = position;
    }

    try {
      player.seek(soundHandle!, clampedPosition);
      debugPrint('Seeked to position: $clampedPosition');
    } catch (e) {
      debugPrint('Error seeking to position $position: $e');
    }
  }

  Uint8List _createWavFromPcm(Uint8List pcmData) {
    const int sampleRate = 24000;
    const int bitsPerSample = 16;
    const int channels = 1;
    const int byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    const int blockAlign = channels * bitsPerSample ~/ 8;

    final int dataSize = pcmData.length;
    final int fileSize = 36 + dataSize;

    final header = ByteData(44);

    header.setUint8(0, 0x52);
    header.setUint8(1, 0x49);
    header.setUint8(2, 0x46);
    header.setUint8(3, 0x46);
    header.setUint32(4, fileSize, Endian.little);
    header.setUint8(8, 0x57);
    header.setUint8(9, 0x41);
    header.setUint8(10, 0x56);
    header.setUint8(11, 0x45);

    header.setUint8(12, 0x66);
    header.setUint8(13, 0x6D);
    header.setUint8(14, 0x74);
    header.setUint8(15, 0x20);
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);

    header.setUint8(36, 0x64);
    header.setUint8(37, 0x61);
    header.setUint8(38, 0x74);
    header.setUint8(39, 0x61);
    header.setUint32(40, dataSize, Endian.little);

    final wavData = Uint8List(44 + dataSize);
    wavData.setRange(0, 44, header.buffer.asUint8List());
    wavData.setRange(44, 44 + dataSize, pcmData);

    return wavData;
  }
}

import 'dart:async';
import 'dart:math';

import 'package:just_audio/just_audio.dart';
import 'package:vit_gpt_dart_api/vit_gpt_dart_api.dart' as api;

class JustAudioPlayer extends api.SimpleAudioPlayer {
  final player = AudioPlayer();

  final String path;
  final bool isAsset;
  final bool randomizeVolumeStream;

  JustAudioPlayer(
    this.path, {
    this.isAsset = false,
    this.randomizeVolumeStream = false,
  });

  /// Mock volume stream.
  StreamController<double> _volumeStreamController = StreamController<double>();

  @override
  Future<void> dispose() async {
    await player.dispose();
    await _volumeStreamController.close();
  }

  @override
  Future<void> pause() async {
    await player.pause();
  }

  @override
  Future<void> play() async {
    if (isAsset) {
      // await player.setAsset(path);
      // await player.setAudioSource(AudioSource.asset(path));
      // await player.setAudioSource(AudioSource.uri(Uri.parse('asset:///$path')));
      await player.setUrl('asset:///$path');
    } else {
      await player.setFilePath(path);
    }

    var completer = Completer();
    Timer? timer;

    if (randomizeVolumeStream) {
      var random = Random();
      timer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
        var value = (5 + random.nextInt(5)) / 10;
        _volumeStreamController.add(value);
      });
    }

    unawaited(player.play().then((_) {
      _volumeStreamController.close();
      _volumeStreamController = StreamController<double>();
      completer.complete();
    }));

    await completer.future;
    timer?.cancel();
  }

  @override
  Future<void> seekTo(Duration position) {
    // TODO: implement seekTo
    throw UnimplementedError();
  }

  @override
  double get positionInSeconds => player.position.inMilliseconds / 1000;

  @override
  api.PlayerState get state {
    var innerState = player.playerState.processingState;
    return switch (innerState) {
      ProcessingState.buffering => api.PlayerState.playing,
      ProcessingState.ready => api.PlayerState.playing,
      ProcessingState.completed => api.PlayerState.stopped,
      ProcessingState.idle => api.PlayerState.paused,
      ProcessingState.loading => api.PlayerState.paused,
    };
  }

  @override
  Future<void> stop() async {
    await player.stop();
  }

  @override
  Stream<double>? getVolumeIntensity() {
    if (!randomizeVolumeStream) {
      return null;
    }
    return _volumeStreamController.stream;
  }
}

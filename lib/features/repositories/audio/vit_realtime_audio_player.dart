import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_sound/flutter_sound.dart';
import 'package:logger/logger.dart' show Level;
import 'package:vit_gpt_dart_api/factories/logger.dart';
import 'package:vit_gpt_flutter_api/data/contracts/realtime_audio_player.dart';
import 'package:vit_gpt_flutter_api/features/repositories/buffered_data_handler.dart';

/// A audio player that plays audio in realtime by receiving Uint8List data or
/// base64 encoded strings.
class VitRealtimeAudioPlayer with RealtimeAudioPlayer {
  /// The player instance.
  ///
  /// If we don't disable the log level, we will see a lot of logs in the
  /// console by default.
  final _player = FlutterSoundPlayer(
    logLevel: Level.off,
  );

  VitRealtimeAudioPlayer() {
    unawaited(_setup());
  }

  /// Controls the cadence of data being sent to the player.
  ///
  /// If we don't control the cadence of data being sent to the player,
  /// the player will cut off parts of the audio.
  /// This was observed using "flutter_sound" on version 9.23.1 when running
  /// on IOS. If this is no longer true in the future, we can remove this.
  late final _bufferHandler = BufferedDataHandler(
    (base64) {
      logger.debug('Adding data to player: ${base64.length} of length');
      var bytes = base64Decode(base64);
      appendBytes(bytes);
    },
    interval: Duration(milliseconds: 1200),
  );

  Future<void> _setup() async {
    await _player.openPlayer();
  }

  @override
  Future<void> appendBytes(Uint8List audioData) async {
    // We are not worried here about the player not being open YET (see
    //[appendData] explanation). But that the player was disposed.
    if (!_player.isOpen()) {
      return;
    }

    // A better implementation would buffer the data here instead of the base64
    // string (a new buffer class is required).
    // But this works since the current implementation sends the data only in
    // string format.

    await _player.feedUint8FromStream(audioData);
  }

  @override
  void appendData(String base64Data) {
    // Technically, this method could be called before the player is open or
    // the buffer stream is created. But we don't want to wait for any of
    // these to be ready before we start receiving data because the current
    // usecase is the realtime feature of the app, and the way it works is: we
    // first need to wait for the user to speak and then we start receiving
    // data. By that time, the player and stream should be ready.
    _bufferHandler.addData(base64Data);
  }

  @override
  Future<void> createBufferStream() async {
    // Since we are not waiting for the [_setup] to complete, we need to wait
    // for the player to be open before creating the buffer stream.
    while (!_player.isOpen()) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // The player was made to work with open ai's realtime API, which only
    // supports PCM16 codec, mono audio, and 24000 sample rate.
    //
    // If you change the settings, make sure to make it customizable in the
    // [RealtimeAudioPlayer] interface or [VitRealtimeAudioPlayer] constructor
    // so it still works with open ai's realtime API.
    await _player.startPlayerFromStream(
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: 24000,
      bufferSize: 1024 * 20,
    );
  }

  @override
  Future<void> disposeBufferStream() async {
    // [stopPlayer] will complain in the logs if the player is not open.
    var isOpen = _player.isOpen();
    if (!isOpen) return;

    await _player.stopPlayer();
  }

  @override
  Future<void> dispose() async {
    await _player.closePlayer();
  }
}

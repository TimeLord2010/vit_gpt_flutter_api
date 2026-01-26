import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:vit_gpt_flutter_api/data/vit_gpt_configuration.dart';

mixin RealtimeAudioPlayer {
  /// A stream that sends events everytime the audio stream finishes playing
  /// the audio from the buffer.
  Stream<void> get stopPlayStream;

  /// A stream that sends audio every interval to show the audio level being
  /// played. This value of the event is a number between 0 and 1.
  Stream<double> get volumeStream;

  Future<void> createBufferStream();

  void disposeBufferStream();

  void appendBytes(Uint8List audioData);

  /// Signals that no more audio data will be sent to the stream.
  /// Call this method when the audio stream has ended to properly
  /// finish playback without relying on timeout-based detection.
  void completeStream();

  void dispose();

  void appendData(String base64Data) {
    var bytes = base64Decode(base64Data);
    appendBytes(bytes);
  }

  void resetBuffer() {
    var logger = VitGptFlutterConfiguration.logger;
    logger.d('Reseting realtime audio player stream');
    disposeBufferStream();
    createBufferStream();
  }

  Future<void> play();

  Future<void> pause();

  bool get isPaused;
}

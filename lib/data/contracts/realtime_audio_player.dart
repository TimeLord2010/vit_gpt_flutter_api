import 'dart:convert';
import 'dart:typed_data';

import 'package:vit_gpt_dart_api/data/configuration.dart';

mixin RealtimeAudioPlayer {
  Future<void> createBufferStream();

  void disposeBufferStream();

  void appendBytes(Uint8List audioData);

  void dispose();

  void appendData(String base64Data) {
    var bytes = base64Decode(base64Data);
    appendBytes(bytes);
  }

  void resetBuffer() {
    VitGptConfiguration.logger.d('Reseting realtime audio player stream');
    disposeBufferStream();
    createBufferStream();
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:vit_gpt_flutter_api/data/vit_gpt_configuration.dart';

mixin RealtimeAudioPlayer {
  Stream<void> get stopPlayStream;

  Future<void> createBufferStream();

  void disposeBufferStream();

  void appendBytes(Uint8List audioData);

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
}

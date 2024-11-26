import 'dart:typed_data';

import 'package:chatgpt_chat/data/enums/voices.dart';
import 'package:chatgpt_chat/factories/logger.dart';
import 'package:chatgpt_chat/repositories/tts/aws_tts.dart';
import 'package:chatgpt_chat/repositories/tts/google_tts.dart';
import 'package:vit_gpt_dart_api/vit_gpt_dart_api.dart';

class LeiaTts extends TTSModel {
  @override
  Stream<Uint8List> getAudio({
    required String voice,
    required String input,
    bool highQuality = false,
    AudioFormat? format,
  }) {
    // logger.info('Incoming tts voice: $voice');
    var choosenVoice = Voice.fromString(voice);

    TTSModel model;

    if (choosenVoice.isAws) {
      logger.info('AWS TTS selected');
      model = AwsTts();
    } else if (choosenVoice.isGoogle) {
      logger.info('Google TTS selected');
      model = GoogleTts();
    } else {
      logger.info('OpenAI TTS selected');
      model = TTSRepository();
    }

    return model.getAudio(
      voice: choosenVoice.nativeVoice,
      input: input,
      highQuality: highQuality,
      format: format,
    );
  }

  @override
  Future<List<String>> getVoices() async {
    return Voice.values.map((x) => x.toString()).toList();
  }
}

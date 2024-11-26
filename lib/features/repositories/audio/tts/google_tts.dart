import 'dart:typed_data';

import 'package:chatgpt_chat/data/configuration.dart';
import 'package:dio/dio.dart';
import 'package:vit_gpt_dart_api/vit_gpt_dart_api.dart';

class GoogleTts extends TTSModel {
  @override
  Stream<Uint8List> getAudio({
    required String voice,
    required String input,
    bool highQuality = false,
    AudioFormat? format,
  }) async* {
    var dio = Dio();
    var response = await dio.post(
      'http://___:3001/audio/google/tts',
      data: {
        'text': input,
      },
      options: Options(
        headers: {
          'api-key': Configuration.apiKey,
        },
        responseType: ResponseType.bytes,
      ),
    );

    Uint8List data = response.data;
    yield data;
  }

  @override
  Future<List<String>> getVoices() async {
    return [
      'WaveNet-D',
    ];
  }
}

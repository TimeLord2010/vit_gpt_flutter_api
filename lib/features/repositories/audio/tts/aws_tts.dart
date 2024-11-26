import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:vit_gpt_dart_api/data/enums/audio_format.dart';
import 'package:vit_gpt_dart_api/data/interfaces/tts_model.dart';

class AwsTts extends TTSModel {
  @override
  Stream<Uint8List> getAudio({
    required String voice,
    required String input,
    bool highQuality = false,
    AudioFormat? format,
  }) async* {
    // var allVoices = await getVoices();
    // var validVoice = allVoices.firstWhereOrNull((x) {
    //       return x == voice;
    //     }) ??
    //     allVoices.first;

    var dio = Dio();
    var response = await dio.post(
      'http://___:3001/audio/tts',
      data: {
        'text': input,
        'voiceId': 'Thiago',
        'engine': 'neural',
      },
      options: Options(
        headers: {
          'api-key': Configuration.apiKey,
        },
        responseType: ResponseType.stream,
      ),
    );
    var data = response.data;
    Stream<Uint8List> stream = data.stream;
    yield* stream;
  }

  @override
  Future<List<String>> getVoices() async {
    return [
      'Vitoria',
      'Camila',
      'Thiago',
      'Ricardo',
    ];
  }
}

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vit_gpt_dart_api/vit_gpt_dart_api.dart';
import 'package:vit_gpt_flutter_api/factories/create_grouped_logger.dart';
import 'package:vit_gpt_flutter_api/features/repositories/audio/players/vit_audio_player.dart';

import '../repositories/audio/vit_audio_recorder.dart';
import '../repositories/local_storage_repository.dart';

Future<void> setupUI({
  String? openAiKey,
}) async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeLogOutputs();

  List<LogOutput> outputs = [ConsoleOutput()];

  DynamicFactories.logger = (tag) {
    return Logger(
      output: MultiOutput(outputs),
      printer: GptFlutterLogGroup(
        tags: ['VitGptDart', if (tag != null) tag],
        appendFlutterApiPrefix: false,
      ),
      filter: GptFlutterLogFilter(),
    );
  };

  if (!GetIt.I.isRegistered<SharedPreferences>()) {
    var sp = await SharedPreferences.getInstance();
    GetIt.I.registerSingleton(sp);
  }

  // Setting up local storage
  var sp = GetIt.I.get<SharedPreferences>();
  var localStorageRepository = LocalStorageRepository(sp);
  await localStorageRepository.prepare();
  if (!GetIt.I.isRegistered<LocalStorageModel>()) {
    GetIt.I.registerSingleton<LocalStorageModel>(localStorageRepository);
  }

  DynamicFactories.localStorage = () => LocalStorageRepository(sp);

  //VitGptDartConfiguration.internalFilesDirectory = appDocDir;

  // Setting input and output audio classes.
  DynamicFactories.recorder = () => VitAudioRecorder();
  DynamicFactories.simplePlayer = (file) {
    return VitAudioPlayer(
      audioPath: file.path,
      randomizeVolumeStream: true,
    ).getPlayer();
  };

  VitGptDartConfiguration.useHighQualityTts = false;
  VitGptDartConfiguration.ttsFormat = AudioFormat.mp3;

  // Setting the API token to the http client.
  if (openAiKey != null) {
    await updateApiToken(openAiKey);
  }
}

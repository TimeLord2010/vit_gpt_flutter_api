import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/web.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vit_gpt_dart_api/vit_gpt_dart_api.dart';
import 'package:vit_gpt_flutter_api/data/vit_gpt_configuration.dart';
import 'package:vit_gpt_flutter_api/features/repositories/audio/players/vit_audio_player.dart';

import '../repositories/audio/vit_audio_recorder.dart';
import '../repositories/local_storage_repository.dart';

Future<void> setupUI({
  String? openAiKey,
  TTSModel Function()? tts,
}) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isIOS) {
    VitGptFlutterConfiguration.logger
        .d('Disabling colors on logs since we are in IOS');
    VitGptConfiguration.logger = Logger(
      printer: SimplePrinter(colors: false),
    );
  }

  var sp = await SharedPreferences.getInstance();
  GetIt.I.registerSingleton(sp);

  Directory appDocDir = await getApplicationDocumentsDirectory();
  String dbPath = '${appDocDir.path}${Platform.pathSeparator}local_storage.db';
  Database db = sqlite3.open(dbPath);
  var localStorageRepository = LocalStorageRepository(sp, db);
  await localStorageRepository.prepare();

  GetIt.I.registerSingleton(localStorageRepository);

  setupFactories(
    localStorage: () => LocalStorageRepository(sp, db),
    recorder: () => VitAudioRecorder(),
    tts: tts,
    simplePlayerFactory: (file) {
      return VitAudioPlayer(
        audioPath: file.path,
        randomizeVolumeStream: true,
      ).getPlayer();
    },
  );

  var directory = await getApplicationDocumentsDirectory();
  VitGptConfiguration.internalFilesDirectory = directory;

  VitGptConfiguration.useHighQualityTts = false;
  VitGptConfiguration.ttsFormat = AudioFormat.mp3;

  // Setting the API token to the http client.
  if (openAiKey != null) {
    await updateApiToken(openAiKey);
  }
}

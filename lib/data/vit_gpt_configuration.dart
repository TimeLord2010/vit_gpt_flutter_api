import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:logger/logger.dart';
import 'package:vit_gpt_flutter_api/data/contracts/realtime_audio_player.dart';
import 'package:vit_gpt_flutter_api/factories/create_grouped_logger.dart';

class VitGptFlutterConfiguration {
  /// Called when the user finishes speaking.
  static FutureOr<void> Function()? onListenEnd;

  /// Used to play audio when using the realtime API
  static RealtimeAudioPlayer Function()? realtimeAudioPlayer;

  static var logger = Logger(
    printer: SimplePrinter(
      colors: !kIsWeb && !Platform.isIOS,
    ),
    level: Level.debug,
  );

  static Logger Function(List<String> tags) groupedLogsFactory = createGroupedLogger;
}

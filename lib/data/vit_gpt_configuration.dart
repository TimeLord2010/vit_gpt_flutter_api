import 'dart:async';
import 'dart:io';

import 'package:logger/logger.dart';
import 'package:vit_gpt_flutter_api/data/contracts/realtime_audio_player.dart';
import 'package:vit_gpt_flutter_api/factories/create_grouped_logger.dart';

class VitGptFlutterConfiguration {
  /// Called when the user finishes speaking.
  static FutureOr<void> Function()? onListenEnd;

  /// Used to play audio when using the realtime API
  static RealtimeAudioPlayer Function()? realtimeAudioPlayer;

  static var logger = Logger(
    // filter: AlwaysLogFilter(),
    printer: SimplePrinter(
      colors: !Platform.isIOS,
    ),
    level: Level.error,
  );

  static Logger Function(List<String> tags) groupedLogsFactory =
      createGroupedLogger;
}

// class AlwaysLogFilter extends LogFilter {
//   @override
//   bool shouldLog(LogEvent event) => true;
// }

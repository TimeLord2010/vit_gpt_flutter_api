import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vit_gpt_flutter_api/features/usecases/get_error_message.dart';

Future<List<LogOutput>> getPlatformSpecificOutputs({
  required String tag,
}) async {
  try {
    // Get application support directory (writable and hidden from user)
    final appSupportDir = await getApplicationSupportDirectory();
    final logsPath = '${appSupportDir.path}/logs';

    // Create logs directory if it doesn't exist
    final logsDir = Directory(logsPath);
    if (!await logsDir.exists()) {
      await logsDir.create(recursive: true);
    }

    // Create log file with date and tag
    final dtKey = DateTime.now().toIso8601String().split('T')[0];
    var path = '$logsPath/${dtKey}_$tag.txt';
    debugPrint('Logs will also be stored in the file $path');
    final file = File(path);

    return [
      ConsoleOutput(),
      FileOutput(file: file),
    ];
  } catch (e) {
    debugPrint('Failed to create file log output: ${getErrorMessage(e)}');
    // Fallback to console-only logging if file creation fails
    return [ConsoleOutput()];
  }
}

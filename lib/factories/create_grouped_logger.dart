import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:vit_gpt_flutter_api/features/usecases/get_error_message.dart';

import '../features/usecases/setup_ui_stub.dart'
    if (dart.library.io) '../features/usecases/setup_ui_io.dart';

class GptFlutterLogGroup extends LogPrinter {
  final List<String> tags;
  final String separator;
  final bool appendFlutterApiPrefix;

  GptFlutterLogGroup({
    required this.tags,
    this.separator = ':',
    this.appendFlutterApiPrefix = true,
  });

  static bool addTimeInfo = false;

  @override
  List<String> log(LogEvent event) {
    var prefix = [
      if (appendFlutterApiPrefix) 'VitGptFlutter',
      ...tags,
    ].where((x) => x.isNotEmpty).join(separator);
    var msg = event.message;
    var error = event.error;

    String getTimeStr() {
      var dt = DateTime.now();
      return dt.toIso8601String().split('T')[1];
    }

    return [
      if (addTimeInfo)
        '($prefix) [${event.level.name.toUpperCase()}] ${getTimeStr()}: $msg'
      else
        '($prefix) [${event.level.name.toUpperCase()}]: $msg',
      if (error != null) getErrorMessage(error) ?? '...',
    ];
  }
}

class GptFlutterLogFilter extends LogFilter {
  GptFlutterLogFilter();

  @override
  bool shouldLog(LogEvent event) => !kReleaseMode;
}

List<LogOutput>? _outputsCache;

Future<void> initializeLogOutputs() async {
  _outputsCache ??= await getPlatformSpecificOutputs(tag: 'gptflutter');
}

Logger createGptFlutterLogger(
  List<String> tags, {
  bool appendFlutterApiPrefix = true,
}) {
  List<LogOutput> outputsCache = _outputsCache ?? [ConsoleOutput()];
  return Logger(
    output: MultiOutput(outputsCache),
    printer: GptFlutterLogGroup(
      tags: tags,
      appendFlutterApiPrefix: appendFlutterApiPrefix,
    ),
    filter: GptFlutterLogFilter(),
  );
}

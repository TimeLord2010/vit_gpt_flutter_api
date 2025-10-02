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

  @override
  List<String> log(LogEvent event) {
    var dt = DateTime.now();
    var timeStr = dt.toIso8601String().split('T')[1];
    var prefix = [
      if (appendFlutterApiPrefix) 'VitGptFlutter',
      ...tags,
    ].where((x) => x.isNotEmpty).join(separator);
    var msg = event.message;
    var error = event.error;

    return [
      '($prefix) [${event.level.name.toUpperCase()}] $timeStr: $msg',
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
  assert(_outputsCache != null,
      'Call initializeLogOutputs() before creating loggers');

  return Logger(
    output: MultiOutput(_outputsCache!),
    printer: GptFlutterLogGroup(
      tags: tags,
      appendFlutterApiPrefix: appendFlutterApiPrefix,
    ),
    filter: GptFlutterLogFilter(),
  );
}

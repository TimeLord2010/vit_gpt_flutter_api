import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:vit_gpt_flutter_api/features/usecases/get_error_message.dart';

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

Logger createGptFlutterLogger(
  List<String> tags, {
  bool appendFlutterApiPrefix = true,
}) {
  return Logger(
    printer: GptFlutterLogGroup(
      tags: tags,
      appendFlutterApiPrefix: appendFlutterApiPrefix,
    ),
    filter: GptFlutterLogFilter(),
  );
}

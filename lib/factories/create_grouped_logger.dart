import 'package:logger/logger.dart';
import 'package:vit_gpt_flutter_api/features/usecases/get_error_message.dart';

class LogGroup extends LogPrinter {
  final List<String> tags;
  final String separator;

  LogGroup({
    required this.tags,
    this.separator = ':',
  });

  @override
  List<String> log(LogEvent event) {
    var prefix = ['VitGptFlutter', ...tags].join(separator);
    var msg = event.message;
    var error = event.error;

    return [
      '($prefix) [${event.level.name.toUpperCase()}] $msg',
      if (error != null) getErrorMessage(error) ?? '...',
    ];
  }
}

Logger createGroupedLogger(List<String> tags) {
  return Logger(
    // filter: AlwaysLogFilter(),
    printer: LogGroup(
      tags: tags,
    ),
  );
}

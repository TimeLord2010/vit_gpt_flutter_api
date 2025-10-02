import 'package:logger/logger.dart';

Future<List<LogOutput>> getPlatformSpecificOutputs({
  required String tag,
}) async {
  return [ConsoleOutput()];
}

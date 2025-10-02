import 'dart:io';

import 'package:logger/logger.dart';

Future<List<LogOutput>> getPlatformSpecificOutputs({
  required String tag,
}) async {
  var dtKey = DateTime.now().toIso8601String().split('T')[0];
  var file = File('./logs/${dtKey}_$tag.txt');
  await file.create(recursive: true);
  return [
    ConsoleOutput(),
    FileOutput(file: file),
  ];
}

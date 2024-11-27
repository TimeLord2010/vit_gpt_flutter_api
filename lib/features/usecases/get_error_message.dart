import 'dart:io';

import 'package:dio/dio.dart';

String? getErrorMessage(Object obj) {
  if (obj is AssertionError && obj.message != null) {
    return getErrorMessage(obj.message!);
  }
  if (obj is DioException) {
    var response = obj.response;
    if (response != null) {
      var data = response.data;
      if (data is Map<String, dynamic>) {
        var msg = _getMessageFromMap(data);
        if (msg != null) return msg;
      }
      var statusCode = response.statusCode;
      if (statusCode != null) {
        return 'Erro no servidor ($statusCode): ${response.statusMessage}';
      }
      if (data is String) {
        return data;
      }
    }
    var error = obj.error;
    if (error != null) {
      var msg = getErrorMessage(error);
      return 'Não foi possível conectar ao servidor: $msg';
    }
  }
  if (obj is SocketException) {
    var server = obj.address;
    var msg = obj.osError;
    return 'Não foi possível conectar ao servidor: $server. Mensagem: ${msg?.message}';
  }
  if (obj is Exception) {
    var message = obj.toString();
    message = message.replaceFirst(RegExp(r'^(Exception|Error):'), '');
    return message.trim();
  }
  if (obj is TypeError) {
    return obj.toString();
  }
  if (obj is Error) {
    var msg = obj.toString();
    return msg;
  }
  if (obj is String) {
    return obj;
  }
  return null;
}

String? _getMessageFromMap(Map<String, dynamic> map) {
  var msg = map['message'];
  if (msg is String) {
    return msg;
  }
  var error = map['error'];
  if (error is Map<String, dynamic>) {
    return _getMessageFromMap(error);
  }
  if (map case {'name': 'ZodError', 'map': Map<String, dynamic> innerMap}) {
    var entries = innerMap.entries;
    if (entries.isNotEmpty) {
      var entry = entries.first;
      var value = entry.value;
      if (value is String) {
        return '${entry.key}: $value';
      }
      if (value case List errors) {
        if (errors.every((x) => x is String)) {
          return '${entry.key}: ${errors.join(' AND ')}';
        }
      }
    }
  }
  return null;
}

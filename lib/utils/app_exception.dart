import 'dart:io';

import 'package:pocketbase/pocketbase.dart';

/// A user-facing error. Every repository/service call that can fail should
/// throw this (or let it propagate from [asAppException]) so every screen
/// can show one consistent, human message instead of a raw stack trace.
class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => message;
}

/// Converts any error thrown by a PocketBase call into a friendly
/// [AppException].
AppException asAppException(Object error) {
  if (error is AppException) return error;

  if (error is SocketException || error is HttpException) {
    return const AppException(
      "Can't reach the server — check you're connected to the office WiFi.",
    );
  }

  if (error is ClientException) {
    if (error.statusCode == 0 || error.originalError != null) {
      return const AppException(
        "Can't reach the server — check you're connected to the office WiFi "
            "and that the server address in Settings is correct.",
      );
    }

    if (error.statusCode == 401 || error.statusCode == 403) {
      return const AppException(
        'Your session has expired or you don\'t have permission to do that. '
            'Please log in again.',
      );
    }

    if (error.statusCode == 404) {
      return const AppException('That record could not be found.');
    }

    final response = error.response;
    final data = response['data'];
    if (data is Map && data.isNotEmpty) {
      final firstField = data.values.first;
      if (firstField is Map && firstField['message'] is String) {
        return AppException(firstField['message'] as String);
      }
    }
    if (response['message'] is String) {
      return AppException(response['message'] as String);
    }

    return const AppException(
      'Something went wrong talking to the server. Please try again.',
    );
  }

  return const AppException('Something went wrong. Please try again.');
}
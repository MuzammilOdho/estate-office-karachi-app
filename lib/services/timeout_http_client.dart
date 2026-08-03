import 'dart:async';

import 'package:http/http.dart' as http;

/// An [http.Client] that applies a total-request [timeout] to every
/// request, regardless of which method initiates it. Used as the
/// PocketBase SDK's underlying client so every SDK call (getFullList,
/// getList, create, update, file token, etc.) inherits the timeout
/// automatically — no per-call `.timeout()` needed.
///
/// On timeout the future completes with a [TimeoutException], which
/// [asAppException] maps to the friendly "server didn't respond" message,
/// so the existing retry views handle it.
class TimeoutHttpClient extends http.BaseClient {
  TimeoutHttpClient(this._inner, this.timeout);

  final http.Client _inner;
  final Duration timeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request).timeout(timeout);
  }

  @override
  void close() => _inner.close();
}

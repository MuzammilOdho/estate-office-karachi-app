import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';
import 'timeout_http_client.dart';

/// Owns the single [PocketBase] client used by the whole app.
class PocketBaseService {
  PocketBaseService._internal();
  static final PocketBaseService instance = PocketBaseService._internal();

  PocketBase? _pb;

  PocketBase get client {
    final pb = _pb;
    if (pb == null) {
      throw StateError(
        'PocketBaseService.init() must be called before use.',
      );
    }
    return pb;
  }

  bool get isReady => _pb != null;

  bool get isLoggedIn => _pb?.authStore.isValid ?? false;

  /// LAN-appropriate request timeout. A hung request on the office LAN
  /// (server busy mid-backup, WiFi AP saturated) should fail fast into
  /// the friendly retry view rather than spin forever. 12s is generous
  /// for even a slow query against a 10k-unit estate over WiFi.
  static const requestTimeout = Duration(seconds: 12);

  Future<void> init(String baseUrl) async {
    final prefs = await SharedPreferences.getInstance();

    final authStore = AsyncAuthStore(
      save: (String data) async {
        await prefs.setString(PrefsKeys.pbAuthStore, data);
      },
      initial: prefs.getString(PrefsKeys.pbAuthStore),
      clear: () async {
        await prefs.remove(PrefsKeys.pbAuthStore);
      },
    );

    _pb = PocketBase(
      baseUrl,
      authStore: authStore,
      // Wrap every SDK HTTP call in the shared LAN timeout so a hung
      // request fails fast into the retry view instead of spinning.
      httpClientFactory: () => TimeoutHttpClient(http.Client(), requestTimeout),
    );
  }

  Future<void> updateBaseUrl(String baseUrl) async {
    await init(baseUrl);
  }

  void logout() {
    _pb?.authStore.clear();
  }
}
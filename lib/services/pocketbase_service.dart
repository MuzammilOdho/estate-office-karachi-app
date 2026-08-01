import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';

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

    _pb = PocketBase(baseUrl, authStore: authStore);
  }

  Future<void> updateBaseUrl(String baseUrl) async {
    await init(baseUrl);
  }

  void logout() {
    _pb?.authStore.clear();
  }
}
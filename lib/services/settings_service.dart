import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';

class SettingsService {
  SettingsService._internal();
  static final SettingsService instance = SettingsService._internal();

  Future<String> getServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(PrefsKeys.serverUrl) ?? AppDefaults.defaultServerUrl;
  }

  Future<void> setServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefsKeys.serverUrl, url.trim());
  }
}
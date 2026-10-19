import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String _rememberMeKey = 'remember_me';

  final SharedPreferencesAsync _preferences =
      SharedPreferencesAsync();

  Future<void> setRememberMe(bool value) async {
    await _preferences.setBool(
      _rememberMeKey,
      value,
    );
  }

  Future<bool> getRememberMe() async {
    return await _preferences.getBool(
          _rememberMeKey,
        ) ??
        false;
  }

  Future<void> clearRememberMe() async {
    await _preferences.remove(_rememberMeKey);
  }
}
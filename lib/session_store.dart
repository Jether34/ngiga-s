import 'package:shared_preferences/shared_preferences.dart';

class SessionStore {
  static const key = 'token';

  Future<String> restore() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(key) ?? '';
  }

  Future<void> save(String token, {required bool remember}) async {
    final preferences = await SharedPreferences.getInstance();
    if (remember && token.isNotEmpty) {
      await preferences.setString(key, token);
    } else {
      await preferences.remove(key);
    }
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(key);
  }
}

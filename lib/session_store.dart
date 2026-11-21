import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SessionStore {
  static const key = 'token';
  static const iconTokenKey = 'icon_switch_token';
  static const userKey = 'cached_user';

  Future<Map<String, dynamic>> restoreUser() async {
    final preferences = await SharedPreferences.getInstance();
    try {
      final value = jsonDecode(preferences.getString(userKey) ?? '{}');
      return value is Map ? Map<String, dynamic>.from(value) : {};
    } catch (_) {
      return {};
    }
  }

  Future<void> saveUser(Map<String, dynamic> user) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(userKey, jsonEncode(user));
  }

  Future<String> restore() async {
    final preferences = await SharedPreferences.getInstance();
    final remembered = preferences.getString(key) ?? '';
    if (remembered.isNotEmpty) return remembered;
    return preferences.getString(iconTokenKey) ?? '';
  }

  Future<void> holdForIconChange(String token) async {
    if (token.isEmpty) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(iconTokenKey, token);
  }

  Future<void> clearIconChangeHold() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(iconTokenKey);
  }

  Future<void> save(String token, {required bool remember}) async {
    final preferences = await SharedPreferences.getInstance();
    await clearIconChangeHold();
    if (remember && token.isNotEmpty) {
      await preferences.setString(key, token);
    } else {
      await preferences.remove(key);
    }
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(key);
    await clearIconChangeHold();
    await preferences.remove(userKey);
  }
}

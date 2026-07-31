import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/models/user_model.dart';

class UserCacheService {
  static const String _userCacheKey = 'cached_user_profile';

  Future<void> saveUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(user.toMap());
    await prefs.setString(_userCacheKey, jsonString);
  }

  Future<UserModel?> getCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_userCacheKey);
    if (jsonString != null) {
      try {
        final Map<String, dynamic> map = jsonDecode(jsonString);
        return UserModel.fromMap(map);
      } catch (e) {
        debugPrint('Error decoding cached user: $e');
        return null;
      }
    }
    return null;
  }

  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userCacheKey);
  }
}

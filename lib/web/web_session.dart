import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'web_role_model.dart';

/// Persists the officer's web-dashboard session in the browser's local
/// storage (SharedPreferences' web implementation) so refreshing the page
/// doesn't log them out — only the explicit Logout button should do that.
class WebSession {
  static const _kStaffId = 'web_staffId';
  static const _kUserName = 'web_userName';
  static const _kUserEmail = 'web_userEmail';
  static const _kUserRole = 'web_userRole';

  static Future<void> save({
    required String staffId,
    required String userName,
    required String userEmail,
    required UserRole userRole,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kStaffId, staffId);
    await prefs.setString(_kUserName, userName);
    await prefs.setString(_kUserEmail, userEmail);
    await prefs.setString(_kUserRole, userRole.name);
    debugPrint('[WebSession] saved session for staffId=$staffId role=${userRole.name}');
  }

  /// Returns the restored session (`staffId`, `userName`, `userEmail`,
  /// `userRole`), or null if none is stored / it's incomplete.
  static Future<Map<String, dynamic>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final staffId = prefs.getString(_kStaffId);
    final roleName = prefs.getString(_kUserRole);
    debugPrint('[WebSession] load() found staffId=$staffId role=$roleName (all keys: ${prefs.getKeys()})');
    if (staffId == null || roleName == null) return null;
    return {
      'staffId': staffId,
      'userName': prefs.getString(_kUserName) ?? '',
      'userEmail': prefs.getString(_kUserEmail) ?? '',
      'userRole': UserRole.values.byName(roleName),
    };
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kStaffId);
    await prefs.remove(_kUserName);
    await prefs.remove(_kUserEmail);
    await prefs.remove(_kUserRole);
    debugPrint('[WebSession] cleared session');
  }
}

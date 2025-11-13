import 'package:shared_preferences/shared_preferences.dart';

class SharedpreferenceHelper {
  // Keys
  static const String userIdKey = "USERKEY";
  static const String userNameKey = "USERNAMEKEY";
  static const String userEmailKey = "USEREMAILKEY";
  static const String userImageKey = "USERIMAGEKEY";
  static const String userRoleKey = "USERROLEKEY";
  static const String isLoggedInKey = "ISLOGGEDINKEY";
  static const String appFirstLaunchKey = "APPFIRSTLAUNCHKEY";

  // Private instance
  static SharedPreferences? _prefs;

  // Initialize SharedPreferences
  static Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Ensure preferences are initialized
  static Future<SharedPreferences> _getInstance() async {
    if (_prefs == null) {
      await _init();
    }
    return _prefs!;
  }

  // User ID methods
  Future<bool> saveUserId(String userId) async {
    try {
      final prefs = await _getInstance();
      print('SharedPreference - Saving User ID: $userId');
      return await prefs.setString(userIdKey, userId);
    } catch (e) {
      print('Error saving user ID: $e');
      return false;
    }
  }

  Future<String?> getUserId() async {
    try {
      final prefs = await _getInstance();
      final userId = prefs.getString(userIdKey);
      print('SharedPreference - Retrieved User ID: "$userId"');
      return userId;
    } catch (e) {
      print('Error getting user ID: $e');
      return null;
    }
  }

  // User Name methods
  Future<bool> saveUserName(String userName) async {
    try {
      final prefs = await _getInstance();
      print('SharedPreference - Saving User Name: $userName');
      return await prefs.setString(userNameKey, userName);
    } catch (e) {
      print('Error saving user name: $e');
      return false;
    }
  }

  Future<String?> getUserName() async {
    try {
      final prefs = await _getInstance();
      return prefs.getString(userNameKey);
    } catch (e) {
      print('Error getting user name: $e');
      return null;
    }
  }

  // User Email methods
  Future<bool> saveUserEmail(String userEmail) async {
    try {
      final prefs = await _getInstance();
      print('SharedPreference - Saving User Email: $userEmail');
      return await prefs.setString(userEmailKey, userEmail);
    } catch (e) {
      print('Error saving user email: $e');
      return false;
    }
  }

  Future<String?> getUserEmail() async {
    try {
      final prefs = await _getInstance();
      return prefs.getString(userEmailKey);
    } catch (e) {
      print('Error getting user email: $e');
      return null;
    }
  }

  // User Image methods
  Future<bool> saveUserImage(String userImage) async {
    try {
      final prefs = await _getInstance();
      print('SharedPreference - Saving User Image: $userImage');
      return await prefs.setString(userImageKey, userImage);
    } catch (e) {
      print('Error saving user image: $e');
      return false;
    }
  }

  Future<String?> getUserImage() async {
    try {
      final prefs = await _getInstance();
      return prefs.getString(userImageKey);
    } catch (e) {
      print('Error getting user image: $e');
      return null;
    }
  }

  // User Role methods
  Future<bool> saveUserRole(String userRole) async {
    try {
      final prefs = await _getInstance();
      print('SharedPreference - Saving User Role: $userRole');
      return await prefs.setString(userRoleKey, userRole);
    } catch (e) {
      print('Error saving user role: $e');
      return false;
    }
  }

  Future<String?> getUserRole() async {
    try {
      final prefs = await _getInstance();
      return prefs.getString(userRoleKey);
    } catch (e) {
      print('Error getting user role: $e');
      return null;
    }
  }

  // Login status methods
  Future<bool> setLoggedIn(bool isLoggedIn) async {
    try {
      final prefs = await _getInstance();
      print('SharedPreference - Setting login status: $isLoggedIn');
      return await prefs.setBool(isLoggedInKey, isLoggedIn);
    } catch (e) {
      print('Error setting login status: $e');
      return false;
    }
  }

  Future<bool> isLoggedIn() async {
    try {
      final prefs = await _getInstance();
      return prefs.getBool(isLoggedInKey) ?? false;
    } catch (e) {
      print('Error getting login status: $e');
      return false;
    }
  }

  // App first launch methods
  Future<bool> setAppFirstLaunch(bool isFirstLaunch) async {
    try {
      final prefs = await _getInstance();
      return await prefs.setBool(appFirstLaunchKey, isFirstLaunch);
    } catch (e) {
      print('Error setting app first launch: $e');
      return false;
    }
  }

  Future<bool> isAppFirstLaunch() async {
    try {
      final prefs = await _getInstance();
      return prefs.getBool(appFirstLaunchKey) ?? true;
    } catch (e) {
      print('Error getting app first launch: $e');
      return true;
    }
  }

  // Save all user data at once
  Future<bool> saveAllUserData({
    required String userId,
    required String userName,
    required String userEmail,
    String? userImage,
    String? userRole,
  }) async {
    try {
      final prefs = await _getInstance();

      await prefs.setString(userIdKey, userId);
      await prefs.setString(userNameKey, userName);
      await prefs.setString(userEmailKey, userEmail);

      if (userImage != null) {
        await prefs.setString(userImageKey, userImage);
      }

      if (userRole != null) {
        await prefs.setString(userRoleKey, userRole);
      }

      await prefs.setBool(isLoggedInKey, true);

      print('SharedPreference - Saved all user data for: $userName');
      return true;
    } catch (e) {
      print('Error saving all user data: $e');
      return false;
    }
  }

  // Get all user data
  Future<Map<String, String?>> getAllUserData() async {
    try {
      final prefs = await _getInstance();

      return {
        'userId': prefs.getString(userIdKey),
        'userName': prefs.getString(userNameKey),
        'userEmail': prefs.getString(userEmailKey),
        'userImage': prefs.getString(userImageKey),
        'userRole': prefs.getString(userRoleKey),
      };
    } catch (e) {
      print('Error getting all user data: $e');
      return {};
    }
  }

  // Clear all user data (logout)
  Future<bool> clearAllUserData() async {
    try {
      final prefs = await _getInstance();

      await prefs.remove(userIdKey);
      await prefs.remove(userNameKey);
      await prefs.remove(userEmailKey);
      await prefs.remove(userImageKey);
      await prefs.remove(userRoleKey);
      await prefs.remove(isLoggedInKey);

      print('SharedPreference - Cleared all user data');
      return true;
    } catch (e) {
      print('Error clearing user data: $e');
      return false;
    }
  }

  // Clear specific data
  Future<bool> clearUserData(List<String> keys) async {
    try {
      final prefs = await _getInstance();

      for (String key in keys) {
        await prefs.remove(key);
      }

      print('SharedPreference - Cleared keys: $keys');
      return true;
    } catch (e) {
      print('Error clearing specific user data: $e');
      return false;
    }
  }

  // Check if user exists - UPDATED
  Future<bool> userExists() async {
    try {
      final prefs = await _getInstance();
      final userId = prefs.getString(userIdKey);

      // Only check if user ID exists and is not empty
      return userId != null && userId.isNotEmpty;
    } catch (e) {
      print('Error checking if user exists: $e');
      return false;
    }
  }

  // Get user profile summary
  Future<Map<String, dynamic>> getUserProfileSummary() async {
    try {
      final prefs = await _getInstance();

      return {
        'isLoggedIn': prefs.getBool(isLoggedInKey) ?? false,
        'userId': prefs.getString(userIdKey),
        'userName': prefs.getString(userNameKey),
        'userEmail': prefs.getString(userEmailKey),
        'hasImage': prefs.getString(userImageKey) != null,
        'userRole': prefs.getString(userRoleKey),
      };
    } catch (e) {
      print('Error getting user profile summary: $e');
      return {'isLoggedIn': false};
    }
  }
}

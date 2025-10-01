import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  final SharedPreferences _prefs;
  final ApiService _apiService = ApiService();
  UserModel? _currentUser;

  AuthService(this._prefs) {
    // Load saved user if "Remember me" was checked
    _loadUserFromPrefs();
  }

  bool get isLoggedIn => _currentUser != null;

  UserModel? get currentUser => _currentUser;

  Future<void> _loadUserFromPrefs() async {
    final userJson = _prefs.getString('current_user');
    if (userJson != null) {
      try {
        _currentUser = UserModel.fromJsonString(userJson);
      } catch (e) {
        print('Error loading user from prefs: $e');
        await _clearStoredUser();
      }
    }
  }

  Future<void> _saveUserToPrefs() async {
    if (_currentUser != null) {
      await _prefs.setString('current_user', _currentUser!.toJsonString());
    } else {
      await _prefs.remove('current_user');
    }
  }

  Future<void> _clearStoredUser() async {
    _currentUser = null;
    await _prefs.remove('current_user');
    await _prefs.remove('access_token');
    await _prefs.remove('refresh_token');
  }

  Future<void> clearStoredUser() async {
    await _clearStoredUser();
  }

  Future<UserModel?> signInWithEmailAndPassword({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    try {
      final response =
          await _apiService.login(email, password, rememberMe: rememberMe);

      if (response['success'] == true && response['data'] != null) {
        final userData = response['data']['user'];
        final tokens = response['data'];

        _currentUser = UserModel(
          id: userData['id'] ?? 'unknown',
          email: userData['email'] ?? email,
          username: userData['username'] ?? 'User',
          bio: userData['bio'],
          avatarUrl: userData['avatarUrl'],
          isVerified: userData['isVerified'] ?? false,
          createdAt: DateTime.parse(
              userData['createdAt'] ?? DateTime.now().toIso8601String()),
        );

        // Save tokens
        await _prefs.setString('access_token', tokens['accessToken'] ?? '');
        await _prefs.setString('refresh_token', tokens['refreshToken'] ?? '');

        // Save user if remember me is checked
        if (rememberMe) {
          await _saveUserToPrefs();
        }

        return _currentUser;
      }
      return null;
    } catch (e) {
      print('Login error: $e');
      return null;
    }
  }

  Future<UserModel?> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      final response = await _apiService.register(
        username: username,
        email: email,
        password: password,
      );

      if (response['success'] == true && response['data'] != null) {
        final userData = response['data']['user'];
        final tokens = response['data'];

        _currentUser = UserModel(
          id: userData['id'] ?? 'unknown',
          email: userData['email'] ?? email,
          username: userData['username'] ?? username,
          bio: userData['bio'],
          avatarUrl: userData['avatarUrl'],
          isVerified: userData['isVerified'] ?? false,
          createdAt: DateTime.parse(
              userData['createdAt'] ?? DateTime.now().toIso8601String()),
        );

        // Save tokens
        await _prefs.setString('access_token', tokens['accessToken'] ?? '');
        await _prefs.setString('refresh_token', tokens['refreshToken'] ?? '');

        // Always save user after registration
        await _saveUserToPrefs();
        return _currentUser;
      }
      return null;
    } catch (e) {
      print('Registration error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _apiService.logout();
    } catch (e) {
      print('Logout API error: $e');
    }
    await _clearStoredUser();
  }

  Future<bool> forgotPassword(String email) async {
    try {
      final response = await _apiService.forgotPassword(email);
      return response['success'] == true;
    } catch (e) {
      print('Forgot password error: $e');
      return false;
    }
  }

  Future<bool> resetPassword(String token, String newPassword) async {
    try {
      final response = await _apiService.resetPassword(token, newPassword);
      return response['success'] == true;
    } catch (e) {
      print('Reset password error: $e');
      return false;
    }
  }

  Future<UserModel?> updateUserProfile({
    String? username,
    String? bio,
    String? avatarUrl,
  }) async {
    if (_currentUser != null) {
      try {
        final response = await _apiService.updateUserProfile(
          firstName: null,
          lastName: null,
          bio: bio,
          avatarUrl: avatarUrl,
        );

        if (response['success'] == true && response['data'] != null) {
          final userData = response['data'];
          _currentUser = UserModel(
            id: userData['id'] ?? _currentUser!.id,
            email: userData['email'] ?? _currentUser!.email,
            username:
                userData['username'] ?? username ?? _currentUser!.username,
            bio: userData['bio'] ?? bio,
            avatarUrl: userData['avatarUrl'] ?? avatarUrl,
            isVerified: userData['isVerified'] ?? _currentUser!.isVerified,
            createdAt: _currentUser!.createdAt,
            updatedAt: DateTime.now(),
          );
          await _saveUserToPrefs();
          return _currentUser;
        }
      } catch (e) {
        print('Profile update error: $e');
      }
    }
    return _currentUser;
  }

  Stream<UserModel?> get authStateChanges {
    return Stream.value(_currentUser);
  }
}

// Provider for auth service
final authServiceProvider = Provider<AuthService>((ref) {
  throw UnimplementedError('AuthService requires SharedPreferences');
});

final authStateProvider = StreamProvider<UserModel?>((ref) async* {
  final authService = ref.watch(authServiceProvider);
  yield* authService.authStateChanges;
});

final currentUserProvider = Provider<UserModel?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.currentUser;
});

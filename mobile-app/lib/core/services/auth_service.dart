import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  final SharedPreferences _prefs;
  final ApiService _apiService = ApiService();
  UserModel? _currentUser;
  final List<VoidCallback> _listeners = [];
  DateTime? _lastNotificationTime;
  bool _isNotifying = false;

  AuthService(this._prefs) {
    // Load saved user if "Remember me" was checked
    _loadUserFromPrefs();
  }

  bool get isLoggedIn => _currentUser != null;

  UserModel? get currentUser => _currentUser;

  // Add listener for user changes
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  // Remove listener
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  // Notify all listeners with debouncing
  void _notifyListeners() {
    if (_isNotifying) return; // Prevent concurrent notifications

    final now = DateTime.now();
    if (_lastNotificationTime != null &&
        now.difference(_lastNotificationTime!).inMilliseconds < 100) {
      return; // Debounce: only notify once per 100ms
    }

    _lastNotificationTime = now;
    _isNotifying = true;

    try {
      // Create a copy of listeners to avoid issues if listeners are removed during iteration
      final listenersCopy = List<VoidCallback>.from(_listeners);
      for (final listener in listenersCopy) {
        try {
          listener();
        } catch (e) {
          print('Error notifying listener: $e');
          // Continue with other listeners even if one fails
        }
      }
    } finally {
      _isNotifying = false;
    }
  }

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

  // Public method to reload user data (useful after profile updates)
  Future<void> reloadCurrentUser() async {
    // First try to load from cache
    await _loadUserFromPrefs();

    // Then fetch fresh data from API if we have a token
    final token = _prefs.getString('access_token');
    if (token != null && _currentUser != null) {
      try {
        final response = await _apiService.getUserProfile(_currentUser!.id);
        if (response['success'] == true && response['data'] != null) {
          _currentUser = UserModel.fromJson(response['data']);
          await _saveUserToPrefs();
          print('✅ Reloaded current user with fresh data from API');
        }
      } catch (e) {
        print('⚠️ Failed to reload user from API, using cached data: $e');
      }
    }

    _notifyListeners();
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

  // Handle automatic sign out due to invalid authentication
  Future<void> handleUnauthorized() async {
    print(
        '🔐 AuthService: User automatically signed out due to invalid authentication');
    await _clearStoredUser();
  }

  Future<void> clearStoredUser() async {
    await _clearStoredUser();
  }

  // Update current user's coin balance
  Future<void> updateUserCoinBalance(int newBalance,
      {String? transactionType,
      String? description,
      String? paymentId,
      String? relatedPostId}) async {
    if (_currentUser != null) {
      try {
        // Update coin balance in database via API
        final success = await _apiService.updateUserCoinBalance(
          newBalance,
          transactionType: transactionType,
          description: description,
          paymentId: paymentId,
          relatedPostId: relatedPostId,
        );

        if (success) {
          // Update local user object
          _currentUser = _currentUser!.copyWith(coinBalance: newBalance);
          await _saveUserToPrefs();
          _notifyListeners();
          print(
              '✅ User coin balance updated to: $newBalance (database updated)');
        } else {
          print('❌ Failed to update coin balance in database');
          throw Exception('Failed to update coin balance in database');
        }
      } catch (e) {
        print('❌ Error updating coin balance: $e');
        rethrow;
      }
    }
  }

  Future<UserModel?> signInWithEmailAndPassword({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    try {
      print('🔐 AuthService: Starting login for $email');
      final response =
          await _apiService.login(email, password, rememberMe: rememberMe);

      print('🔐 AuthService: Login response received: ${response['success']}');

      if (response['success'] == true && response['data'] != null) {
        final userData = response['data']['user'];
        final tokens = response['data'];

        print(
            '🔐 AuthService: Creating user model for ${userData['username']}');

        _currentUser = UserModel(
          id: userData['id'] ?? 'unknown',
          email: userData['email'] ?? email,
          username: userData['username'] ?? 'User',
          bio: userData['bio'],
          avatarUrl: userData['avatarUrl'],
          isVerified: userData['isVerified'] ?? false,
          isVip: userData['isVip'] ?? false,
          coinBalance: userData['coinBalance'] ?? 0,
          createdAt: DateTime.parse(
              userData['createdAt'] ?? DateTime.now().toIso8601String()),
        );

        // Save tokens
        await _prefs.setString('access_token', tokens['accessToken'] ?? '');
        await _prefs.setString('refresh_token', tokens['refreshToken'] ?? '');

        // Always save user data to ensure coin balance is available
        await _saveUserToPrefs();

        print('🔐 AuthService: User data saved, notifying listeners');

        // Notify listeners that user has changed
        _notifyListeners();

        print('🔐 AuthService: Login successful for ${_currentUser?.username}');
        return _currentUser;
      } else {
        print('🔐 AuthService: Login failed - invalid response: $response');
        return null;
      }
    } catch (e) {
      print('🔐 AuthService: Login error: $e');
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
    _notifyListeners();
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

  Stream<UserModel?> get authStateChanges {
    return Stream.value(_currentUser);
  }

  // Update user profile
  Future<UserModel?> refreshCurrentUser() async {
    try {
      if (!isLoggedIn) return null;

      print('🎯 Refreshing current user data...');
      final response = await _apiService.getUserProfile(_currentUser!.id);
      if (response['success'] == true && response['data'] != null) {
        print('🎯 User data refreshed: ${response['data']}');
        _currentUser = UserModel.fromJson(response['data']);
        await _saveUserToPrefs();
        _notifyListeners();
        return _currentUser;
      }
      return null;
    } catch (e) {
      print('Refresh current user error: $e');
      return null;
    }
  }

  Future<UserModel?> updateUserProfile({
    required String username,
    String? bio,
    String? firstName,
    String? lastName,
  }) async {
    try {
      final response = await _apiService.updateUserProfile(
        username: username,
        bio: bio,
        firstName: firstName,
        lastName: lastName,
      );

      if (response['success'] == true && response['data'] != null) {
        _currentUser = UserModel.fromJson(response['data']);
        await _saveUserToPrefs();
        _notifyListeners();
        return _currentUser;
      }
      return null;
    } catch (e) {
      print('Error updating profile: $e');
      return null;
    }
  }

  // Upload avatar
  Future<UserModel?> uploadAvatar(String imagePath) async {
    try {
      final response = await _apiService.uploadAvatar(File(imagePath));

      if (response['success'] == true && response['data'] != null) {
        _currentUser = UserModel.fromJson(response['data']);
        await _saveUserToPrefs();
        _notifyListeners();
        return _currentUser;
      }
      return null;
    } catch (e) {
      print('Error uploading avatar: $e');
      return null;
    }
  }

  // Upload banner
  Future<UserModel?> uploadBanner(String imagePath) async {
    try {
      final response = await _apiService.uploadBanner(File(imagePath));

      if (response['success'] == true && response['data'] != null) {
        _currentUser = UserModel.fromJson(response['data']);
        await _saveUserToPrefs();
        _notifyListeners();
        return _currentUser;
      }
      return null;
    } catch (e) {
      print('Error uploading banner: $e');
      return null;
    }
  }

  // Get access token
  Future<String?> getAccessToken() async {
    return _prefs.getString('access_token');
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

// Create a StateNotifier for current user
class CurrentUserNotifier extends StateNotifier<UserModel?> {
  final AuthService _authService;

  CurrentUserNotifier(this._authService) : super(_authService.currentUser) {
    // Listen to auth service changes
    _authService.addListener(_onAuthServiceChanged);
  }

  void _onAuthServiceChanged() {
    state = _authService.currentUser;
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthServiceChanged);
    super.dispose();
  }
}

final currentUserProvider =
    StateNotifierProvider<CurrentUserNotifier, UserModel?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return CurrentUserNotifier(authService);
});

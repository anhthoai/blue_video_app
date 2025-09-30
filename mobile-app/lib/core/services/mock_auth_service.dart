import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user_model.dart';
import 'api_service.dart';

class MockAuthService {
  final SharedPreferences _prefs;
  final ApiService _apiService = ApiService();
  UserModel? _currentUser;

  MockAuthService(this._prefs) {
    _loadUserFromPrefs();
  }

  bool get isLoggedIn => _currentUser != null;

  UserModel? get currentUser => _currentUser;

  Future<void> _loadUserFromPrefs() async {
    final userJson = _prefs.getString('current_user');
    if (userJson != null) {
      _currentUser = UserModel.fromJsonString(userJson);
    }
  }

  Future<void> _saveUserToPrefs() async {
    if (_currentUser != null) {
      await _prefs.setString('current_user', _currentUser!.toJsonString());
    } else {
      await _prefs.remove('current_user');
    }
  }

  Future<UserModel?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      // Use real API for authentication
      final response = await _apiService.login(email, password);

      if (response['success'] == true && response['data'] != null) {
        final userData = response['data']['user'];
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
        await _saveUserToPrefs();
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
      // Use real API for registration
      final response = await _apiService.register(
        username: username,
        email: email,
        password: password,
      );

      if (response['success'] == true && response['data'] != null) {
        final userData = response['data']['user'];
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
    await _apiService.logout();
    _currentUser = null;
    await _saveUserToPrefs();
  }

  Future<void> resetPassword(String email) async {
    // Mock password reset
    print('Mock password reset sent to $email');
  }

  Future<UserModel?> updateUserProfile({
    String? username,
    String? bio,
    String? avatarUrl,
  }) async {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(
        username: username ?? _currentUser!.username,
        bio: bio ?? _currentUser!.bio,
        avatarUrl: avatarUrl ?? _currentUser!.avatarUrl,
        updatedAt: DateTime.now(),
      );
      await _saveUserToPrefs();
    }
    return _currentUser;
  }

  Stream<UserModel?> get authStateChanges {
    // Return a simple stream that emits the current user
    return Stream.value(_currentUser);
  }
}

// Provider for mock auth service
final mockAuthServiceProvider = Provider<MockAuthService>((ref) {
  throw UnimplementedError('MockAuthService requires SharedPreferences');
});

final mockAuthStateProvider = StreamProvider<UserModel?>((ref) async* {
  final authService = ref.watch(mockAuthServiceProvider);
  yield* authService.authStateChanges;
});

final mockCurrentUserProvider = Provider<UserModel?>((ref) {
  final authService = ref.watch(mockAuthServiceProvider);
  return authService.currentUser;
});

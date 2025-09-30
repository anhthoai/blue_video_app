import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user_model.dart';

class MockAuthService {
  final SharedPreferences _prefs;
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
    // Mock login - accept any credentials
    _currentUser = UserModel(
      id: 'mock_user_1',
      email: email,
      username: 'Test User',
      avatarUrl: 'https://i.pravatar.cc/150?img=1',
      bio: 'Mock user for testing',
      createdAt: DateTime.now(),
    );
    await _saveUserToPrefs();
    return _currentUser;
  }

  Future<UserModel?> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String username,
  }) async {
    // Mock registration
    _currentUser = UserModel(
      id: 'mock_user_${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      username: username,
      avatarUrl:
          'https://i.pravatar.cc/150?img=${DateTime.now().millisecondsSinceEpoch % 10}',
      bio: 'New mock user',
      createdAt: DateTime.now(),
    );
    await _saveUserToPrefs();
    return _currentUser;
  }

  Future<void> signOut() async {
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

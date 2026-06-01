import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user_model.dart';
import 'api_service.dart';
import 'notification_service.dart';

enum SignInFailureReason {
  invalidCredentials,
  emailNotVerified,
  unknown,
}

class AuthService {
  final SharedPreferences _prefs;
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();

  static const String _biometricEnabledKey = 'biometric_login_enabled';
  static const String _biometricEmailKey = 'biometric_login_email';
  static const String _biometricPasswordKey = 'biometric_login_password';

  UserModel? _currentUser;
  final List<VoidCallback> _listeners = [];
  DateTime? _lastNotificationTime;
  bool _isNotifying = false;
  SignInFailureReason? _lastSignInFailureReason;

  AuthService(this._prefs) {
    // Load saved user if "Remember me" was checked
    _loadUserFromPrefs();
  }

  bool get isLoggedIn => _currentUser != null;

  UserModel? get currentUser => _currentUser;
  bool get isAdmin => _currentUser?.role == 'ADMIN';
  SignInFailureReason? get lastSignInFailureReason => _lastSignInFailureReason;

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

    await NotificationService.registerCurrentToken();
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
    bool? enableBiometricLogin,
  }) async {
    try {
      _lastSignInFailureReason = null;
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
          role: userData['role'] ?? 'USER',
          bio: userData['bio'],
          avatarUrl: userData['avatarUrl'],
          isVerified: userData['isVerified'] ?? false,
          isVip: userData['isVip'] ?? false,
          coinBalance: userData['coinBalance'] ?? 0,
          createdAt: DateTime.parse(
              userData['createdAt'] ?? DateTime.now().toIso8601String()),
        );

        if (!(_currentUser?.isVerified ?? false)) {
          await _apiService.clearTokens();
          await _clearStoredUser();
          _lastSignInFailureReason = SignInFailureReason.emailNotVerified;
          return null;
        }

        // Save tokens
        await _prefs.setString('access_token', tokens['accessToken'] ?? '');
        await _prefs.setString('refresh_token', tokens['refreshToken'] ?? '');

        final shouldStoreForBiometric =
            enableBiometricLogin ?? await isBiometricLoginEnabled();
        if (shouldStoreForBiometric) {
          await _storeBiometricCredentials(email: email, password: password);
          await _prefs.setBool(_biometricEnabledKey, true);
        } else if (enableBiometricLogin == false) {
          await disableBiometricLogin();
        }

        // Always save user data to ensure coin balance is available
        await _saveUserToPrefs();

        print('🔐 AuthService: User data saved, notifying listeners');

        // Notify listeners that user has changed
        await NotificationService.registerCurrentToken();
        _notifyListeners();

        print('🔐 AuthService: Login successful for ${_currentUser?.username}');
        return _currentUser;
      } else {
        print('🔐 AuthService: Login failed - invalid response: $response');
        _lastSignInFailureReason = SignInFailureReason.invalidCredentials;
        return null;
      }
    } catch (e) {
      print('🔐 AuthService: Login error: $e');
      _lastSignInFailureReason = SignInFailureReason.unknown;
      return null;
    }
  }

  Future<UserModel?> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      print('🔐 AuthService: Starting registration for $username');
      final response = await _apiService.register(
        username: username,
        email: email,
        password: password,
      );

      if (response['success'] == true && response['data'] != null) {
        final userData = response['data']['user'];
        final tokens = response['data'];

        final registeredUser = UserModel(
          id: userData['id'] ?? 'unknown',
          email: userData['email'] ?? email,
          username: userData['username'] ?? username,
          role: userData['role'] ?? 'USER',
          bio: userData['bio'],
          avatarUrl: userData['avatarUrl'],
          isVerified: userData['isVerified'] ?? false,
          isVip: userData['isVip'] ?? false,
          coinBalance: userData['coinBalance'] ?? 0,
          createdAt: DateTime.parse(
              userData['createdAt'] ?? DateTime.now().toIso8601String()),
        );

        if (!registeredUser.isVerified) {
          await _apiService.clearTokens();
          await _clearStoredUser();
          return registeredUser;
        }

        _currentUser = registeredUser;

        // Save tokens
        await _prefs.setString('access_token', tokens['accessToken'] ?? '');
        await _prefs.setString('refresh_token', tokens['refreshToken'] ?? '');

        // Always save user after registration
        await _saveUserToPrefs();

        print(
            '🔐 AuthService: User data saved, scheduling listener notification');

        // Schedule notification for next frame to avoid widget disposal issues
        // This gives the navigation time to complete before updating listeners
        Future.microtask(() {
          _notifyListeners();
          print('🔐 AuthService: Listeners notified');
        });
        await NotificationService.registerCurrentToken();

        print(
            '🔐 AuthService: Registration successful for ${_currentUser?.username}');
        return _currentUser;
      }
      print(
          '🔐 AuthService: Registration failed - invalid response: $response');
      return null;
    } catch (e) {
      print('🔐 AuthService: Registration error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await NotificationService.unregisterCurrentToken();
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

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _apiService.changePassword(
        currentPassword,
        newPassword,
      );
      return response['success'] == true;
    } catch (e) {
      print('Change password error: $e');
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

  Future<bool> isBiometricLoginEnabled() async {
    return _prefs.getBool(_biometricEnabledKey) ?? false;
  }

  Future<bool> canUseBiometrics() async {
    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheckBiometrics || isSupported;
    } catch (error) {
      debugPrint('Biometric availability check failed: $error');
      return false;
    }
  }

  Future<bool> hasStoredBiometricCredentials() async {
    final email = await _secureStorage.read(key: _biometricEmailKey);
    final password = await _secureStorage.read(key: _biometricPasswordKey);
    return email != null &&
        email.isNotEmpty &&
        password != null &&
        password.isNotEmpty;
  }

  Future<bool> isBiometricLoginAvailable() async {
    final enabled = await isBiometricLoginEnabled();
    if (!enabled) return false;

    final canUse = await canUseBiometrics();
    if (!canUse) return false;

    return hasStoredBiometricCredentials();
  }

  Future<bool> authenticateForBiometricLogin({String? localizedReason}) async {
    try {
      return await _localAuth.authenticate(
        localizedReason:
            localizedReason ?? 'Authenticate to login to Blue Video',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );
    } catch (error) {
      debugPrint('Biometric authentication failed: $error');
      return false;
    }
  }

  Future<void> setBiometricLoginEnabled({
    required bool enabled,
    String? email,
    String? password,
  }) async {
    await _prefs.setBool(_biometricEnabledKey, enabled);

    if (enabled) {
      if (email != null &&
          password != null &&
          email.isNotEmpty &&
          password.isNotEmpty) {
        await _storeBiometricCredentials(email: email, password: password);
      }
      return;
    }
  }

  Future<void> disableBiometricLogin() async {
    await setBiometricLoginEnabled(enabled: false);
  }

  Future<UserModel?> signInWithBiometrics({
    bool rememberMe = true,
    String? localizedReason,
  }) async {
    final enabled = await isBiometricLoginEnabled();
    if (!enabled) {
      debugPrint('Biometric login requested but feature is disabled');
      return null;
    }

    final authenticated = await authenticateForBiometricLogin(
      localizedReason: localizedReason,
    );
    if (!authenticated) {
      return null;
    }

    final email = await _secureStorage.read(key: _biometricEmailKey);
    final password = await _secureStorage.read(key: _biometricPasswordKey);
    if (email == null ||
        password == null ||
        email.isEmpty ||
        password.isEmpty) {
      debugPrint('No stored credentials available for biometric login');
      return null;
    }

    return signInWithEmailAndPassword(
      email: email,
      password: password,
      rememberMe: rememberMe,
      enableBiometricLogin: true,
    );
  }

  Future<void> _storeBiometricCredentials({
    required String email,
    required String password,
  }) async {
    await _secureStorage.write(key: _biometricEmailKey, value: email);
    await _secureStorage.write(key: _biometricPasswordKey, value: password);
  }

  Future<void> _clearBiometricCredentials() async {
    try {
      await _secureStorage.delete(key: _biometricEmailKey);
      await _secureStorage.delete(key: _biometricPasswordKey);
    } on PlatformException catch (error) {
      debugPrint('Failed to clear biometric credentials: $error');
    }
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
  bool _isDisposed = false;

  CurrentUserNotifier(this._authService) : super(_authService.currentUser) {
    // Listen to auth service changes
    _authService.addListener(_onAuthServiceChanged);
  }

  void _onAuthServiceChanged() {
    // Defer state update to avoid notifying consumer elements during teardown.
    if (_isDisposed) return;

    Future.microtask(() {
      if (_isDisposed || !mounted) return;

      try {
        state = _authService.currentUser;
      } catch (e) {
        // Ignore lifecycle races during widget/provider disposal.
        print(
            '⚠️ CurrentUserNotifier: Unable to update state (widget disposed): $e');
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _authService.removeListener(_onAuthServiceChanged);
    super.dispose();
  }
}

final currentUserProvider =
    StateNotifierProvider<CurrentUserNotifier, UserModel?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return CurrentUserNotifier(authService);
});

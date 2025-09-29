import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SharedPreferences _prefs;

  AuthService(this._prefs);

  // Getters
  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => currentUser != null;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserModel?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        return await _getUserModel(credential.user!);
      }
      return null;
    } catch (e) {
      throw Exception('Sign in failed: $e');
    }
  }

  // Register with email and password
  Future<UserModel?> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String username,
    String? phoneNumber,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Update display name
        await credential.user!.updateDisplayName(username);

        // Create user model
        final userModel = UserModel(
          id: credential.user!.uid,
          email: email,
          username: username,
          phoneNumber: phoneNumber,
          createdAt: DateTime.now(),
          isVerified: false,
          isVip: false,
          vipLevel: 0,
          coinBalance: 0,
          followerCount: 0,
          followingCount: 0,
          videoCount: 0,
          likeCount: 0,
        );

        // Save user data
        await _saveUserModel(userModel);

        return userModel;
      }
      return null;
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  // Sign in with phone number
  Future<void> signInWithPhoneNumber({
    required String phoneNumber,
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      await _auth.signInWithCredential(credential);
    } catch (e) {
      throw Exception('Phone sign in failed: $e');
    }
  }

  // Send phone verification code
  Future<void> sendPhoneVerificationCode(String phoneNumber) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          throw Exception('Verification failed: ${e.message}');
        },
        codeSent: (String verificationId, int? resendToken) {
          // Store verification ID for later use
          _prefs.setString('verification_id', verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _prefs.setString('verification_id', verificationId);
        },
      );
    } catch (e) {
      throw Exception('Failed to send verification code: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _prefs.clear();
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw Exception('Password reset failed: $e');
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    String? username,
    String? bio,
    String? avatarUrl,
  }) async {
    try {
      final user = currentUser;
      if (user != null) {
        if (username != null) {
          await user.updateDisplayName(username);
        }

        // Update local user model
        final userModel = await getCurrentUserModel();
        if (userModel != null) {
          final updatedModel = userModel.copyWith(
            username: username ?? userModel.username,
            bio: bio ?? userModel.bio,
            avatarUrl: avatarUrl ?? userModel.avatarUrl,
          );
          await _saveUserModel(updatedModel);
        }
      }
    } catch (e) {
      throw Exception('Profile update failed: $e');
    }
  }

  // Get current user model
  Future<UserModel?> getCurrentUserModel() async {
    try {
      final userJson = _prefs.getString('user_model');
      if (userJson != null) {
        return UserModel.fromJson(userJson);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Private methods
  Future<UserModel> _getUserModel(User user) async {
    // Try to get existing user model
    final existingModel = await getCurrentUserModel();
    if (existingModel != null) {
      return existingModel;
    }

    // Create new user model
    final userModel = UserModel(
      id: user.uid,
      email: user.email ?? '',
      username: user.displayName ?? 'User',
      avatarUrl: user.photoURL,
      createdAt: DateTime.now(),
      isVerified: user.emailVerified,
      isVip: false,
      vipLevel: 0,
      coinBalance: 0,
      followerCount: 0,
      followingCount: 0,
      videoCount: 0,
      likeCount: 0,
    );

    await _saveUserModel(userModel);
    return userModel;
  }

  Future<void> _saveUserModel(UserModel userModel) async {
    await _prefs.setString('user_model', userModel.toJson());
  }
}

// Provider
final authServiceProvider = Provider<AuthService>((ref) {
  throw UnimplementedError('AuthService provider not implemented');
});

// Auth state provider
final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

// Current user provider
final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final authService = ref.watch(authServiceProvider);
  return await authService.getCurrentUserModel();
});

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';
import '../../screens/splash/splash_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/main/main_screen.dart';
import '../../screens/video/video_detail_screen.dart';
import '../../screens/video/video_player_screen.dart';
import '../../screens/video/upload_video_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/profile/edit_profile_screen.dart';
import '../../screens/chat/chat_screen.dart';
import '../../screens/chat/chat_list_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/search/search_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) async {
      final authServiceAsync = ref.read(authServiceProvider);
      final authService = await authServiceAsync;

      final isLoggedIn = authService.isLoggedIn;
      final isOnAuthScreen = state.uri.path.startsWith('/auth');
      final isOnSplashScreen = state.uri.path == '/splash';

      // If user is not logged in and not on auth screens, redirect to login
      if (!isLoggedIn && !isOnAuthScreen && !isOnSplashScreen) {
        return '/auth/login';
      }

      // If user is logged in and on auth screens, redirect to main
      if (isLoggedIn && isOnAuthScreen) {
        return '/main';
      }

      return null;
    },
    routes: [
      // Splash Screen
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // Auth Routes
      GoRoute(
        path: '/auth/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/register',
        builder: (context, state) => const RegisterScreen(),
      ),

      // Main App Routes
      GoRoute(
        path: '/main',
        builder: (context, state) => const MainScreen(),
        routes: [
          // Video Routes
          GoRoute(
            path: 'video/:id',
            builder: (context, state) {
              final videoId = state.pathParameters['id']!;
              return VideoDetailScreen(videoId: videoId);
            },
          ),
          GoRoute(
            path: 'video/:id/player',
            builder: (context, state) {
              final videoId = state.pathParameters['id']!;
              return VideoPlayerScreen(videoId: videoId);
            },
          ),
          GoRoute(
            path: 'upload',
            builder: (context, state) => const UploadVideoScreen(),
          ),

          // Profile Routes
          GoRoute(
            path: 'profile/:userId',
            builder: (context, state) {
              final userId = state.pathParameters['userId']!;
              return ProfileScreen(userId: userId);
            },
          ),
          GoRoute(
            path: 'profile/edit',
            builder: (context, state) => const EditProfileScreen(),
          ),

          // Chat Routes
          GoRoute(
            path: 'chat',
            builder: (context, state) => const ChatListScreen(),
          ),
          GoRoute(
            path: 'chat/:chatId',
            builder: (context, state) {
              final chatId = state.pathParameters['chatId']!;
              return ChatScreen(chatId: chatId);
            },
          ),

          // Other Routes
          GoRoute(
            path: 'search',
            builder: (context, state) => const SearchScreen(),
          ),
          GoRoute(
            path: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'The page you are looking for does not exist.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/main'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});

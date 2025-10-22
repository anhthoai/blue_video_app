import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';
import '../../screens/splash/splash_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/auth/forgot_password_screen.dart';
import '../../screens/auth/reset_password_screen.dart';
import '../../screens/main/main_screen.dart';
import '../../screens/video/video_detail_screen.dart';
import '../../screens/video/video_player_screen.dart';
import '../../screens/video/upload_video_screen_new.dart';
import '../../screens/profile/other_user_profile_screen.dart';
import '../../screens/profile/edit_profile_screen.dart';
import '../../screens/chat/chat_screen.dart';
import '../../screens/chat/chat_list_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/search/search_screen.dart';
import '../../screens/test/test_instructions_screen.dart';
import '../../screens/community/create_post_screen.dart';
import '../../screens/community/tag_posts_screen.dart';
import '../../screens/community/post_detail_screen.dart';
import '../../screens/community/search_results_screen.dart';
import '../../screens/coin/coin_recharge_screen.dart';
import '../../screens/coin/coin_history_screen.dart';
import '../../screens/vip/vip_subscription_screen.dart';
import '../../screens/discover/category_detail_screen.dart';
import '../../screens/playlist/playlist_detail_screen.dart';
import '../../models/category_model.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) async {
      final authService = ref.read(authServiceProvider);

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
      GoRoute(
        path: '/auth/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/auth/reset-password',
        builder: (context, state) {
          final token = state.uri.queryParameters['token'];
          return ResetPasswordScreen(token: token);
        },
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
            builder: (context, state) => const UploadVideoScreenNew(),
          ),
          GoRoute(
            path: 'create-post',
            builder: (context, state) => const CreatePostScreen(),
          ),
          GoRoute(
            path: 'post/:postId',
            builder: (context, state) {
              final postId = state.pathParameters['postId']!;
              return PostDetailScreen(postId: postId);
            },
          ),
          GoRoute(
            path: 'tag/:tag',
            builder: (context, state) {
              final tag = state.pathParameters['tag']!;
              return TagPostsScreen(tag: tag);
            },
          ),
          GoRoute(
            path: 'search/:query',
            builder: (context, state) {
              final query = Uri.decodeComponent(state.pathParameters['query']!);
              return SearchResultsScreen(query: query);
            },
          ),
          GoRoute(
            path: 'coin-recharge',
            builder: (context, state) => const CoinRechargeScreen(),
          ),
          GoRoute(
            path: 'coin-history',
            builder: (context, state) => const CoinHistoryScreen(),
          ),

          // VIP Subscription Routes
          GoRoute(
            path: 'vip-subscription/:authorId',
            builder: (context, state) {
              final authorId = state.pathParameters['authorId']!;
              final authorName = state.uri.queryParameters['name'] ?? 'Author';
              final authorAvatar = state.uri.queryParameters['avatar'];
              return VipSubscriptionScreen(
                authorId: authorId,
                authorName: authorName,
                authorAvatar: authorAvatar,
              );
            },
          ),

          // Profile Routes
          GoRoute(
            path: 'profile/edit',
            builder: (context, state) => const EditProfileScreen(),
          ),
          GoRoute(
            path: 'profile/:userId',
            builder: (context, state) {
              final userId = state.pathParameters['userId']!;
              return OtherUserProfileScreen(userId: userId);
            },
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

          // Discover/Category Routes
          GoRoute(
            path: 'category/:categoryId',
            builder: (context, state) {
              final categoryData = state.extra as CategoryModel;
              return CategoryDetailScreen(category: categoryData);
            },
          ),

          // Playlist Routes
          GoRoute(
            path: 'playlist/:playlistId',
            builder: (context, state) {
              final playlistId = state.pathParameters['playlistId']!;
              final extra = state.extra as Map<String, dynamic>?;
              return PlaylistDetailScreen(
                playlistId: playlistId,
                playlistName: extra?['playlistName'] ?? 'Playlist',
                playlistDescription: extra?['playlistDescription'],
                playlistThumbnail: extra?['playlistThumbnail'],
                isPublic: extra?['isPublic'] ?? true,
                videoCount: extra?['videoCount'] ?? 0,
              );
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

          // Test Routes
          GoRoute(
            path: 'test-instructions',
            builder: (context, state) => const TestInstructionsScreen(),
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

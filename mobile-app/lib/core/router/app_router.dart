import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';
import '../../screens/splash/splash_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/auth/forgot_password_screen.dart';
import '../../screens/auth/reset_password_screen.dart';
import '../../screens/auth/verify_email_screen.dart';
import '../../screens/main/main_screen.dart';
import '../../screens/video/video_detail_screen.dart';
import '../../screens/video/video_player_screen.dart';
import '../../screens/video/upload_video_screen_new.dart';
import '../../screens/profile/other_user_profile_screen.dart';
import '../../screens/profile/edit_profile_screen.dart';
import '../../screens/chat/chat_screen.dart';
import '../../screens/chat/chat_list_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/settings/language_selection_screen.dart';
import '../../screens/settings/theme_selection_screen.dart';
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
import '../../core/models/library_navigation.dart';
import '../../screens/library/movie_detail_screen.dart';
import '../../screens/library/movie_player_screen.dart';
import '../../screens/library/add_movie/add_movie_start_screen.dart';
import '../../screens/library/add_movie/add_movie_manual_screen.dart';
import '../../screens/library/library_folder_screen.dart';
import '../../screens/library/library_image_viewer_screen.dart';
import '../../screens/library/library_audio_player_screen.dart';
import '../../screens/library/library_video_player_screen.dart';
import '../../screens/library/library_document_screen.dart';
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
      GoRoute(
        path: '/auth/verify-email',
        builder: (context, state) {
          final token = state.uri.queryParameters['token'] ?? '';
          return VerifyEmailScreen(token: token);
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

          // Library Routes
          GoRoute(
            path: 'library/movie/:movieId',
            builder: (context, state) {
              final movieId = state.pathParameters['movieId']!;
              return MovieDetailScreen(movieId: movieId);
            },
          ),
          GoRoute(
            path: 'library/add',
            builder: (context, state) {
              final type = state.uri.queryParameters['type'];
              final title = state.uri.queryParameters['title'];
              final imdbId = state.uri.queryParameters['imdbId'];
              final tmdbId = state.uri.queryParameters['tmdbId'];
              final tvdbId = state.uri.queryParameters['tvdbId'];

              return AddMovieStartScreen(
                initialType: type,
                initialTitle: title,
                initialImdbId: imdbId,
                initialTmdbId: tmdbId,
                initialTvdbId: tvdbId,
              );
            },
            routes: [
              GoRoute(
                path: 'manual',
                builder: (context, state) {
                  final type = state.uri.queryParameters['type'];
                  final title = state.uri.queryParameters['title'];
                  final imdbId = state.uri.queryParameters['imdbId'];
                  final tmdbId = state.uri.queryParameters['tmdbId'];
                  final tvdbId = state.uri.queryParameters['tvdbId'];

                  return AddMovieManualScreen(
                    initialType: type,
                    initialTitle: title,
                    initialImdbId: imdbId,
                    initialTmdbId: tmdbId,
                    initialTvdbId: tvdbId,
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: 'library/movie/:movieId/player',
            builder: (context, state) {
              final movieId = state.pathParameters['movieId']!;
              final episodeId = state.uri.queryParameters['episodeId'];
              return MoviePlayerScreen(
                movieId: movieId,
                initialEpisodeId: episodeId,
              );
            },
          ),
          GoRoute(
            path: 'library/section/:section/folder',
            builder: (context, state) {
              final section = state.pathParameters['section'] ?? '';
              final extra = state.extra as LibraryFolderArgs?;
              final parentId =
                  extra?.parentId ?? state.uri.queryParameters['parentId'] ?? '';
              final title =
                  extra?.title ?? state.uri.queryParameters['title'] ?? 'Folder';

              return LibraryFolderScreen(
                args: LibraryFolderArgs(
                  section: section,
                  parentId: parentId,
                  title: title,
                ),
              );
            },
          ),
          GoRoute(
            path: 'library/section/:section/image-viewer',
            builder: (context, state) {
              final extra = state.extra as LibraryImageViewerArgs?;
              if (extra == null) {
                return const _LibraryRouteFallback(
                    message: 'Image viewer requires navigation data.');
              }
              return LibraryImageViewerScreen(args: extra);
            },
          ),
          GoRoute(
            path: 'library/section/:section/audio-player',
            builder: (context, state) {
              final extra = state.extra as LibraryAudioPlayerArgs?;
              if (extra == null) {
                return const _LibraryRouteFallback(
                    message: 'Audio player requires track data.');
              }
              return LibraryAudioPlayerScreen(args: extra);
            },
          ),
          GoRoute(
            path: 'library/section/:section/video-player',
            builder: (context, state) {
              final extra = state.extra as LibraryVideoPlayerArgs?;
              if (extra == null) {
                return const _LibraryRouteFallback(
                    message: 'Video player requires video data.');
              }
              return LibraryVideoPlayerScreen(args: extra);
            },
          ),
          GoRoute(
            path: 'library/section/:section/document',
            builder: (context, state) {
              final extra = state.extra as LibraryDocumentArgs?;
              if (extra == null) {
                return const _LibraryRouteFallback(
                    message: 'Document viewer requires file data.');
              }
              return LibraryDocumentScreen(args: extra);
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
            builder: (context, state) {
              final query = state.uri.queryParameters['q'];
              final tab = state.uri.queryParameters['tab'];
              return SearchScreen(
                initialQuery: query,
                initialTab: tab,
              );
            },
          ),
          GoRoute(
            path: 'settings',
            builder: (context, state) => const SettingsScreen(),
            routes: [
              GoRoute(
                path: 'language',
                builder: (context, state) => const LanguageSelectionScreen(),
              ),
              GoRoute(
                path: 'theme',
                builder: (context, state) => const ThemeSelectionScreen(),
              ),
            ],
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

class _LibraryRouteFallback extends StatelessWidget {
  const _LibraryRouteFallback({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}

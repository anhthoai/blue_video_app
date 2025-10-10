import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/community_post.dart';
import '../../models/video_model.dart';
import 'api_service.dart';

class CommunityService {
  final ApiService _apiService = ApiService();

  // Create a new community post
  Future<Map<String, dynamic>> createPost({
    required String title,
    required String content,
    required PostType type,
    List<String>? images,
    List<String>? videos,
    String? linkUrl,
    String? linkTitle,
    String? linkDescription,
    Map<String, dynamic>? pollOptions,
    List<String>? tags,
    String? category,
    int? cost,
    bool? requiresVip,
    bool? allowComments,
    bool? allowCommentLinks,
    bool? isPinned,
    bool? isNsfw,
    String? replyRestriction,
  }) async {
    try {
      // Call the API service to create the post
      final response = await _apiService.createCommunityPost(
        content: content,
        type: type.name,
        imageFiles:
            images != null ? images.map((path) => File(path)).toList() : null,
        videoFiles:
            videos != null ? videos.map((path) => File(path)).toList() : null,
        linkUrl: linkUrl,
        linkTitle: linkTitle,
        linkDescription: linkDescription,
        pollOptions: pollOptions,
        tags: tags ?? [],
        cost: cost ?? 0,
        requiresVip: requiresVip ?? false,
        allowComments: allowComments ?? true,
        allowCommentLinks: allowCommentLinks ?? false,
        isPinned: isPinned ?? false,
        isNsfw: isNsfw ?? false,
        replyRestriction: replyRestriction ?? 'FOLLOWERS',
      );

      if (response['success'] == true) {
        // Post created successfully
        return {'success': true, 'post': response['data']};
      } else {
        return {'success': false, 'message': response['message']};
      }
    } catch (e) {
      print('Error creating post: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Get community posts with pagination (from API)
  Future<List<CommunityPost>> getPosts({
    int limit = 20,
    int offset = 0,
    String? category,
    String? userId,
    bool featuredOnly = false,
  }) async {
    try {
      final page = (offset ~/ limit) + 1;
      final response = await _apiService.getCommunityPosts(
        page: page,
        limit: limit,
        category: category,
        search: null,
      );

      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> items = response['data'];
        return items.map((json) {
          return CommunityPost(
            id: json['id'] ?? '',
            userId: json['userId'] ?? '',
            username: json['username'] ?? 'User',
            firstName: json['firstName'],
            lastName: json['lastName'],
            isVerified: json['isVerified'] ?? false,
            userAvatar: json['userAvatar'] ?? '',
            title: json['title'],
            content: json['content'],
            type: _mapPostType(json['type']),
            images: List<String>.from(json['images'] ?? const []),
            videos: List<String>.from(json['videos'] ?? const []),
            imageUrls: List<String>.from(json['imageUrls'] ?? const []),
            videoUrls: List<String>.from(json['videoUrls'] ?? const []),
            videoThumbnailUrls:
                List<String>.from(json['videoThumbnailUrls'] ?? const []),
            duration: List<String>.from(json['duration'] ?? const []),
            videoUrl: null,
            linkUrl: json['linkUrl'],
            linkTitle: json['linkTitle'],
            linkDescription: json['linkDescription'],
            linkThumbnail: json['linkThumbnail'],
            pollData: json['pollOptions'],
            tags: List<String>.from(json['tags'] ?? const []),
            category: json['category'],
            likes: json['likes'] ?? 0,
            comments: json['comments'] ?? 0,
            shares: json['shares'] ?? 0,
            views: json['views'] ?? 0,
            isLiked: false,
            isBookmarked: false,
            isPinned: json['isPinned'] ?? false,
            isFeatured: json['isFeatured'] ?? false,
            createdAt:
                DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
            publishedAt:
                DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
          );
        }).toList();
      }

      return [];
    } catch (e) {
      print('Error getting posts: $e');
      return [];
    }
  }

  PostType _mapPostType(dynamic type) {
    final t =
        (type is String) ? type.toUpperCase() : type?.toString().toUpperCase();
    switch (t) {
      case 'TEXT':
        return PostType.text;
      case 'LINK':
        return PostType.link;
      case 'POLL':
        return PostType.poll;
      case 'MEDIA':
      default:
        return PostType.media;
    }
  }

  // Get trending posts
  Future<List<CommunityPost>> getTrendingPosts({
    int limit = 20,
    String? category,
  }) async {
    try {
      // In a real app, this would make an API call
      await Future.delayed(const Duration(milliseconds: 1200));

      // Mock data - generate trending posts
      return List.generate(limit, (index) {
        return CommunityPost(
          id: 'trending_post_$index',
          userId: 'user_${index % 10}',
          username: 'Trending User ${index % 10}',
          userAvatar: 'https://picsum.photos/50/50?random=$index',
          title: 'Trending Post $index',
          content:
              'This is a trending community post $index that is popular right now.',
          type: PostType.values[index % PostType.values.length],
          tags: ['trending', 'viral', 'popular'],
          category: category ?? 'general',
          likes: (index + 1) * 100,
          comments: (index + 1) * 20,
          shares: (index + 1) * 10,
          views: (index + 1) * 500,
          isLiked: index % 2 == 0,
          isBookmarked: index % 3 == 0,
          isPinned: index < 2,
          isFeatured: true,
          createdAt: DateTime.now().subtract(Duration(hours: index)),
        );
      });
    } catch (e) {
      print('Error getting trending posts: $e');
      return [];
    }
  }

  // Get trending videos
  Future<List<VideoModel>> getTrendingVideos({
    int limit = 20,
    String? category,
  }) async {
    try {
      // In a real app, this would make an API call
      await Future.delayed(const Duration(milliseconds: 1000));

      // Mock data - generate trending videos
      return List.generate(limit, (index) {
        return VideoModel(
          id: 'trending_video_$index',
          userId: 'user_${index % 10}',
          title: 'Trending Video $index',
          description:
              'This is a trending video $index with lots of views and engagement.',
          videoUrl: 'https://example.com/video$index.mp4',
          thumbnailUrl: 'https://picsum.photos/400/300?random=$index',
          duration: (index % 10) + 1,
          viewCount: (index + 1) * 10000,
          likeCount: (index + 1) * 1000,
          commentCount: (index + 1) * 100,
          shareCount: (index + 1) * 50,
          isPublic: true,
          isFeatured: true,
          createdAt: DateTime.now().subtract(Duration(hours: index)),
          tags: ['trending', 'viral', 'popular'],
          category: category ?? 'general',
        );
      });
    } catch (e) {
      print('Error getting trending videos: $e');
      return [];
    }
  }

  // Like a post
  Future<bool> likePost({
    required String postId,
    required String userId,
  }) async {
    try {
      // In a real app, this would make an API call
      await Future.delayed(const Duration(milliseconds: 500));

      print('Liked post: $postId by user: $userId');
      return true;
    } catch (e) {
      print('Error liking post: $e');
      return false;
    }
  }

  // Unlike a post
  Future<bool> unlikePost({
    required String postId,
    required String userId,
  }) async {
    try {
      // In a real app, this would make an API call
      await Future.delayed(const Duration(milliseconds: 500));

      print('Unliked post: $postId by user: $userId');
      return true;
    } catch (e) {
      print('Error unliking post: $e');
      return false;
    }
  }

  // Bookmark a post
  Future<bool> bookmarkPost({
    required String postId,
    required String userId,
  }) async {
    try {
      // In a real app, this would make an API call
      await Future.delayed(const Duration(milliseconds: 500));

      print('Bookmarked post: $postId by user: $userId');
      return true;
    } catch (e) {
      print('Error bookmarking post: $e');
      return false;
    }
  }

  // Remove bookmark
  Future<bool> removeBookmark({
    required String postId,
    required String userId,
  }) async {
    try {
      // In a real app, this would make an API call
      await Future.delayed(const Duration(milliseconds: 500));

      print('Removed bookmark for post: $postId by user: $userId');
      return true;
    } catch (e) {
      print('Error removing bookmark: $e');
      return false;
    }
  }

  // Report a post
  Future<bool> reportPost({
    required String postId,
    required String userId,
    required String reason,
    String? description,
  }) async {
    try {
      // In a real app, this would make an API call
      await Future.delayed(const Duration(milliseconds: 800));

      print('Reported post: $postId by user: $userId for reason: $reason');
      return true;
    } catch (e) {
      print('Error reporting post: $e');
      return false;
    }
  }

  // Get reported posts (for moderation)
  Future<List<CommunityPost>> getReportedPosts({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      // In a real app, this would make an API call
      await Future.delayed(const Duration(milliseconds: 1000));

      // Mock data - generate reported posts
      return List.generate(limit, (index) {
        return CommunityPost(
          id: 'reported_post_$index',
          userId: 'user_${index % 10}',
          username: 'Reported User ${index % 10}',
          userAvatar: 'https://picsum.photos/50/50?random=$index',
          title: 'Reported Post $index',
          content:
              'This is a reported community post $index that needs moderation.',
          type: PostType.values[index % PostType.values.length],
          status: PostStatus.reported,
          tags: ['reported', 'moderation'],
          category: 'general',
          likes: (index * 5) % 100,
          comments: (index * 2) % 20,
          shares: (index * 1) % 10,
          views: (index * 20) % 200,
          isLiked: false,
          isBookmarked: false,
          isPinned: false,
          isFeatured: false,
          createdAt: DateTime.now().subtract(Duration(days: index)),
        );
      });
    } catch (e) {
      print('Error getting reported posts: $e');
      return [];
    }
  }

  // Moderate a post (approve, reject, delete)
  Future<bool> moderatePost({
    required String postId,
    required String moderatorId,
    required String action, // 'approve', 'reject', 'delete'
    String? reason,
  }) async {
    try {
      // In a real app, this would make an API call
      await Future.delayed(const Duration(milliseconds: 800));

      print(
          'Moderated post: $postId by moderator: $moderatorId with action: $action');
      return true;
    } catch (e) {
      print('Error moderating post: $e');
      return false;
    }
  }

  // Get user's bookmarked posts
  Future<List<CommunityPost>> getBookmarkedPosts({
    required String userId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      // In a real app, this would make an API call
      await Future.delayed(const Duration(milliseconds: 1000));

      // Mock data - generate bookmarked posts
      return List.generate(limit, (index) {
        return CommunityPost(
          id: 'bookmarked_post_$index',
          userId: 'user_${index % 10}',
          username: 'Bookmarked User ${index % 10}',
          userAvatar: 'https://picsum.photos/50/50?random=$index',
          title: 'Bookmarked Post $index',
          content:
              'This is a bookmarked community post $index that the user saved.',
          type: PostType.values[index % PostType.values.length],
          tags: ['bookmarked', 'saved'],
          category: 'general',
          likes: (index * 8) % 200,
          comments: (index * 3) % 30,
          shares: (index * 2) % 20,
          views: (index * 30) % 300,
          isLiked: index % 2 == 0,
          isBookmarked: true,
          isPinned: false,
          isFeatured: false,
          createdAt: DateTime.now().subtract(Duration(days: index)),
        );
      });
    } catch (e) {
      print('Error getting bookmarked posts: $e');
      return [];
    }
  }

  // Search posts
  Future<List<CommunityPost>> searchPosts({
    required String query,
    int limit = 20,
    int offset = 0,
    String? category,
  }) async {
    try {
      // In a real app, this would make an API call
      await Future.delayed(const Duration(milliseconds: 1200));

      // Mock data - generate search results
      return List.generate(limit, (index) {
        return CommunityPost(
          id: 'search_post_$index',
          userId: 'user_${index % 10}',
          username: 'Search User ${index % 10}',
          userAvatar: 'https://picsum.photos/50/50?random=$index',
          title: 'Search Result $index for "$query"',
          content:
              'This is a search result $index that matches the query "$query".',
          type: PostType.values[index % PostType.values.length],
          tags: ['search', 'result', query],
          category: category ?? 'general',
          likes: (index * 6) % 150,
          comments: (index * 4) % 40,
          shares: (index * 2) % 25,
          views: (index * 25) % 250,
          isLiked: index % 3 == 0,
          isBookmarked: index % 4 == 0,
          isPinned: false,
          isFeatured: false,
          createdAt: DateTime.now().subtract(Duration(hours: index)),
        );
      });
    } catch (e) {
      print('Error searching posts: $e');
      return [];
    }
  }

  // Get categories
  Future<List<String>> getCategories() async {
    try {
      // In a real app, this would make an API call
      await Future.delayed(const Duration(milliseconds: 500));

      return [
        'general',
        'technology',
        'entertainment',
        'sports',
        'news',
        'lifestyle',
        'education',
        'business',
        'health',
        'travel',
      ];
    } catch (e) {
      print('Error getting categories: $e');
      return [];
    }
  }
}

// Provider
final communityServiceProvider = Provider<CommunityService>((ref) {
  return CommunityService();
});

// Community service state provider
final communityServiceStateProvider =
    StateNotifierProvider<CommunityServiceNotifier, CommunityServiceState>(
        (ref) {
  return CommunityServiceNotifier();
});

// Community service state
class CommunityServiceState {
  final List<CommunityPost> posts;
  final List<CommunityPost> trendingPosts;
  final List<VideoModel> trendingVideos;
  final List<CommunityPost> reportedPosts;
  final List<CommunityPost> bookmarkedPosts;
  final List<CommunityPost> searchResults;
  final List<String> categories;
  final bool isLoading;
  final String? error;

  const CommunityServiceState({
    this.posts = const [],
    this.trendingPosts = const [],
    this.trendingVideos = const [],
    this.reportedPosts = const [],
    this.bookmarkedPosts = const [],
    this.searchResults = const [],
    this.categories = const [],
    this.isLoading = false,
    this.error,
  });

  CommunityServiceState copyWith({
    List<CommunityPost>? posts,
    List<CommunityPost>? trendingPosts,
    List<VideoModel>? trendingVideos,
    List<CommunityPost>? reportedPosts,
    List<CommunityPost>? bookmarkedPosts,
    List<CommunityPost>? searchResults,
    List<String>? categories,
    bool? isLoading,
    String? error,
  }) {
    return CommunityServiceState(
      posts: posts ?? this.posts,
      trendingPosts: trendingPosts ?? this.trendingPosts,
      trendingVideos: trendingVideos ?? this.trendingVideos,
      reportedPosts: reportedPosts ?? this.reportedPosts,
      bookmarkedPosts: bookmarkedPosts ?? this.bookmarkedPosts,
      searchResults: searchResults ?? this.searchResults,
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

// Community service notifier
class CommunityServiceNotifier extends StateNotifier<CommunityServiceState> {
  CommunityServiceNotifier() : super(const CommunityServiceState()) {
    // CommunityServiceNotifier initialized
  }

  Future<void> loadPosts({
    String? category,
    String? userId,
    bool featuredOnly = false,
  }) async {
    // Loading posts...
    try {
      state = state.copyWith(isLoading: true, error: null);
      final service = CommunityService();
      final posts = await service.getPosts(
        limit: 20,
        offset: 0,
        category: category,
        userId: userId,
        featuredOnly: featuredOnly,
      );
      state = state.copyWith(
        posts: posts,
        isLoading: false,
      );
      // Posts loaded successfully
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadTrendingPosts({String? category}) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      // Generate mock trending posts directly
      final posts = List.generate(10, (index) {
        final postTypes = PostType.values;
        final postType = postTypes[index % postTypes.length];

        return CommunityPost(
          id: 'trending_post_$index',
          userId: 'user_${index % 10}',
          username: 'Trending User ${index % 10}',
          userAvatar: 'https://picsum.photos/50/50?random=$index',
          title: 'Trending Post $index',
          content:
              'This is a trending community post $index with viral content.',
          type: postType,
          images: postType == PostType.media
              ? [
                  'https://picsum.photos/400/300?random=$index',
                  'https://picsum.photos/400/300?random=${index + 100}',
                ]
              : [],
          videos: postType == PostType.media
              ? ['https://example.com/trending_video$index.mp4']
              : [],
          videoUrl: null,
          tags: ['trending', 'viral', 'popular'],
          category: category ?? 'general',
          likes: (index * 100) + 500, // Higher likes for trending
          comments: (index * 10) + 50,
          shares: (index * 5) + 25,
          views: (index * 500) + 2000,
          isLiked: index % 2 == 0,
          isBookmarked: index % 3 == 0,
          isPinned: false,
          isFeatured: true,
          createdAt: DateTime.now().subtract(Duration(hours: index)),
          publishedAt: DateTime.now().subtract(Duration(hours: index)),
        );
      });

      state = state.copyWith(
        trendingPosts: posts,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadTrendingVideos({String? category}) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final communityService = CommunityService();
      final videos =
          await communityService.getTrendingVideos(category: category);

      state = state.copyWith(
        trendingVideos: videos,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadReportedPosts() async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final communityService = CommunityService();
      final posts = await communityService.getReportedPosts();

      state = state.copyWith(
        reportedPosts: posts,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadBookmarkedPosts(String userId) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final communityService = CommunityService();
      final posts = await communityService.getBookmarkedPosts(userId: userId);

      state = state.copyWith(
        bookmarkedPosts: posts,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> searchPosts({
    required String query,
    String? category,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final communityService = CommunityService();
      final posts = await communityService.searchPosts(
        query: query,
        category: category,
      );

      state = state.copyWith(
        searchResults: posts,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadCategories() async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final communityService = CommunityService();
      final categories = await communityService.getCategories();

      state = state.copyWith(
        categories: categories,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> likePost(String postId, String userId) async {
    try {
      final communityService = CommunityService();
      final success = await communityService.likePost(
        postId: postId,
        userId: userId,
      );

      if (success) {
        // Update local state
        final updatedPosts = state.posts.map((post) {
          if (post.id == postId) {
            return post.copyWith(
              likes: post.likes + 1,
              isLiked: true,
            );
          }
          return post;
        }).toList();

        state = state.copyWith(posts: updatedPosts);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> unlikePost(String postId, String userId) async {
    try {
      final communityService = CommunityService();
      final success = await communityService.unlikePost(
        postId: postId,
        userId: userId,
      );

      if (success) {
        // Update local state
        final updatedPosts = state.posts.map((post) {
          if (post.id == postId) {
            return post.copyWith(
              likes: post.likes - 1,
              isLiked: false,
            );
          }
          return post;
        }).toList();

        state = state.copyWith(posts: updatedPosts);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> bookmarkPost(String postId, String userId) async {
    try {
      final communityService = CommunityService();
      final success = await communityService.bookmarkPost(
        postId: postId,
        userId: userId,
      );

      if (success) {
        // Update local state
        final updatedPosts = state.posts.map((post) {
          if (post.id == postId) {
            return post.copyWith(isBookmarked: true);
          }
          return post;
        }).toList();

        state = state.copyWith(posts: updatedPosts);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> removeBookmark(String postId, String userId) async {
    try {
      final communityService = CommunityService();
      final success = await communityService.removeBookmark(
        postId: postId,
        userId: userId,
      );

      if (success) {
        // Update local state
        final updatedPosts = state.posts.map((post) {
          if (post.id == postId) {
            return post.copyWith(isBookmarked: false);
          }
          return post;
        }).toList();

        state = state.copyWith(posts: updatedPosts);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> reportPost({
    required String postId,
    required String userId,
    required String reason,
    String? description,
  }) async {
    try {
      final communityService = CommunityService();
      final success = await communityService.reportPost(
        postId: postId,
        userId: userId,
        reason: reason,
        description: description,
      );

      if (success) {
        // Show success message
        print('Post reported successfully');
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> moderatePost({
    required String postId,
    required String moderatorId,
    required String action,
    String? reason,
  }) async {
    try {
      final communityService = CommunityService();
      final success = await communityService.moderatePost(
        postId: postId,
        moderatorId: moderatorId,
        action: action,
        reason: reason,
      );

      if (success) {
        // Update local state
        final updatedReportedPosts =
            state.reportedPosts.where((post) => post.id != postId).toList();

        state = state.copyWith(reportedPosts: updatedReportedPosts);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

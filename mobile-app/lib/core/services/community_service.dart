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
  // Like/Unlike a post
  Future<bool> likePost(String postId) async {
    try {
      final response = await _apiService.likeCommunityPost(postId);
      return response['liked'] as bool;
    } catch (e) {
      print('Error liking post: $e');
      rethrow;
    }
  }

  // Bookmark/Unbookmark a post
  Future<bool> bookmarkPost(String postId) async {
    try {
      final response = await _apiService.bookmarkCommunityPost(postId);
      return response['bookmarked'] as bool;
    } catch (e) {
      print('Error bookmarking post: $e');
      rethrow;
    }
  }

  // Report a post
  Future<void> reportPost(String postId,
      {String? reason, String? description}) async {
    try {
      await _apiService.reportCommunityPost(postId,
          reason: reason, description: description);
    } catch (e) {
      print('Error reporting post: $e');
      rethrow;
    }
  }

  // Pin/Unpin a post
  Future<bool> pinPost(String postId) async {
    try {
      final response = await _apiService.pinCommunityPost(postId);
      return response['pinned'] as bool;
    } catch (e) {
      print('Error pinning post: $e');
      rethrow;
    }
  }

  // Follow/Unfollow a user
  Future<bool> followUser(String userId) async {
    try {
      final response = await _apiService.followUser(userId);
      return response['following'] as bool;
    } catch (e) {
      print('Error following user: $e');
      rethrow;
    }
  }

  // Increment post views
  Future<void> incrementViews(String postId) async {
    try {
      await _apiService.incrementPostViews(postId);
    } catch (e) {
      print('Error incrementing views: $e');
      // Don't rethrow for views as it's not critical
    }
  }

  // Get posts by tag
  Future<List<CommunityPost>> getPostsByTag(
    String tag, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _apiService.getPostsByTag(
        tag,
        page: (offset ~/ limit) + 1,
        limit: limit,
      );

      if (response['success'] == true) {
        final items = response['data'] as List<dynamic>;
        return items.map<CommunityPost>((json) {
          return CommunityPost(
            id: json['id'],
            userId: json['userId'],
            username: json['username'],
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
            pollData: json['pollData'],
            tags: List<String>.from(json['tags'] ?? const []),
            category: json['category'],
            likes: json['likes'] ?? 0,
            comments: json['comments'] ?? 0,
            shares: json['shares'] ?? 0,
            views: json['views'] ?? 0,
            isLiked: json['isLiked'] ?? false,
            isBookmarked: json['isBookmarked'] ?? false,
            isPinned: json['isPinned'] ?? false,
            createdAt: DateTime.parse(json['createdAt']),
            updatedAt: DateTime.parse(json['updatedAt']),
            firstName: json['firstName'],
            lastName: json['lastName'],
            isVerified: json['isVerified'] ?? false,
            userAvatar: json['userAvatar'] ?? '',
          );
        }).toList();
      } else {
        throw Exception(response['message'] ?? 'Failed to fetch posts by tag');
      }
    } catch (e) {
      print('Error getting posts by tag: $e');
      rethrow;
    }
  }

  // Get trending posts (ordered by views)
  Future<List<CommunityPost>> getTrendingPosts({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _apiService.getTrendingPosts(
        page: (offset ~/ limit) + 1,
        limit: limit,
      );

      if (response['success'] == true) {
        final items = response['data'] as List<dynamic>;
        return items.map<CommunityPost>((json) {
          return CommunityPost(
            id: json['id'],
            userId: json['userId'],
            username: json['username'],
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
            pollData: json['pollData'],
            tags: List<String>.from(json['tags'] ?? const []),
            category: json['category'],
            likes: json['likes'] ?? 0,
            comments: json['comments'] ?? 0,
            shares: json['shares'] ?? 0,
            views: json['views'] ?? 0,
            isLiked: json['isLiked'] ?? false,
            isBookmarked: json['isBookmarked'] ?? false,
            isPinned: json['isPinned'] ?? false,
            createdAt: DateTime.parse(json['createdAt']),
            updatedAt: DateTime.parse(json['updatedAt']),
            firstName: json['firstName'],
            lastName: json['lastName'],
            isVerified: json['isVerified'] ?? false,
            userAvatar: json['userAvatar'] ?? '',
          );
        }).toList();
      } else {
        throw Exception(
            response['message'] ?? 'Failed to fetch trending posts');
      }
    } catch (e) {
      print('Error getting trending posts: $e');
      rethrow;
    }
  }

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
            isLiked: json['isLiked'] ?? false,
            isBookmarked: json['isBookmarked'] ?? false,
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

  // Get tags from community posts
  Future<List<String>> getTags() async {
    try {
      final response = await _apiService.getCommunityTags();

      if (response['success'] == true && response['tags'] != null) {
        final List<dynamic> tagsList = response['tags'];
        return tagsList.map((tag) => tag.toString()).toList();
      } else {
        throw Exception(response['message'] ?? 'Failed to fetch tags');
      }
    } catch (e) {
      print('Error getting tags: $e');
      return [];
    }
  }

  // Get categories (legacy method - now returns tags)
  Future<List<String>> getCategories() async {
    return await getTags();
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
  final List<CommunityPost> tagPosts; // Posts filtered by tag
  final String? currentTag; // Currently selected tag
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
    this.tagPosts = const [],
    this.currentTag,
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
    List<CommunityPost>? tagPosts,
    String? currentTag,
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
      tagPosts: tagPosts ?? this.tagPosts,
      currentTag: currentTag ?? this.currentTag,
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

      // Load trending posts from API
      final service = CommunityService();
      final posts = await service.getTrendingPosts();

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

  // Load tags from community posts
  Future<void> loadTags() async {
    await loadCategories(); // Uses the same method since getCategories() now returns tags
  }

  // Like/Unlike a post
  Future<void> likePost(String postId) async {
    try {
      final service = CommunityService();
      final liked = await service.likePost(postId);

      // Update the post in the state
      final updatedPosts = state.posts.map((post) {
        if (post.id == postId) {
          return post.copyWith(
            likes: liked ? post.likes + 1 : post.likes - 1,
          );
        }
        return post;
      }).toList();

      state = state.copyWith(posts: updatedPosts);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // Bookmark/Unbookmark a post
  Future<void> bookmarkPost(String postId) async {
    try {
      final service = CommunityService();
      await service.bookmarkPost(postId);
      // You could add bookmark state tracking here if needed
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // Follow/Unfollow a user
  Future<void> followUser(String userId) async {
    try {
      final service = CommunityService();
      await service.followUser(userId);
      // You could add follow state tracking here if needed
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // Increment post views
  Future<void> incrementViews(String postId) async {
    try {
      final service = CommunityService();
      await service.incrementViews(postId);

      // Update the post in the state
      final updatedPosts = state.posts.map((post) {
        if (post.id == postId) {
          return post.copyWith(views: post.views + 1);
        }
        return post;
      }).toList();

      state = state.copyWith(posts: updatedPosts);
    } catch (e) {
      // Don't update state for view errors as it's not critical
    }
  }

  // Load posts by tag
  Future<void> loadPostsByTag(String tag) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final service = CommunityService();
      final posts = await service.getPostsByTag(tag);
      state = state.copyWith(
        tagPosts: posts,
        currentTag: tag,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  // Clear tag posts (when returning to main community screen)
  void clearTagPosts() {
    state = state.copyWith(
      tagPosts: const [],
      currentTag: null,
    );
  }

  Future<void> pinPost(String postId) async {
    try {
      final service = CommunityService();
      await service.pinPost(postId);

      // Update the local state to reflect the pin change
      final updatedPosts = state.posts.map((post) {
        if (post.id == postId) {
          return post.copyWith(isPinned: !post.isPinned);
        }
        return post;
      }).toList();

      state = state.copyWith(posts: updatedPosts);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> reportPost(
      String postId, String reason, String description) async {
    try {
      final service = CommunityService();
      await service.reportPost(postId,
          reason: reason, description: description);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

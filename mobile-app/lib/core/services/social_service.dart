import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/comment_model.dart';
import '../../models/like_model.dart';
import '../../models/user_model.dart';
import '../../models/video_model.dart';
import 'api_service.dart';

class SocialService {
  // Like a video, comment, or user
  Future<bool> likeItem({
    required String userId,
    required String targetId,
    required LikeType type,
  }) async {
    try {
      // In a real app, this would make an API call
      await Future.delayed(const Duration(milliseconds: 500));

      print('Liked $type: $targetId by user: $userId');
      return true;
    } catch (e) {
      print('Error liking item: $e');
      return false;
    }
  }

  // Unlike an item
  Future<bool> unlikeItem({
    required String userId,
    required String targetId,
    required LikeType type,
  }) async {
    try {
      // In a real app, this would make an API call
      await Future.delayed(const Duration(milliseconds: 500));

      print('Unliked $type: $targetId by user: $userId');
      return true;
    } catch (e) {
      print('Error unliking item: $e');
      return false;
    }
  }

  // Get like count for an item
  Future<int> getLikeCount({
    required String targetId,
    required LikeType type,
  }) async {
    try {
      // In a real app, this would make an API call
      await Future.delayed(const Duration(milliseconds: 300));

      // Mock data - return random like counts
      final random = DateTime.now().millisecondsSinceEpoch % 1000;
      return random;
    } catch (e) {
      print('Error getting like count: $e');
      return 0;
    }
  }

  // Check if user has liked an item
  Future<bool> hasUserLiked({
    required String userId,
    required String targetId,
    required LikeType type,
  }) async {
    try {
      // In a real app, this would make an API call
      await Future.delayed(const Duration(milliseconds: 200));

      // Mock data - return random like status
      final random = DateTime.now().millisecondsSinceEpoch % 2;
      return random == 1;
    } catch (e) {
      print('Error checking like status: $e');
      return false;
    }
  }

  // Add a comment
  Future<CommentModel?> addComment({
    required String videoId,
    required String userId,
    required String username,
    required String userAvatar,
    required String content,
    String? parentCommentId,
  }) async {
    try {
      // In a real app, this would make an API call
      await Future.delayed(const Duration(milliseconds: 800));

      final comment = CommentModel(
        id: 'comment_${DateTime.now().millisecondsSinceEpoch}',
        videoId: videoId,
        userId: userId,
        username: username,
        userAvatar: userAvatar,
        content: content,
        timestamp: DateTime.now(),
        parentCommentId: parentCommentId,
      );

      print('Added comment: ${comment.id}');
      return comment;
    } catch (e) {
      print('Error adding comment: $e');
      return null;
    }
  }

  // Get comments for a video
  Future<List<CommentModel>> getComments({
    required String videoId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      // In a real app, this would make an API call
      await Future.delayed(const Duration(milliseconds: 1000));

      // Mock data - generate sample comments
      return List.generate(limit, (index) {
        final isReply = index % 3 == 0;
        return CommentModel(
          id: 'comment_${videoId}_$index',
          videoId: videoId,
          userId: 'user_${index % 5}',
          username: 'User ${index % 5}',
          userAvatar: 'https://picsum.photos/50/50?random=$index',
          content: isReply
              ? 'This is a reply to a comment $index'
              : 'This is a sample comment $index for video $videoId',
          timestamp: DateTime.now().subtract(Duration(minutes: index * 5)),
          likes: (index * 3) % 50,
          isLiked: index % 2 == 0,
          parentCommentId: isReply ? 'comment_${videoId}_${index - 1}' : null,
          replies: isReply
              ? []
              : List.generate(2, (replyIndex) {
                  return CommentModel(
                    id: 'reply_${videoId}_${index}_$replyIndex',
                    videoId: videoId,
                    userId: 'user_${(index + replyIndex) % 5}',
                    username: 'User ${(index + replyIndex) % 5}',
                    userAvatar:
                        'https://picsum.photos/50/50?random=${index + replyIndex}',
                    content: 'This is a reply $replyIndex to comment $index',
                    timestamp: DateTime.now()
                        .subtract(Duration(minutes: index * 5 + replyIndex)),
                    likes: (replyIndex * 2) % 20,
                    isLiked: replyIndex % 2 == 1,
                    parentCommentId: 'comment_${videoId}_$index',
                  );
                }),
        );
      });
    } catch (e) {
      print('Error getting comments: $e');
      return [];
    }
  }

  // Follow a user
  Future<bool> followUser({
    required String followerId,
    required String followingId,
  }) async {
    try {
      // In a real app, this would make an API call
      await Future.delayed(const Duration(milliseconds: 500));

      print('User $followerId followed user $followingId');
      return true;
    } catch (e) {
      print('Error following user: $e');
      return false;
    }
  }

  // Unfollow a user
  Future<bool> unfollowUser({
    required String followerId,
    required String followingId,
  }) async {
    try {
      // In a real app, this would make an API call
      await Future.delayed(const Duration(milliseconds: 500));

      print('User $followerId unfollowed user $followingId');
      return true;
    } catch (e) {
      print('Error unfollowing user: $e');
      return false;
    }
  }

  // Get followers of a user
  Future<List<UserModel>> getFollowers({
    required String userId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      // In a real app, this would make an API call
      await Future.delayed(const Duration(milliseconds: 1000));

      // Mock data - generate sample followers
      return List.generate(limit, (index) {
        return UserModel(
          id: 'follower_${userId}_$index',
          username: 'Follower $index',
          email: 'follower$index@example.com',
          avatarUrl: 'https://picsum.photos/50/50?random=$index',
          bio: 'This is follower $index',
          followerCount: (index * 10) % 1000,
          followingCount: (index * 5) % 500,
          videoCount: (index * 3) % 100,
          likeCount: (index * 20) % 5000,
          createdAt: DateTime.now().subtract(Duration(days: index)),
        );
      });
    } catch (e) {
      print('Error getting followers: $e');
      return [];
    }
  }

  // Get users that a user is following
  Future<List<UserModel>> getFollowing({
    required String userId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      // In a real app, this would make an API call
      await Future.delayed(const Duration(milliseconds: 1000));

      // Mock data - generate sample following users
      return List.generate(limit, (index) {
        return UserModel(
          id: 'following_${userId}_$index',
          username: 'Following $index',
          email: 'following$index@example.com',
          avatarUrl: 'https://picsum.photos/50/50?random=$index',
          bio: 'This is following user $index',
          followerCount: (index * 15) % 2000,
          followingCount: (index * 8) % 800,
          videoCount: (index * 4) % 200,
          likeCount: (index * 30) % 10000,
          createdAt: DateTime.now().subtract(Duration(days: index)),
        );
      });
    } catch (e) {
      print('Error getting following: $e');
      return [];
    }
  }

  // Check if user is following another user
  Future<bool> isFollowing({
    required String followerId,
    required String followingId,
  }) async {
    try {
      // In a real app, this would make an API call
      await Future.delayed(const Duration(milliseconds: 200));

      // Mock data - return random follow status
      final random = DateTime.now().millisecondsSinceEpoch % 2;
      return random == 1;
    } catch (e) {
      print('Error checking follow status: $e');
      return false;
    }
  }

  // Get user's like history
  Future<List<LikeModel>> getUserLikes({
    required String userId,
    LikeType? type,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      // In a real app, this would make an API call
      await Future.delayed(const Duration(milliseconds: 1000));

      // Mock data - generate sample likes
      return List.generate(limit, (index) {
        return LikeModel(
          id: 'like_${userId}_$index',
          userId: userId,
          targetId: 'target_$index',
          type: type ?? LikeType.values[index % LikeType.values.length],
          timestamp: DateTime.now().subtract(Duration(hours: index)),
        );
      });
    } catch (e) {
      print('Error getting user likes: $e');
      return [];
    }
  }

  // Share content
  Future<bool> shareContent({
    required String userId,
    required String contentId,
    required String contentType, // 'video', 'user', 'comment'
    String? message,
    List<String>? platforms, // 'facebook', 'twitter', 'instagram', 'whatsapp'
  }) async {
    try {
      // In a real app, this would integrate with social media APIs
      await Future.delayed(const Duration(milliseconds: 1000));

      print('Shared $contentType: $contentId by user: $userId');
      if (message != null) print('Message: $message');
      if (platforms != null) print('Platforms: ${platforms.join(', ')}');

      return true;
    } catch (e) {
      print('Error sharing content: $e');
      return false;
    }
  }

  // Get trending content
  Future<List<VideoModel>> getTrendingVideos({
    int limit = 20,
    String? category,
  }) async {
    try {
      // In a real app, this would make an API call
      await Future.delayed(const Duration(milliseconds: 1500));

      // Mock data - generate trending videos
      return List.generate(limit, (index) {
        return VideoModel(
          id: 'trending_video_$index',
          userId: 'user_${index % 10}',
          title: 'Trending Video $index',
          description:
              'This is a trending video $index with lots of views and likes',
          videoUrl: 'https://example.com/video$index.mp4',
          thumbnailUrl: 'https://picsum.photos/400/300?random=$index',
          duration: (index % 10) + 1,
          viewCount: (index + 1) * 10000,
          likeCount: (index + 1) * 1000,
          commentCount: (index + 1) * 100,
          shareCount: (index + 1) * 50,
          isPublic: true,
          isFeatured: index < 5,
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
}

// Provider
final socialServiceProvider = Provider<SocialService>((ref) {
  return SocialService();
});

// Social service state provider
final socialServiceStateProvider =
    StateNotifierProvider<SocialServiceNotifier, SocialServiceState>((ref) {
  return SocialServiceNotifier();
});

// Social service state
class SocialServiceState {
  final Map<String, bool> likeStatus; // targetId -> isLiked
  final Map<String, int> likeCounts; // targetId -> count
  final Map<String, bool> followStatus; // userId -> isFollowing
  final Map<String, List<CommentModel>> comments; // videoId -> comments
  final Map<String, List<UserModel>> followers; // userId -> followers
  final Map<String, List<UserModel>> following; // userId -> following
  final List<VideoModel> trendingVideos;
  final bool isLoading;
  final String? error;

  const SocialServiceState({
    this.likeStatus = const {},
    this.likeCounts = const {},
    this.followStatus = const {},
    this.comments = const {},
    this.followers = const {},
    this.following = const {},
    this.trendingVideos = const [],
    this.isLoading = false,
    this.error,
  });

  SocialServiceState copyWith({
    Map<String, bool>? likeStatus,
    Map<String, int>? likeCounts,
    Map<String, bool>? followStatus,
    Map<String, List<CommentModel>>? comments,
    Map<String, List<UserModel>>? followers,
    Map<String, List<UserModel>>? following,
    List<VideoModel>? trendingVideos,
    bool? isLoading,
    String? error,
  }) {
    return SocialServiceState(
      likeStatus: likeStatus ?? this.likeStatus,
      likeCounts: likeCounts ?? this.likeCounts,
      followStatus: followStatus ?? this.followStatus,
      comments: comments ?? this.comments,
      followers: followers ?? this.followers,
      following: following ?? this.following,
      trendingVideos: trendingVideos ?? this.trendingVideos,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

// Social service notifier
class SocialServiceNotifier extends StateNotifier<SocialServiceState> {
  final ApiService _apiService = ApiService();

  SocialServiceNotifier() : super(const SocialServiceState());

  Future<void> likeItem({
    required String userId,
    required String targetId,
    required LikeType type,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final socialService = SocialService();
      final success = await socialService.likeItem(
        userId: userId,
        targetId: targetId,
        type: type,
      );

      if (success) {
        final updatedLikeStatus = Map<String, bool>.from(state.likeStatus);
        updatedLikeStatus[targetId] = true;

        final updatedLikeCounts = Map<String, int>.from(state.likeCounts);
        updatedLikeCounts[targetId] = (updatedLikeCounts[targetId] ?? 0) + 1;

        state = state.copyWith(
          likeStatus: updatedLikeStatus,
          likeCounts: updatedLikeCounts,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to like item',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> unlikeItem({
    required String userId,
    required String targetId,
    required LikeType type,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final socialService = SocialService();
      final success = await socialService.unlikeItem(
        userId: userId,
        targetId: targetId,
        type: type,
      );

      if (success) {
        final updatedLikeStatus = Map<String, bool>.from(state.likeStatus);
        updatedLikeStatus[targetId] = false;

        final updatedLikeCounts = Map<String, int>.from(state.likeCounts);
        updatedLikeCounts[targetId] = (updatedLikeCounts[targetId] ?? 1) - 1;

        state = state.copyWith(
          likeStatus: updatedLikeStatus,
          likeCounts: updatedLikeCounts,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to unlike item',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadComments(String videoId,
      {String contentType = 'VIDEO'}) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      // Load comments from API
      final response = await _apiService.getComments(
        contentId: videoId,
        contentType: contentType,
      );

      final comments = <CommentModel>[];
      if (response['success'] == true && response['data'] != null) {
        final commentsData = response['data'] as List;
        for (var commentData in commentsData) {
          // Process replies if they exist
          final replies = <CommentModel>[];
          if (commentData['replies'] != null) {
            final repliesData = commentData['replies'] as List;
            for (var replyData in repliesData) {
              replies.add(CommentModel(
                id: replyData['id'] ?? 'unknown',
                videoId: videoId,
                userId: replyData['userId'] ?? 'unknown',
                username: replyData['username'] ?? 'User',
                userAvatar: replyData['userAvatar'],
                content: replyData['content'] ?? '',
                timestamp: DateTime.parse(
                    replyData['createdAt'] ?? DateTime.now().toIso8601String()),
                likes: replyData['likes'] ?? 0,
                isLiked: replyData['isLiked'] ?? false,
                parentCommentId: replyData['parentCommentId'],
              ));
            }
          }

          comments.add(CommentModel(
            id: commentData['id'] ?? 'unknown',
            videoId: videoId,
            userId: commentData['userId'] ?? 'unknown',
            username: commentData['username'] ?? 'User',
            userAvatar: commentData['userAvatar'],
            content: commentData['content'] ?? '',
            timestamp: DateTime.parse(
                commentData['createdAt'] ?? DateTime.now().toIso8601String()),
            likes: commentData['likes'] ?? 0,
            isLiked: commentData['isLiked'] ?? false,
            parentCommentId: commentData['parentCommentId'],
            replies: replies,
          ));
        }
      }

      final updatedComments =
          Map<String, List<CommentModel>>.from(state.comments);
      updatedComments[videoId] = comments;

      print('Loaded ${comments.length} comments for video $videoId from API');

      state = state.copyWith(
        comments: updatedComments,
        isLoading: false,
      );
    } catch (e) {
      print('Error loading comments: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> addComment({
    required String videoId,
    required String userId,
    required String username,
    required String userAvatar,
    required String content,
    String? parentCommentId,
    String contentType = 'VIDEO',
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      // Add comment via API
      final response = await _apiService.addComment(
        contentId: videoId,
        contentType: contentType,
        content: content,
        parentCommentId: parentCommentId,
      );

      if (response['success'] == true && response['data'] != null) {
        final commentData = response['data'];
        final comment = CommentModel(
          id: commentData['id'] ?? 'unknown',
          videoId: videoId,
          userId: commentData['userId'] ?? 'unknown',
          username: commentData['username'] ?? 'User',
          userAvatar: commentData['userAvatar'],
          content: commentData['content'] ?? '',
          timestamp: DateTime.parse(
              commentData['createdAt'] ?? DateTime.now().toIso8601String()),
          likes: commentData['likes'] ?? 0,
          isLiked: commentData['isLiked'] ?? false,
          parentCommentId: commentData['parentCommentId'],
        );

        final updatedComments =
            Map<String, List<CommentModel>>.from(state.comments);

        if (parentCommentId != null) {
          // This is a reply - add it to the parent comment's replies
          if (updatedComments[videoId] != null) {
            final comments = updatedComments[videoId]!;
            final parentIndex =
                comments.indexWhere((c) => c.id == parentCommentId);
            if (parentIndex != -1) {
              final parentComment = comments[parentIndex];
              final updatedReplies = [...parentComment.replies, comment];
              final updatedParentComment =
                  parentComment.copyWith(replies: updatedReplies);
              comments[parentIndex] = updatedParentComment;
              updatedComments[videoId] = comments;
            }
          }
        } else {
          // This is a top-level comment
          if (updatedComments[videoId] != null) {
            updatedComments[videoId] = [comment, ...updatedComments[videoId]!];
          } else {
            updatedComments[videoId] = [comment];
          }
        }

        state = state.copyWith(
          comments: updatedComments,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to add comment',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  // Toggle like on comment
  Future<void> toggleCommentLike(String commentId, String videoId) async {
    try {
      final response = await _apiService.toggleCommentLike(commentId);

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        final updatedComments =
            Map<String, List<CommentModel>>.from(state.comments);

        if (updatedComments[videoId] != null) {
          final comments = updatedComments[videoId]!;

          // First, try to find the comment in top-level comments
          final commentIndex = comments.indexWhere((c) => c.id == commentId);

          if (commentIndex != -1) {
            // Found in top-level comments
            final comment = comments[commentIndex];
            final updatedComment = comment.copyWith(
              likes: data['likes'] ?? comment.likes,
              isLiked: data['isLiked'] ?? comment.isLiked,
            );

            comments[commentIndex] = updatedComment;
            updatedComments[videoId] = comments;

            state = state.copyWith(comments: updatedComments);
          } else {
            // Search in replies
            for (int i = 0; i < comments.length; i++) {
              final parentComment = comments[i];
              final replyIndex =
                  parentComment.replies.indexWhere((r) => r.id == commentId);

              if (replyIndex != -1) {
                // Found in replies
                final reply = parentComment.replies[replyIndex];
                final updatedReply = reply.copyWith(
                  likes: data['likes'] ?? reply.likes,
                  isLiked: data['isLiked'] ?? reply.isLiked,
                );

                final updatedReplies =
                    List<CommentModel>.from(parentComment.replies);
                updatedReplies[replyIndex] = updatedReply;

                final updatedParentComment =
                    parentComment.copyWith(replies: updatedReplies);
                comments[i] = updatedParentComment;
                updatedComments[videoId] = comments;

                state = state.copyWith(comments: updatedComments);
                break;
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error toggling comment like: $e');
    }
  }

  // Edit comment
  Future<void> editComment(
      String commentId, String videoId, String content) async {
    try {
      final response = await _apiService.editComment(commentId, content);

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        final updatedComments =
            Map<String, List<CommentModel>>.from(state.comments);

        if (updatedComments[videoId] != null) {
          final comments = updatedComments[videoId]!;

          // First, try to find the comment in top-level comments
          final commentIndex = comments.indexWhere((c) => c.id == commentId);

          if (commentIndex != -1) {
            // Found in top-level comments
            final comment = comments[commentIndex];
            final updatedComment = comment.copyWith(
              content: data['content'] ?? comment.content,
            );

            comments[commentIndex] = updatedComment;
            updatedComments[videoId] = comments;

            state = state.copyWith(comments: updatedComments);
          } else {
            // Search in replies
            for (int i = 0; i < comments.length; i++) {
              final parentComment = comments[i];
              final replyIndex =
                  parentComment.replies.indexWhere((r) => r.id == commentId);

              if (replyIndex != -1) {
                // Found in replies
                final reply = parentComment.replies[replyIndex];
                final updatedReply = reply.copyWith(
                  content: data['content'] ?? reply.content,
                );

                final updatedReplies =
                    List<CommentModel>.from(parentComment.replies);
                updatedReplies[replyIndex] = updatedReply;

                final updatedParentComment =
                    parentComment.copyWith(replies: updatedReplies);
                comments[i] = updatedParentComment;
                updatedComments[videoId] = comments;

                state = state.copyWith(comments: updatedComments);
                break;
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error editing comment: $e');
      rethrow;
    }
  }

  // Delete comment
  Future<void> deleteComment(String commentId, String videoId) async {
    try {
      final response = await _apiService.deleteComment(commentId);

      if (response['success'] == true) {
        final updatedComments =
            Map<String, List<CommentModel>>.from(state.comments);

        if (updatedComments[videoId] != null) {
          final comments = updatedComments[videoId]!;

          // First, try to remove from top-level comments
          final commentIndex = comments.indexWhere((c) => c.id == commentId);

          if (commentIndex != -1) {
            // Found in top-level comments - remove it
            comments.removeAt(commentIndex);
          } else {
            // Search in replies
            for (int i = 0; i < comments.length; i++) {
              final parentComment = comments[i];
              final replyIndex =
                  parentComment.replies.indexWhere((r) => r.id == commentId);

              if (replyIndex != -1) {
                // Found in replies - remove it
                final updatedReplies =
                    List<CommentModel>.from(parentComment.replies);
                updatedReplies.removeAt(replyIndex);

                final updatedParentComment =
                    parentComment.copyWith(replies: updatedReplies);
                comments[i] = updatedParentComment;
                break;
              }
            }
          }

          updatedComments[videoId] = comments;
          state = state.copyWith(comments: updatedComments);
        }
      }
    } catch (e) {
      print('Error deleting comment: $e');
      rethrow;
    }
  }

  Future<void> followUser({
    required String followerId,
    required String followingId,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final socialService = SocialService();
      final success = await socialService.followUser(
        followerId: followerId,
        followingId: followingId,
      );

      if (success) {
        final updatedFollowStatus = Map<String, bool>.from(state.followStatus);
        updatedFollowStatus[followingId] = true;

        state = state.copyWith(
          followStatus: updatedFollowStatus,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to follow user',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> unfollowUser({
    required String followerId,
    required String followingId,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final socialService = SocialService();
      final success = await socialService.unfollowUser(
        followerId: followerId,
        followingId: followingId,
      );

      if (success) {
        final updatedFollowStatus = Map<String, bool>.from(state.followStatus);
        updatedFollowStatus[followingId] = false;

        state = state.copyWith(
          followStatus: updatedFollowStatus,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to unfollow user',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadTrendingVideos() async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final socialService = SocialService();
      final videos = await socialService.getTrendingVideos();

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
}

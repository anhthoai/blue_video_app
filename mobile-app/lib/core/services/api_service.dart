import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/video_model.dart';
import '../../models/user_model.dart';

class ApiService {
  final Dio _dio = Dio();
  final String baseUrl =
      'https://api.bluevideoapp.com'; // Replace with actual API URL

  ApiService() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);

    // Add interceptors for authentication and logging
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));
  }

  // Set authentication token
  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  // Remove authentication token
  void clearAuthToken() {
    _dio.options.headers.remove('Authorization');
  }

  // Video API endpoints
  Future<List<VideoModel>> getVideos({
    int page = 1,
    int limit = 20,
    String? category,
    String? search,
  }) async {
    try {
      final response = await _dio.get('/videos', queryParameters: {
        'page': page,
        'limit': limit,
        if (category != null) 'category': category,
        if (search != null) 'search': search,
      });

      final List<dynamic> videosJson = response.data['data'];
      return videosJson.map((json) => VideoModel.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching videos: $e');
      return [];
    }
  }

  Future<VideoModel?> getVideoById(String videoId) async {
    try {
      final response = await _dio.get('/videos/$videoId');
      return VideoModel.fromJson(response.data);
    } catch (e) {
      print('Error fetching video: $e');
      return null;
    }
  }

  Future<VideoModel?> createVideo(VideoModel video) async {
    try {
      final response = await _dio.post('/videos', data: video.toJson());
      return VideoModel.fromJson(response.data);
    } catch (e) {
      print('Error creating video: $e');
      return null;
    }
  }

  Future<VideoModel?> updateVideo(String videoId, VideoModel video) async {
    try {
      final response = await _dio.put('/videos/$videoId', data: video.toJson());
      return VideoModel.fromJson(response.data);
    } catch (e) {
      print('Error updating video: $e');
      return null;
    }
  }

  Future<bool> deleteVideo(String videoId) async {
    try {
      await _dio.delete('/videos/$videoId');
      return true;
    } catch (e) {
      print('Error deleting video: $e');
      return false;
    }
  }

  Future<bool> likeVideo(String videoId) async {
    try {
      await _dio.post('/videos/$videoId/like');
      return true;
    } catch (e) {
      print('Error liking video: $e');
      return false;
    }
  }

  Future<bool> unlikeVideo(String videoId) async {
    try {
      await _dio.delete('/videos/$videoId/like');
      return true;
    } catch (e) {
      print('Error unliking video: $e');
      return false;
    }
  }

  // User API endpoints
  Future<List<UserModel>> getUsers({
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    try {
      final response = await _dio.get('/users', queryParameters: {
        'page': page,
        'limit': limit,
        if (search != null) 'search': search,
      });

      final List<dynamic> usersJson = response.data['data'];
      return usersJson.map((json) => UserModel.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching users: $e');
      return [];
    }
  }

  Future<UserModel?> getUserById(String userId) async {
    try {
      final response = await _dio.get('/users/$userId');
      return UserModel.fromJson(response.data);
    } catch (e) {
      print('Error fetching user: $e');
      return null;
    }
  }

  Future<UserModel?> updateUser(String userId, UserModel user) async {
    try {
      final response = await _dio.put('/users/$userId', data: user.toJson());
      return UserModel.fromJson(response.data);
    } catch (e) {
      print('Error updating user: $e');
      return null;
    }
  }

  Future<bool> followUser(String userId) async {
    try {
      await _dio.post('/users/$userId/follow');
      return true;
    } catch (e) {
      print('Error following user: $e');
      return false;
    }
  }

  Future<bool> unfollowUser(String userId) async {
    try {
      await _dio.delete('/users/$userId/follow');
      return true;
    } catch (e) {
      print('Error unfollowing user: $e');
      return false;
    }
  }

  // Mock data for development
  Future<List<VideoModel>> getMockVideos() async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay

    return List.generate(10, (index) {
      return VideoModel(
        id: 'video_$index',
        userId: 'user_$index',
        title: 'Sample Video ${index + 1}',
        description:
            'This is a sample video description for video ${index + 1}',
        videoUrl:
            'https://sample-videos.com/zip/10/mp4/SampleVideo_${index + 1}.mp4',
        thumbnailUrl: 'https://picsum.photos/400/225?random=$index',
        duration: (index + 1) * 30, // 30 seconds to 5 minutes
        viewCount: (index + 1) * 1000,
        likeCount: (index + 1) * 100,
        commentCount: (index + 1) * 50,
        shareCount: (index + 1) * 25,
        isPublic: true,
        isFeatured: index < 3,
        createdAt: DateTime.now().subtract(Duration(days: index)),
        tags: ['sample', 'video', 'test'],
        category: index % 3 == 0
            ? 'Entertainment'
            : index % 3 == 1
                ? 'Education'
                : 'Sports',
      );
    });
  }

  Future<List<UserModel>> getMockUsers() async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay

    return List.generate(10, (index) {
      return UserModel(
        id: 'user_$index',
        email: 'user$index@example.com',
        username: 'user_$index',
        avatarUrl: 'https://picsum.photos/100/100?random=$index',
        bio: 'This is a sample bio for user $index',
        createdAt: DateTime.now().subtract(Duration(days: index * 10)),
        isVerified: index < 3,
        isVip: index < 2,
        vipLevel: index < 2 ? index + 1 : 0,
        coinBalance: (index + 1) * 1000,
        followerCount: (index + 1) * 100,
        followingCount: (index + 1) * 50,
        videoCount: (index + 1) * 10,
        likeCount: (index + 1) * 500,
      );
    });
  }
}

// Provider
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

// Video list provider
final videoListProvider = FutureProvider<List<VideoModel>>((ref) async {
  final apiService = ref.watch(apiServiceProvider);
  return await apiService.getMockVideos();
});

// User list provider
final userListProvider = FutureProvider<List<UserModel>>((ref) async {
  final apiService = ref.watch(apiServiceProvider);
  return await apiService.getMockUsers();
});

// Video detail provider
final videoDetailProvider =
    FutureProvider.family<VideoModel?, String>((ref, videoId) async {
  final apiService = ref.watch(apiServiceProvider);
  return await apiService.getVideoById(videoId);
});

// User detail provider
final userDetailProvider =
    FutureProvider.family<UserModel?, String>((ref, userId) async {
  final apiService = ref.watch(apiServiceProvider);
  return await apiService.getUserById(userId);
});

import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/video_model.dart';
import 'api_service.dart';

class VideoService {
  final ApiService _apiService = ApiService();
  final ImagePicker _imagePicker = ImagePicker();

  // Pick video from gallery
  Future<File?> pickVideoFromGallery() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 10),
      );
      return video != null ? File(video.path) : null;
    } catch (e) {
      print('Error picking video from gallery: $e');
      return null;
    }
  }

  // Record video with camera
  Future<File?> recordVideoWithCamera() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 10),
      );
      return video != null ? File(video.path) : null;
    } catch (e) {
      print('Error recording video: $e');
      return null;
    }
  }

  // Upload video
  Future<VideoModel?> uploadVideo({
    required File videoFile,
    required String title,
    String? description,
    String? thumbnailPath,
    List<String>? tags,
    String? category,
  }) async {
    try {
      final response = await _apiService.uploadVideo(
        title: title,
        description: description,
        videoFile: videoFile,
        thumbnailPath: thumbnailPath,
      );

      if (response['success'] == true && response['data'] != null) {
        final videoData = response['data'];
        return VideoModel(
          id: videoData['id'] ?? 'unknown',
          userId: videoData['userId'] ?? 'unknown',
          title: videoData['title'] ?? title,
          description: videoData['description'] ?? description,
          videoUrl: videoData['videoUrl'] ?? '',
          thumbnailUrl: videoData['thumbnailUrl'],
          duration: videoData['duration'],
          viewCount: 0,
          likeCount: 0,
          commentCount: 0,
          shareCount: 0,
          isPublic: true,
          isFeatured: false,
          createdAt: DateTime.parse(
              videoData['createdAt'] ?? DateTime.now().toIso8601String()),
          tags: tags ?? [],
          category: category ?? 'general',
        );
      }
      return null;
    } catch (e) {
      print('Error uploading video: $e');
      return null;
    }
  }

  // Get videos with pagination
  Future<List<VideoModel>> getVideos({
    int page = 1,
    int limit = 20,
    String? category,
    String? search,
  }) async {
    try {
      final response = await _apiService.getVideos(
        page: page,
        limit: limit,
        category: category,
        search: search,
      );

      if (response['success'] == true && response['data'] != null) {
        final videosData = response['data'] as List;
        return videosData.map((videoData) {
          return VideoModel(
            id: videoData['id'] ?? 'unknown',
            userId: videoData['userId'] ?? 'unknown',
            title: videoData['title'] ?? 'Untitled',
            description: videoData['description'],
            videoUrl: videoData['videoUrl'] ?? '',
            thumbnailUrl: videoData['thumbnailUrl'],
            duration: videoData['duration'],
            viewCount: videoData['viewCount'] ?? 0,
            likeCount: videoData['likeCount'] ?? 0,
            commentCount: videoData['commentCount'] ?? 0,
            shareCount: videoData['shareCount'] ?? 0,
            isPublic: videoData['isPublic'] ?? true,
            isFeatured: videoData['isFeatured'] ?? false,
            createdAt: DateTime.parse(
                videoData['createdAt'] ?? DateTime.now().toIso8601String()),
            tags: List<String>.from(videoData['tags'] ?? []),
            category: videoData['category'],
          );
        }).toList();
      }
      return [];
    } catch (e) {
      print('Error getting videos: $e');
      return [];
    }
  }

  // Get trending videos
  Future<List<VideoModel>> getTrendingVideos({
    int limit = 10,
    String? category,
  }) async {
    try {
      // For now, return mock data
      return List.generate(limit, (index) {
        return VideoModel(
          id: 'trending_video_$index',
          userId: 'user_${index % 10}',
          title: 'Trending Video $index',
          description: 'This is a trending video $index',
          videoUrl: 'https://example.com/trending_video$index.mp4',
          thumbnailUrl: 'https://picsum.photos/400/300?random=$index',
          duration: 120 + (index * 30),
          viewCount: 10000 + (index * 5000),
          likeCount: 500 + (index * 100),
          commentCount: 50 + (index * 10),
          shareCount: 25 + (index * 5),
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

  // Get user videos
  Future<List<VideoModel>> getUserVideos(String userId) async {
    try {
      // Mock implementation
      return List.generate(10, (index) {
        return VideoModel(
          id: 'user_video_$index',
          userId: userId,
          title: 'User Video $index',
          description: 'This is user video $index',
          videoUrl: 'https://example.com/user_video$index.mp4',
          thumbnailUrl: 'https://picsum.photos/400/300?random=$index',
          duration: 60 + (index * 30),
          viewCount: 1000 + (index * 100),
          likeCount: 50 + (index * 10),
          commentCount: 5 + index,
          shareCount: 2 + index,
          isPublic: true,
          isFeatured: false,
          createdAt: DateTime.now().subtract(Duration(days: index)),
          tags: ['user', 'personal'],
          category: 'general',
        );
      });
    } catch (e) {
      print('Error getting user videos: $e');
      return [];
    }
  }

  // Delete video
  Future<bool> deleteVideo(String videoId) async {
    try {
      // Mock implementation
      await Future.delayed(const Duration(seconds: 1));
      return true;
    } catch (e) {
      print('Error deleting video: $e');
      return false;
    }
  }

  // Update video
  Future<VideoModel?> updateVideo({
    required String videoId,
    String? title,
    String? description,
    List<String>? tags,
    String? category,
    bool? isPublic,
  }) async {
    try {
      // Mock implementation
      await Future.delayed(const Duration(seconds: 1));
      return VideoModel(
        id: videoId,
        userId: 'current_user',
        title: title ?? 'Updated Video',
        description: description,
        videoUrl: 'https://example.com/video.mp4',
        thumbnailUrl: 'https://picsum.photos/400/300?random=1',
        duration: 120,
        viewCount: 1000,
        likeCount: 50,
        commentCount: 10,
        shareCount: 5,
        isPublic: isPublic ?? true,
        isFeatured: false,
        createdAt: DateTime.now(),
        tags: tags ?? [],
        category: category ?? 'general',
      );
    } catch (e) {
      print('Error updating video: $e');
      return null;
    }
  }
}

// Provider
final videoServiceProvider = Provider<VideoService>((ref) {
  return VideoService();
});

// Video list provider
final videoListProvider = FutureProvider<List<VideoModel>>((ref) async {
  final videoService = ref.watch(videoServiceProvider);
  return await videoService.getVideos();
});

// Trending videos provider
final trendingVideosProvider = FutureProvider<List<VideoModel>>((ref) async {
  final videoService = ref.watch(videoServiceProvider);
  return await videoService.getTrendingVideos();
});

// Video upload state
class VideoUploadState {
  final bool isUploading;
  final double progress;
  final String? error;
  final VideoModel? uploadedVideo;

  const VideoUploadState({
    this.isUploading = false,
    this.progress = 0.0,
    this.error,
    this.uploadedVideo,
  });

  VideoUploadState copyWith({
    bool? isUploading,
    double? progress,
    String? error,
    VideoModel? uploadedVideo,
  }) {
    return VideoUploadState(
      isUploading: isUploading ?? this.isUploading,
      progress: progress ?? this.progress,
      error: error ?? this.error,
      uploadedVideo: uploadedVideo ?? this.uploadedVideo,
    );
  }
}

// Video upload state notifier
class VideoUploadNotifier extends StateNotifier<VideoUploadState> {
  VideoUploadNotifier() : super(const VideoUploadState());

  Future<void> uploadVideo({
    required File videoFile,
    required String title,
    String? description,
    String? thumbnailPath,
    List<String>? tags,
    String? category,
  }) async {
    state = state.copyWith(isUploading: true, progress: 0.0, error: null);

    try {
      final videoService = VideoService();

      // Simulate progress
      for (int i = 0; i <= 100; i += 10) {
        await Future.delayed(const Duration(milliseconds: 200));
        state = state.copyWith(progress: i / 100);
      }

      final uploadedVideo = await videoService.uploadVideo(
        videoFile: videoFile,
        title: title,
        description: description,
        thumbnailPath: thumbnailPath,
        tags: tags,
        category: category,
      );

      if (uploadedVideo != null) {
        state = state.copyWith(
          isUploading: false,
          progress: 1.0,
          uploadedVideo: uploadedVideo,
        );
      } else {
        state = state.copyWith(
          isUploading: false,
          error: 'Failed to upload video',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isUploading: false,
        error: e.toString(),
      );
    }
  }

  void reset() {
    state = const VideoUploadState();
  }
}

// Video upload state provider
final videoUploadStateProvider =
    StateNotifierProvider<VideoUploadNotifier, VideoUploadState>((ref) {
  return VideoUploadNotifier();
});

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
    File? thumbnailFile,
    List<String>? tags,
    String? category,
  }) async {
    try {
      final response = await _apiService.uploadVideo(
        videoFile: videoFile,
        thumbnailFile: thumbnailFile,
        title: title,
        description: description,
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

  // Get single video by ID
  Future<VideoModel?> getVideoById(String videoId) async {
    try {
      final response = await _apiService.getVideoById(videoId);

      if (response['success'] == true && response['data'] != null) {
        return VideoModel.fromJson(response['data'] as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error getting video by ID: $e');
      print('Error details: ${e.toString()}');
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
          return VideoModel.fromJson(videoData as Map<String, dynamic>);
        }).toList();
      }
      return [];
    } catch (e) {
      print('Error getting videos: $e');
      print('Error details: ${e.toString()}');
      return [];
    }
  }

  // Get trending videos
  Future<List<VideoModel>> getTrendingVideos({
    int limit = 10,
    String? category,
  }) async {
    try {
      final response = await _apiService.getVideos(
        page: 1,
        limit: limit,
        category: category,
      );

      if (response['success'] == true && response['data'] != null) {
        final videosData = response['data'] as List;
        return videosData.map((videoData) {
          return VideoModel.fromJson(videoData as Map<String, dynamic>);
        }).toList();
      }
      return [];
    } catch (e) {
      print('Error getting trending videos: $e');
      return [];
    }
  }

  // Get user videos
  Future<List<VideoModel>> getUserVideos(String userId) async {
    try {
      final response = await _apiService.getUserVideos(userId);

      if (response['success'] == true && response['data'] != null) {
        final videosData = response['data'] as List;
        return videosData.map((videoData) {
          return VideoModel(
            id: videoData['id'] ?? 'unknown',
            userId: videoData['userId'] ?? userId,
            title: videoData['title'] ?? 'Untitled',
            description: videoData['description'],
            videoUrl: videoData['videoUrl'] ?? '',
            thumbnailUrl: videoData['thumbnailUrl'],
            duration: videoData['duration'],
            viewCount: videoData['views'] ?? 0,
            likeCount: videoData['likes'] ?? 0,
            commentCount: videoData['comments'] ?? 0,
            shareCount: videoData['shares'] ?? 0,
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
      print('Error getting user videos: $e');
      return [];
    }
  }

  // Delete video
  Future<bool> deleteVideo(String videoId) async {
    try {
      final response = await _apiService.deleteVideo(videoId);
      return response['success'] == true;
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
      final response = await _apiService.updateVideo(
        videoId: videoId,
        title: title,
        description: description,
        tags: tags,
        category: category,
        isPublic: isPublic,
      );

      if (response['success'] == true && response['data'] != null) {
        final videoData = response['data'];
        return VideoModel(
          id: videoData['id'] ?? videoId,
          userId: videoData['userId'] ?? 'unknown',
          title: videoData['title'] ?? title ?? 'Updated Video',
          description: videoData['description'] ?? description,
          videoUrl: videoData['videoUrl'] ?? '',
          thumbnailUrl: videoData['thumbnailUrl'],
          duration: videoData['duration'],
          viewCount: videoData['viewCount'] ?? 0,
          likeCount: videoData['likeCount'] ?? 0,
          commentCount: videoData['commentCount'] ?? 0,
          shareCount: videoData['shareCount'] ?? 0,
          isPublic: videoData['isPublic'] ?? isPublic ?? true,
          isFeatured: videoData['isFeatured'] ?? false,
          createdAt: DateTime.parse(
              videoData['createdAt'] ?? DateTime.now().toIso8601String()),
          tags: List<String>.from(videoData['tags'] ?? tags ?? []),
          category: videoData['category'] ?? category ?? 'general',
        );
      }
      return null;
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
    File? thumbnailFile,
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
        thumbnailFile: thumbnailFile,
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

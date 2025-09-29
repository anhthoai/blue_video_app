import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../models/video_model.dart';
import '../../models/user_model.dart';

class VideoService {
  final ImagePicker _imagePicker = ImagePicker();

  // Get video player controller
  VideoPlayerController? getVideoPlayerController(String videoUrl) {
    try {
      return VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    } catch (e) {
      print('Error creating video player controller: $e');
      return null;
    }
  }

  // Pick video from gallery
  Future<File?> pickVideoFromGallery() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 10),
      );
      if (video != null) {
        return File(video.path);
      }
      return null;
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
      if (video != null) {
        return File(video.path);
      }
      return null;
    } catch (e) {
      print('Error recording video: $e');
      return null;
    }
  }

  // Pick video thumbnail
  Future<File?> pickVideoThumbnail() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('Error picking thumbnail: $e');
      return null;
    }
  }

  // Generate video thumbnail from video file
  Future<String?> generateVideoThumbnail(String videoPath) async {
    try {
      // This would typically use ffmpeg or similar to extract a frame
      // For now, we'll return a placeholder
      return 'https://picsum.photos/400/225?random=${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      print('Error generating thumbnail: $e');
      return null;
    }
  }

  // Upload video file
  Future<String?> uploadVideo(
    File videoFile, {
    required String title,
    String? description,
    List<String>? tags,
    String? category,
  }) async {
    try {
      // This would typically upload to a cloud storage service
      // For now, we'll return a mock URL
      await Future.delayed(const Duration(seconds: 2)); // Simulate upload
      return 'https://example.com/videos/${DateTime.now().millisecondsSinceEpoch}.mp4';
    } catch (e) {
      print('Error uploading video: $e');
      return null;
    }
  }

  // Get video duration
  Future<Duration?> getVideoDuration(String videoPath) async {
    try {
      final controller = VideoPlayerController.file(File(videoPath));
      await controller.initialize();
      final duration = controller.value.duration;
      await controller.dispose();
      return duration;
    } catch (e) {
      print('Error getting video duration: $e');
      return null;
    }
  }

  // Compress video
  Future<File?> compressVideo(File videoFile) async {
    try {
      // This would typically use ffmpeg or similar for compression
      // For now, we'll return the original file
      return videoFile;
    } catch (e) {
      print('Error compressing video: $e');
      return null;
    }
  }

  // Get video metadata
  Future<Map<String, dynamic>?> getVideoMetadata(String videoPath) async {
    try {
      final controller = VideoPlayerController.file(File(videoPath));
      await controller.initialize();

      final metadata = {
        'duration': controller.value.duration.inSeconds,
        'width': controller.value.size.width,
        'height': controller.value.size.height,
        'aspectRatio': controller.value.aspectRatio,
      };

      await controller.dispose();
      return metadata;
    } catch (e) {
      print('Error getting video metadata: $e');
      return null;
    }
  }

  // Create video model
  VideoModel createVideoModel({
    required String id,
    required String userId,
    required String title,
    String? description,
    required String videoUrl,
    String? thumbnailUrl,
    int duration = 0,
    List<String>? tags,
    String? category,
    bool isPublic = true,
  }) {
    return VideoModel(
      id: id,
      userId: userId,
      title: title,
      description: description,
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      duration: duration,
      tags: tags,
      category: category,
      isPublic: isPublic,
      createdAt: DateTime.now(),
    );
  }

  // Get video quality options
  List<String> getVideoQualityOptions() {
    return ['360p', '720p', '1080p'];
  }

  // Get video quality URL (mock implementation)
  String getVideoQualityUrl(String baseUrl, String quality) {
    // This would typically return different URLs for different qualities
    return baseUrl;
  }
}

// Provider
final videoServiceProvider = Provider<VideoService>((ref) {
  return VideoService();
});

// Video upload state provider
final videoUploadStateProvider =
    StateNotifierProvider<VideoUploadNotifier, VideoUploadState>((ref) {
  return VideoUploadNotifier();
});

// Video upload state
class VideoUploadState {
  final bool isUploading;
  final double progress;
  final String? error;
  final String? videoId;

  const VideoUploadState({
    this.isUploading = false,
    this.progress = 0.0,
    this.error,
    this.videoId,
  });

  VideoUploadState copyWith({
    bool? isUploading,
    double? progress,
    String? error,
    String? videoId,
  }) {
    return VideoUploadState(
      isUploading: isUploading ?? this.isUploading,
      progress: progress ?? this.progress,
      error: error ?? this.error,
      videoId: videoId ?? this.videoId,
    );
  }
}

// Video upload notifier
class VideoUploadNotifier extends StateNotifier<VideoUploadState> {
  VideoUploadNotifier() : super(const VideoUploadState());

  Future<void> uploadVideo(
    File videoFile, {
    required String title,
    String? description,
    List<String>? tags,
    String? category,
  }) async {
    state = state.copyWith(isUploading: true, progress: 0.0, error: null);

    try {
      // Simulate upload progress
      for (int i = 0; i <= 100; i += 10) {
        await Future.delayed(const Duration(milliseconds: 200));
        state = state.copyWith(progress: i / 100);
      }

      // Simulate successful upload
      final videoId = 'video_${DateTime.now().millisecondsSinceEpoch}';
      state = state.copyWith(
        isUploading: false,
        progress: 1.0,
        videoId: videoId,
      );
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

import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Utility class for video operations using FFmpeg Kit
class VideoUtils {
  /// Extract video duration using FFprobe
  /// Returns duration in seconds
  static Future<int?> getVideoDuration(File videoFile) async {
    try {
      final session = await FFprobeKit.getMediaInformation(videoFile.path);
      final information = await session.getMediaInformation();

      if (information != null) {
        final properties = information.getAllProperties();
        if (properties != null && properties['format'] != null) {
          final format = properties['format'] as Map;
          final durationStr = format['duration'] as String?;
          if (durationStr != null) {
            final duration = double.tryParse(durationStr);
            if (duration != null) {
              return duration.round();
            }
          }
        }
      }
      return null;
    } catch (e) {
      print('Error getting video duration: $e');
      return null;
    }
  }

  /// Extract video metadata (duration, resolution, codec, etc.)
  static Future<Map<String, dynamic>?> getVideoMetadata(File videoFile) async {
    try {
      final session = await FFprobeKit.getMediaInformation(videoFile.path);
      final information = await session.getMediaInformation();

      if (information != null) {
        final properties = information.getAllProperties();
        if (properties != null) {
          final format = properties['format'] as Map?;
          final streams = properties['streams'] as List?;

          // Find video stream
          Map? videoStream;
          if (streams != null) {
            videoStream = streams.firstWhere(
              (stream) => stream['codec_type'] == 'video',
              orElse: () => null,
            );
          }

          return {
            'duration': format?['duration'] != null
                ? double.tryParse(format!['duration'].toString())?.round()
                : null,
            'width': videoStream?['width'],
            'height': videoStream?['height'],
            'codec': videoStream?['codec_name'],
            'fps': videoStream?['r_frame_rate'],
            'bitrate': format?['bit_rate'],
            'size': format?['size'],
          };
        }
      }
      return null;
    } catch (e) {
      print('Error getting video metadata: $e');
      return null;
    }
  }

  /// Generate thumbnail from video at specific timestamp
  /// Optimized to 640px width for faster loading
  /// Returns the path to the generated thumbnail
  static Future<String?> generateThumbnail(
    File videoFile,
    int timeInSeconds, {
    String? outputPath,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final thumbnailPath = outputPath ??
          path.join(tempDir.path,
              'thumbnail_${DateTime.now().millisecondsSinceEpoch}.jpg');

      // Generate thumbnail with 640px width for faster loading
      // -vf scale=640:-1 resizes to 640px width, maintains aspect ratio
      final command =
          '-i "${videoFile.path}" -ss $timeInSeconds -vframes 1 -vf scale=640:-1 -q:v 2 "$thumbnailPath"';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (returnCode != null && returnCode.getValue() == 0) {
        return thumbnailPath;
      }
      return null;
    } catch (e) {
      print('Error generating thumbnail: $e');
      return null;
    }
  }

  /// Generate multiple thumbnails from video
  /// Returns list of thumbnail paths
  static Future<List<String>> generateThumbnails(
    File videoFile,
    int count, {
    String? outputDir,
  }) async {
    try {
      // Get video duration first
      final duration = await getVideoDuration(videoFile);
      if (duration == null || duration <= 0) {
        print('⚠️  Invalid video duration: $duration');
        return [];
      }

      final tempDir = await getTemporaryDirectory();
      final outputDirectory = outputDir ?? tempDir.path;

      final thumbnails = <String>[];
      final baseTimestamp = DateTime.now().millisecondsSinceEpoch;

      print('🖼️  Generating $count thumbnails from ${duration}s video...');

      // Generate thumbnails at evenly distributed timestamps
      for (int i = 0; i < count; i++) {
        // Skip first 5% and last 5% to avoid black frames
        final position = 0.05 + (i / (count - 1)) * 0.9;
        final timestamp = (duration * position).round();

        // Use unique timestamp for each thumbnail
        final thumbnailPath = path.join(
          outputDirectory,
          'thumbnail_${i + 1}_${baseTimestamp + i}.jpg',
        );

        print('   Generating thumbnail ${i + 1}/$count at ${timestamp}s...');

        final thumbnail = await generateThumbnail(
          videoFile,
          timestamp,
          outputPath: thumbnailPath,
        );

        if (thumbnail != null) {
          // Verify file exists before adding
          final file = File(thumbnail);
          if (await file.exists()) {
            thumbnails.add(thumbnail);
            print('   ✅ Thumbnail ${i + 1} saved: $thumbnail');
          } else {
            print('   ⚠️  Thumbnail file not found: $thumbnail');
          }
        } else {
          print('   ❌ Failed to generate thumbnail ${i + 1}');
        }
      }

      print('✅ Generated ${thumbnails.length}/$count thumbnails successfully');
      return thumbnails;
    } catch (e) {
      print('❌ Error generating thumbnails: $e');
      return [];
    }
  }

  /// Format duration from seconds to readable string (MM:SS or HH:MM:SS)
  static String formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
  }

  /// Get video file size in MB
  static Future<double> getVideoSizeMB(File videoFile) async {
    try {
      final fileSize = await videoFile.length();
      return fileSize / (1024 * 1024);
    } catch (e) {
      print('Error getting video size: $e');
      return 0;
    }
  }
}

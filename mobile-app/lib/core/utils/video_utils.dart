import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class VideoUtils {
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

  static Future<Map<String, dynamic>?> getVideoMetadata(File videoFile) async {
    try {
      final session = await FFprobeKit.getMediaInformation(videoFile.path);
      final information = await session.getMediaInformation();

      if (information != null) {
        final properties = information.getAllProperties();
        if (properties != null) {
          final format = properties['format'] as Map?;
          final streams = properties['streams'] as List?;

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

  static Future<String> generateThumbnail(
    File videoFile,
    int timeInSeconds, {
    String? outputPath,
  }) async {
    try {
      if (!await videoFile.exists()) {
        throw Exception('Video file does not exist: ${videoFile.path}');
      }

      final tempDir = await getTemporaryDirectory();
      final thumbnailPath = outputPath ??
          path.join(
            tempDir.path,
            'thumbnail_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );

      final thumbnailFile = File(thumbnailPath);
      if (await thumbnailFile.exists()) {
        print('Deleting existing thumbnail: $thumbnailPath');
        await thumbnailFile.delete();
      }

      print('Generating thumbnail...');
      print('  Video: ${videoFile.path}');
      print('  Output: $thumbnailPath');
      print('  Time: ${timeInSeconds}s');

      var command =
          '-y -ss $timeInSeconds -i ${videoFile.path} -vframes 1 -vf scale=640:-1 -q:v 5 $thumbnailPath';

      print('FFmpeg command (with scale): $command');

      var session = await FFmpegKit.execute(command);
      var returnCode = await session.getReturnCode();

      print('FFmpeg return code: ${returnCode?.getValue()}');

      if (returnCode == null || returnCode.getValue() != 0) {
        print('Scaling failed, trying without scale filter...');

        command =
            '-y -ss $timeInSeconds -i ${videoFile.path} -vframes 1 $thumbnailPath';
        print('FFmpeg command (no scale): $command');

        session = await FFmpegKit.execute(command);
        returnCode = await session.getReturnCode();
        print('FFmpeg return code (retry): ${returnCode?.getValue()}');
      }

      if (returnCode != null && returnCode.getValue() == 0) {
        if (await thumbnailFile.exists()) {
          final fileSize = await thumbnailFile.length();
          print('Thumbnail created successfully (${fileSize} bytes)');
          return thumbnailPath;
        }

        throw Exception('Thumbnail file was not created at: $thumbnailPath');
      }

      print('FFmpeg failed on both attempts');
      final logs = await session.getAllLogsAsString();
      if (logs != null && logs.isNotEmpty) {
        final relevantLogs =
            logs.length > 1000 ? logs.substring(logs.length - 1000) : logs;
        print('FFmpeg error logs:\n$relevantLogs');
      }

      throw Exception(
        'FFmpeg failed with return code: ${returnCode?.getValue()}',
      );
    } catch (e) {
      print('Error generating thumbnail: $e');
      rethrow;
    }
  }

  static Future<List<String>> generateThumbnails(
    File videoFile,
    int count, {
    String? outputDir,
  }) async {
    try {
      final duration = await getVideoDuration(videoFile);
      if (duration == null || duration <= 0 || count <= 0) {
        print('Invalid thumbnail generation input: duration=$duration, count=$count');
        return [];
      }

      final tempDir = await getTemporaryDirectory();
      final outputDirectory = outputDir ?? tempDir.path;
      final thumbnails = <String>[];
      final baseTimestamp = DateTime.now().millisecondsSinceEpoch;

      print('Generating $count thumbnails from ${duration}s video...');
      print('Using parallel generation for faster processing...');

      final thumbnailTasks = <Future<String?>>[];

      for (int index = 0; index < count; index++) {
        final position = count == 1 ? 0.5 : 0.05 + (index / (count - 1)) * 0.9;
        final timestamp = (duration * position).round();
        final thumbnailPath = path.join(
          outputDirectory,
          'thumbnail_${index + 1}_${baseTimestamp + index}.jpg',
        );

        print('  Queuing thumbnail ${index + 1}/$count at ${timestamp}s...');
        thumbnailTasks.add(
          generateThumbnail(
            videoFile,
            timestamp,
            outputPath: thumbnailPath,
          ),
        );
      }

      print('Starting parallel thumbnail generation...');
      final results = await Future.wait(thumbnailTasks);

      for (int index = 0; index < results.length; index++) {
        final thumbnail = results[index];
        if (thumbnail != null) {
          final file = File(thumbnail);
          if (await file.exists()) {
            thumbnails.add(thumbnail);
            print('  Thumbnail ${index + 1} saved');
          } else {
            print('  Thumbnail ${index + 1} file not found');
          }
        } else {
          print('  Failed to generate thumbnail ${index + 1}');
        }
      }

      print(
        'Generated ${thumbnails.length}/$count thumbnails successfully (parallel)',
      );
      return thumbnails;
    } catch (e) {
      print('Error generating thumbnails: $e');
      return [];
    }
  }

  static String formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  static Future<double> getVideoSizeMB(File videoFile) async {
    try {
      final fileSize = await videoFile.length();
      return fileSize / (1024 * 1024);
    } catch (e) {
      print('Error getting video size: $e');
      return 0;
    }
  }

  static Future<Map<String, String>> extractSubtitles(
    File videoFile, {
    String? outputDir,
  }) async {
    try {
      print('Extracting subtitles from: ${videoFile.path}');

      final tempDir = await getTemporaryDirectory();
      final outputDirectory = outputDir ?? tempDir.path;
      final Map<String, String> subtitles = {};

      final probeCommand = '-i "${videoFile.path}" -hide_banner';
      final probeSession = await FFprobeKit.execute(probeCommand);
      final output = await probeSession.getOutput();

      if (output == null) {
        print('No FFprobe output');
        return subtitles;
      }

      print('FFprobe output:\n$output');

      final streamPattern = RegExp(
        r'Stream #0:(\d+)\(([a-z]{2,3})\): Subtitle:',
        caseSensitive: false,
      );

      final matches = streamPattern.allMatches(output);

      if (matches.isEmpty) {
        print('No embedded subtitles found');
        return subtitles;
      }

      print('Found ${matches.length} subtitle stream(s)');

      for (final match in matches) {
        final streamIndex = match.group(1);
        final langCode = match.group(2)?.toLowerCase();

        if (streamIndex == null || langCode == null) {
          continue;
        }

        print(
          'Extracting subtitle stream $streamIndex (language: $langCode)',
        );

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final outputPath = path.join(
          outputDirectory,
          'subtitle_${langCode}_$timestamp.srt',
        );

        final extractCommand =
            '-i "${videoFile.path}" -map 0:$streamIndex -c:s srt "$outputPath"';
        final extractSession = await FFmpegKit.execute(extractCommand);
        final returnCode = await extractSession.getReturnCode();

        if (returnCode != null && returnCode.getValue() == 0) {
          final file = File(outputPath);
          if (await file.exists()) {
            subtitles[langCode] = outputPath;
            print('  Extracted: $langCode -> $outputPath');
          } else {
            print('  File not created: $outputPath');
          }
        } else {
          print('  Failed to extract subtitle stream $streamIndex');
        }
      }

      print('Successfully extracted ${subtitles.length} subtitle(s)');
      return subtitles;
    } catch (e) {
      print('Error extracting subtitles: $e');
      return {};
    }
  }
}

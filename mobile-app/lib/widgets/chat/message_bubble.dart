import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../models/chat_message.dart';
import '../../core/services/file_url_service.dart';
import '../common/presigned_image.dart';

class MessageBubble extends StatefulWidget {
  final ChatMessage message;
  final bool isMe;
  final VoidCallback? onReply;
  final VoidCallback? onLongPress;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onReply,
    this.onLongPress,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    if (widget.message.messageType == MessageType.audio) {
      _initAudioPlayer();
    }
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
  }

  void _initAudioPlayer() {
    _audioPlayer = AudioPlayer();
    _audioPlayer!.onDurationChanged.listen((duration) {
      setState(() {
        _duration = duration;
      });
    });
    _audioPlayer!.onPositionChanged.listen((position) {
      setState(() {
        _position = position;
      });
    });
    _audioPlayer!.onPlayerStateChanged.listen((state) {
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final isMe = widget.isMe;

    return GestureDetector(
      onLongPress: () => widget.onLongPress?.call(),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
              SizedBox(
                width: 32,
                height: 32,
                child: message.userAvatar != null &&
                        message.userAvatar!.isNotEmpty
                    ? ClipOval(
                        child: PresignedImage(
                          imageUrl: message.userAvatar,
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                          placeholder: Container(
                            color: Colors.grey[300],
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: Container(
                            color: Colors.grey[300],
                            child: Center(
                              child: Text(
                                message.username.isNotEmpty
                                    ? message.username[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                      )
                    : CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.grey[300],
                        child: Text(
                          message.username.isNotEmpty
                              ? message.username[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isMe
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[200],
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: isMe
                        ? const Radius.circular(20)
                        : const Radius.circular(4),
                    bottomRight: isMe
                        ? const Radius.circular(4)
                        : const Radius.circular(20),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.replyToMessageId != null)
                      _buildReplyPreview(context),
                    _buildMessageContent(context),
                    const SizedBox(height: 4),
                    _buildMessageFooter(context),
                  ],
                ),
              ),
            ),
            if (isMe) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 32,
                height: 32,
                child: message.userAvatar != null &&
                        message.userAvatar!.isNotEmpty
                    ? ClipOval(
                        child: PresignedImage(
                          imageUrl: message.userAvatar,
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                          placeholder: Container(
                            color: Colors.grey[300],
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: Container(
                            color: Colors.grey[300],
                            child: Center(
                              child: Text(
                                message.username.isNotEmpty
                                    ? message.username[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                      )
                    : CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.grey[300],
                        child: Text(
                          message.username.isNotEmpty
                              ? message.username[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReplyPreview(BuildContext context) {
    final isMe = widget.isMe;
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withOpacity(0.2) : Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isMe ? Colors.white : Colors.grey[400]!,
            width: 3,
          ),
        ),
      ),
      child: const Text(
        'Replying to: This is a sample reply message',
        style: TextStyle(
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    final message = widget.message;
    final isMe = widget.isMe;

    switch (message.messageType) {
      case MessageType.text:
        return Text(
          message.content,
          style: TextStyle(
            color: isMe ? Colors.white : Colors.black87,
            fontSize: 16,
          ),
        );
      case MessageType.image:
        return _buildImageMessage(context);
      case MessageType.video:
        return _buildVideoMessage(context);
      case MessageType.audio:
        return _buildAudioMessage(context);
      case MessageType.file:
        return _buildFileMessage(context);
      case MessageType.location:
        return _buildLocationMessage(context);
      case MessageType.sticker:
        return _buildStickerMessage(context);
      case MessageType.system:
        return _buildSystemMessage(context);
    }
  }

  Widget _buildImageMessage(BuildContext context) {
    final message = widget.message;
    final isMe = widget.isMe;

    if (message.fileUrl == null || message.fileUrl!.isEmpty) {
      return Text(
        message.content.isNotEmpty ? message.content : '📷 Image',
        style: TextStyle(
          color: isMe ? Colors.white : Colors.black87,
          fontSize: 16,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () =>
              _openImageViewer(context, message.fileUrl!, message.content),
          child: PresignedImage(
            imageUrl: message.fileUrl,
            width: 200,
            height: 200,
            fit: BoxFit.cover,
            borderRadius: BorderRadius.circular(8),
            placeholder: Container(
              width: 200,
              height: 200,
              color: Colors.grey[300],
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
            errorWidget: Container(
              width: 200,
              height: 200,
              color: Colors.grey[300],
              child: const Icon(Icons.broken_image, size: 48),
            ),
          ),
        ),
        if (message.content.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            message.content,
            style: TextStyle(
              color: isMe ? Colors.white : Colors.black87,
              fontSize: 14,
            ),
          ),
        ],
      ],
    );
  }

  void _openImageViewer(BuildContext context, String imageUrl, String caption) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Column(
            children: [
              Expanded(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: PresignedImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain,
                      placeholder: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                      errorWidget: const Icon(
                        Icons.broken_image,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
              if (caption.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.black87,
                  child: Text(
                    caption,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoMessage(BuildContext context) {
    final message = widget.message;
    final isMe = widget.isMe;

    if (message.fileUrl == null || message.fileUrl!.isEmpty) {
      return Text(
        message.content.isNotEmpty ? message.content : '🎥 Video',
        style: TextStyle(
          color: isMe ? Colors.white : Colors.black87,
          fontSize: 16,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _openVideoPlayer(context, message.fileUrl!),
          child: Container(
            width: 200,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              children: [
                // Video thumbnail placeholder
                Container(
                  width: 200,
                  height: 120,
                  color: Colors.grey[800],
                  child: const Center(
                    child: Icon(Icons.play_circle_outline,
                        color: Colors.white, size: 48),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.videocam, color: Colors.white, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'Video',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (message.content.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            message.content,
            style: TextStyle(
              color: isMe ? Colors.white : Colors.black87,
              fontSize: 14,
            ),
          ),
        ],
      ],
    );
  }

  void _openVideoPlayer(BuildContext context, String videoUrl) async {
    // Get presigned URL if needed
    final fileUrlService = FileUrlService();
    final accessibleUrl = await fileUrlService.getAccessibleUrl(videoUrl);

    if (accessibleUrl != null && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => _ChatVideoPlayer(videoUrl: accessibleUrl),
        ),
      );
    }
  }

  Widget _buildAudioMessage(BuildContext context) {
    final message = widget.message;
    final isMe = widget.isMe;

    if (message.fileUrl == null || message.fileUrl!.isEmpty) {
      return Text(
        message.content.isNotEmpty ? message.content : '🎵 Audio',
        style: TextStyle(
          color: isMe ? Colors.white : Colors.black87,
          fontSize: 16,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 250,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isMe ? Colors.white.withOpacity(0.2) : Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: isMe ? Colors.white : Colors.black,
                ),
                onPressed: _toggleAudioPlayback,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: _duration.inMilliseconds > 0
                          ? _position.inMilliseconds / _duration.inMilliseconds
                          : 0.0,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isMe ? Colors.white : Colors.grey[600]!,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_position),
                          style: TextStyle(
                            color: isMe ? Colors.white70 : Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _duration.inMilliseconds > 0
                              ? _formatDuration(_duration)
                              : _formatFileSize(message.fileSize),
                          style: TextStyle(
                            color: isMe ? Colors.white70 : Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.audiotrack,
                color: isMe ? Colors.white70 : Colors.grey[600],
                size: 20,
              ),
            ],
          ),
        ),
        if (message.content.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            message.content,
            style: TextStyle(
              color: isMe ? Colors.white : Colors.black87,
              fontSize: 14,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _toggleAudioPlayback() async {
    if (_audioPlayer == null || widget.message.fileUrl == null) return;

    if (_isPlaying) {
      await _audioPlayer!.pause();
    } else {
      // Get presigned URL if needed
      final fileUrlService = FileUrlService();
      final accessibleUrl =
          await fileUrlService.getAccessibleUrl(widget.message.fileUrl);
      if (accessibleUrl != null) {
        await _audioPlayer!.play(UrlSource(accessibleUrl));
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Widget _buildFileMessage(BuildContext context) {
    final message = widget.message;
    final isMe = widget.isMe;

    if (message.fileUrl == null || message.fileUrl!.isEmpty) {
      return Text(
        message.content.isNotEmpty ? message.content : '📄 File',
        style: TextStyle(
          color: isMe ? Colors.white : Colors.black87,
          fontSize: 16,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () =>
              _downloadFile(message.fileUrl!, message.fileName ?? 'document'),
          child: Container(
            width: 250,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isMe ? Colors.white.withOpacity(0.2) : Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  _getFileIcon(message.mimeType),
                  color: isMe ? Colors.white : Colors.black,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.fileName ?? 'Document',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: isMe ? Colors.white : Colors.black87,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (_isDownloading &&
                          message.fileUrl == widget.message.fileUrl)
                        LinearProgressIndicator(
                          value: _downloadProgress,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isMe ? Colors.white : Colors.grey[600]!,
                          ),
                        )
                      else
                        Text(
                          _formatFileSize(message.fileSize),
                          style: TextStyle(
                            fontSize: 12,
                            color: isMe ? Colors.white70 : Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _isDownloading && message.fileUrl == widget.message.fileUrl
                      ? Icons.hourglass_empty
                      : Icons.download,
                  color: isMe ? Colors.white : Colors.black,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
        if (message.content.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            message.content,
            style: TextStyle(
              color: isMe ? Colors.white : Colors.black87,
              fontSize: 14,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _openFile(String filePath, String fileName) async {
    try {
      // Use open_file package which handles FileProvider automatically
      final result = await OpenFile.open(filePath);

      if (result.type != ResultType.done && mounted) {
        String message;
        switch (result.type) {
          case ResultType.noAppToOpen:
            message = 'No app found to open this file type';
            break;
          case ResultType.fileNotFound:
            message = 'File not found';
            break;
          case ResultType.permissionDenied:
            message = 'Permission denied to open file';
            break;
          default:
            message = result.message;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _downloadFile(String url, String fileName) async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      // Get presigned URL if needed
      final fileUrlService = FileUrlService();
      final accessibleUrl = await fileUrlService.getAccessibleUrl(url);

      if (accessibleUrl == null) {
        throw Exception('Could not get accessible URL for file');
      }

      // Request appropriate storage permission based on Android version
      if (Platform.isAndroid) {
        // For Android 13+ (API 33+), we don't need WRITE_EXTERNAL_STORAGE
        // For Android 10-12, we need WRITE_EXTERNAL_STORAGE
        // For Android 9 and below, we need WRITE_EXTERNAL_STORAGE
        PermissionStatus status;

        // Try to get permission status (will auto-grant on Android 13+)
        try {
          status = await Permission.storage.status;
          if (!status.isGranted && !status.isPermanentlyDenied) {
            status = await Permission.storage.request();
          }
        } catch (e) {
          // On Android 13+, storage permission doesn't exist, so we can proceed
          status = PermissionStatus.granted;
        }

        // If permanently denied, guide user to settings
        if (status.isPermanentlyDenied) {
          setState(() {
            _isDownloading = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                    'Storage permission required. Please enable it in settings.'),
                action: SnackBarAction(
                  label: 'Settings',
                  onPressed: () => openAppSettings(),
                ),
              ),
            );
          }
          return;
        }
      }

      // Get Downloads directory - use app-specific storage (no permission needed)
      Directory? directory;
      if (Platform.isAndroid) {
        // Use app-specific external storage (accessible via file manager)
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          // Create Downloads folder
          directory = Directory('${externalDir.path}/Downloads');
          if (!await directory.exists()) {
            await directory.create(recursive: true);
          }
        } else {
          directory = await getApplicationDocumentsDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        throw Exception('Could not access Downloads folder');
      }

      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);

      // Download the file using presigned URL
      final response = await http.get(Uri.parse(accessibleUrl));
      await file.writeAsBytes(response.bodyBytes);

      setState(() {
        _isDownloading = false;
        _downloadProgress = 1.0;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded: $fileName'),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () => _openFile(filePath, fileName),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _downloadProgress = 0.0;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }

  Widget _buildLocationMessage(BuildContext context) {
    return Container(
      width: 200,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          // Map preview would go here
          Container(
            width: 200,
            height: 120,
            color: Colors.grey[400],
            child: const Center(
              child: Icon(Icons.location_on, color: Colors.red, size: 32),
            ),
          ),
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Current Location',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickerMessage(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Text(
          '😀',
          style: TextStyle(fontSize: 48),
        ),
      ),
    );
  }

  Widget _buildSystemMessage(BuildContext context) {
    final message = widget.message;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message.content,
        style: const TextStyle(
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildMessageFooter(BuildContext context) {
    final message = widget.message;
    final isMe = widget.isMe;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message.shortTime,
          style: TextStyle(
            color: isMe ? Colors.white.withOpacity(0.7) : Colors.grey[600],
            fontSize: 12,
          ),
        ),
        if (isMe) ...[
          const SizedBox(width: 4),
          Icon(
            message.isRead ? Icons.done_all : Icons.done,
            size: 16,
            color: message.isRead ? Colors.blue : Colors.white.withOpacity(0.7),
          ),
        ],
        if (message.isEdited) ...[
          const SizedBox(width: 4),
          Text(
            'edited',
            style: TextStyle(
              color: isMe ? Colors.white.withOpacity(0.7) : Colors.grey[600],
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  // Helper method to format file size
  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes == 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  // Helper method to get file icon based on MIME type
  IconData _getFileIcon(String? mimeType) {
    if (mimeType == null) return Icons.insert_drive_file;

    if (mimeType.contains('pdf')) {
      return Icons.picture_as_pdf;
    } else if (mimeType.contains('word') || mimeType.contains('document')) {
      return Icons.description;
    } else if (mimeType.contains('sheet') || mimeType.contains('excel')) {
      return Icons.table_chart;
    } else if (mimeType.contains('presentation') ||
        mimeType.contains('powerpoint')) {
      return Icons.slideshow;
    } else if (mimeType.contains('text')) {
      return Icons.text_snippet;
    } else if (mimeType.contains('zip') || mimeType.contains('rar')) {
      return Icons.folder_zip;
    }

    return Icons.insert_drive_file;
  }
}

// Simple video player widget for chat videos
class _ChatVideoPlayer extends StatefulWidget {
  final String videoUrl;

  const _ChatVideoPlayer({required this.videoUrl});

  @override
  State<_ChatVideoPlayer> createState() => _ChatVideoPlayerState();
}

class _ChatVideoPlayerState extends State<_ChatVideoPlayer> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoPlayerController.dispose();
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    try {
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );

      await _videoPlayerController.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoPlayerController.value.aspectRatio,
        autoInitialize: true,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.white, size: 48),
                const SizedBox(height: 16),
                Text(
                  errorMessage,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      );

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Video', style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: _isLoading
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Loading video...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              )
            : _errorMessage != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, color: Colors.white, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'Failed to load video',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  )
                : _chewieController != null
                    ? Chewie(controller: _chewieController!)
                    : const SizedBox(),
      ),
    );
  }
}

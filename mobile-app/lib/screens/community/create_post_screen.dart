import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../core/services/api_service.dart';
import '../../core/services/community_service.dart';
import '../../core/utils/video_utils.dart';
import '../../l10n/app_localizations.dart';
import '../../models/community_post.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  final _tagsController = TextEditingController();

  // Audience settings
  final _costController = TextEditingController(text: '0');
  bool _isPublic = true;
  bool _requiresVip = false;

  // Post settings
  bool _allowComments = true;
  bool _allowCommentLinks = false;
  bool _isPinned = false;
  bool _isNsfw = false;

  // Who can reply
  String _replyRestriction = 'FOLLOWERS';

  bool _isLoading = false;

  // Media
  List<File> _selectedImages = [];
  List<File> _selectedVideos = [];
  List<int?> _videoDurations = []; // Duration for each video in seconds
  List<File?> _videoThumbnails = []; // Thumbnail file for each video
  bool _isProcessingVideos = false;

  final ApiService _apiService = ApiService();

  @override
  void dispose() {
    _contentController.dispose();
    _tagsController.dispose();
    _costController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
  }

  Future<void> _pickMedia() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.media,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _isProcessingVideos = true;
        });

        for (var file in result.files) {
          if (file.path != null) {
            final File mediaFile = File(file.path!);
            final String extension = file.extension?.toLowerCase() ?? '';

            if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension)) {
              _selectedImages.add(mediaFile);
            } else if (['mp4', 'mkv', 'mov', 'avi', 'webm']
                .contains(extension)) {
              _selectedVideos.add(mediaFile);
              _videoDurations.add(null); // Placeholder for duration
              _videoThumbnails.add(null); // Placeholder for thumbnail
            }
          }
        }

        // Process videos to extract duration and generate thumbnails
        await _processVideos();

        setState(() {
          _isProcessingVideos = false;
        });
      }
    } catch (e) {
      print('Error picking media: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting media: $e')),
        );
      }
      setState(() {
        _isProcessingVideos = false;
      });
    }
  }

  Future<void> _processVideos() async {
    if (_selectedVideos.isEmpty) return;

    try {
      print('🎬 Processing ${_selectedVideos.length} videos...');

      for (int i = 0; i < _selectedVideos.length; i++) {
        final videoFile = _selectedVideos[i];

        try {
          print('📹 Processing video ${i + 1}/${_selectedVideos.length}');
          print('   Path: ${videoFile.path}');
          print('   Size: ${await videoFile.length()} bytes');

          // Extract duration
          print('⏱️  Extracting duration...');
          final duration = await VideoUtils.getVideoDuration(videoFile);
          _videoDurations[i] = duration;
          print('   Duration: ${duration}s');

          // Generate thumbnail with same name as video but .jpg extension
          try {
            print('🖼️  Generating thumbnail...');
            final videoBaseName = path.basenameWithoutExtension(videoFile.path);
            final tempDir = await getTemporaryDirectory();
            final thumbnailPath =
                path.join(tempDir.path, '${videoBaseName}.jpg');

            print('   Thumbnail path: $thumbnailPath');

            // Try generating at 5 seconds, if video is shorter try at 1 second, then 0
            int seekTime = 5;
            if (duration != null && duration < 5) {
              seekTime = duration > 1 ? 1 : 0;
            }
            print('   Seeking to: ${seekTime}s');

            final generatedPath = await VideoUtils.generateThumbnail(
              videoFile,
              seekTime,
              outputPath: thumbnailPath,
            );

            _videoThumbnails[i] = File(generatedPath);
            print(
                '✅ Processed video ${i + 1}/${_selectedVideos.length}: duration=${duration}s, thumbnail generated');
          } catch (e) {
            print('❌ Error generating thumbnail for video ${i + 1}: $e');
            print('   Continuing without thumbnail...');
            _videoThumbnails[i] = null;
          }
        } catch (e) {
          print('❌ Error processing video ${i + 1}: $e');
          _videoDurations[i] = 0;
          _videoThumbnails[i] = null;
        }
      }

      print('🎬 Video processing completed');
      print(
          '   Videos with thumbnails: ${_videoThumbnails.where((t) => t != null).length}/${_selectedVideos.length}');
    } catch (e) {
      print('❌ Error processing videos: $e');
    }
  }

  Future<void> _createPost() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;

    if (_contentController.text.trim().isEmpty &&
        _selectedImages.isEmpty &&
        _selectedVideos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.createPostAddContentOrMedia)),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Parse cost
      final cost = int.tryParse(_costController.text) ?? 0;

      // Parse tags
      final tags = _tagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      // Prepare processed video data
      final validThumbnails =
          _videoThumbnails.where((t) => t != null).cast<File>().toList();
      final validDurations = _videoDurations
          .where((d) => d != null)
          .map((d) => d.toString())
          .toList();

      // Call API service to create post with file uploads
      final response = await _apiService.createCommunityPost(
        content: _contentController.text.trim().isNotEmpty
            ? _contentController.text.trim()
            : null,
        type: 'MEDIA', // Always MEDIA type for posts with text + media
        imageFiles: _selectedImages.isNotEmpty ? _selectedImages : null,
        videoFiles: _selectedVideos.isNotEmpty ? _selectedVideos : null,
        videoThumbnails: validThumbnails.isNotEmpty ? validThumbnails : null,
        videoDurations: validDurations.isNotEmpty ? validDurations : null,
        cost: cost,
        requiresVip: _requiresVip,
        allowComments: _allowComments,
        allowCommentLinks: _allowCommentLinks,
        isPinned: _isPinned,
        isNsfw: _isNsfw,
        replyRestriction: _replyRestriction,
        tags: tags,
      );

      if (response['success'] == true) {
        final createdPost = _buildCreatedPostFromResponse(response['data']);
        if (createdPost != null) {
          ref.read(communityServiceStateProvider.notifier).upsertPost(createdPost);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.createPostSuccess)),
          );
          // Pop with success result to trigger refresh
          context.pop(true);
        }
      } else {
        throw Exception(response['message'] ?? 'Failed to create post');
      }
    } catch (e) {
      print('Error creating post: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.createPostError}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  CommunityPost? _buildCreatedPostFromResponse(dynamic rawPost) {
    if (rawPost is! Map) {
      return null;
    }

    final post = Map<String, dynamic>.from(rawPost);
    return CommunityPost.fromJson({
      ...post,
      'content': post['content'] ?? '',
      'userAvatar': post['userAvatar'] ?? '',
      'imageUrls': post['imageUrls'] ?? const [],
      'videoUrls': post['videoUrls'] ?? const [],
      'videoThumbnailUrls': post['videoThumbnailUrls'] ?? const [],
      'pollData': post['pollData'] ?? post['pollOptions'],
      'createdAt': post['createdAt'] ?? DateTime.now().toIso8601String(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.createPost),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createPost,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.createPost),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // What's on your mind? (Content)
                    TextFormField(
                      controller: _contentController,
                      maxLines: 5,
                      maxLength: 500,
                      decoration: InputDecoration(
                        hintText: l10n.whatsOnYourMind,
                        border: OutlineInputBorder(),
                        counterText: '', // Hide counter for now
                      ),
                      enabled: !_isLoading,
                    ),

                    // Media Selection
                    const SizedBox(height: 16),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.photo_library),
                        title: Text(l10n.createPostAddMedia),
                        subtitle: Text(
                          '${_selectedImages.length} ${l10n.imagesLabel}, ${_selectedVideos.length} ${l10n.videosLabel} ${l10n.createPostSelectedSummary}',
                        ),
                        trailing: const Icon(Icons.add),
                        onTap: _isLoading ? null : _pickMedia,
                      ),
                    ),

                    // Show video processing indicator
                    if (_isProcessingVideos) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Text(l10n.createPostProcessingVideos),
                          ],
                        ),
                      ),
                    ],

                    // Show selected media preview
                    if (_selectedImages.isNotEmpty ||
                        _selectedVideos.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildMediaPreview(),
                    ],

                    const SizedBox(height: 16),

                    // Audience Settings
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.createPostAudience,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),

                            // Cost
                            TextFormField(
                              controller: _costController,
                              decoration: InputDecoration(
                                labelText: l10n.costCoins,
                                hintText: '0',
                                border: OutlineInputBorder(),
                                helperText: l10n.createPostFreePostHint,
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value != null && value.isNotEmpty) {
                                  final cost = int.tryParse(value);
                                  if (cost == null || cost < 0) {
                                    return l10n.createPostValidCost;
                                  }
                                }
                                return null;
                              },
                              enabled: !_isLoading,
                            ),

                            const SizedBox(height: 16),

                            // VIP Requirement
                            SwitchListTile(
                                title: Text(l10n.createPostVipOnly),
                                subtitle: Text(l10n.createPostVipOnlySubtitle),
                              value: _requiresVip,
                              onChanged: _isLoading
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _requiresVip = value;
                                      });
                                    },
                            ),

                            // Public/Private
                            SwitchListTile(
                              title: Text(l10n.makePublic),
                              subtitle: Text(
                                _isPublic
                                ? l10n.createPostMakePublicSubtitle
                                : l10n.createPostMakePrivateSubtitle,
                              ),
                              value: _isPublic,
                              onChanged: _isLoading
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _isPublic = value;
                                      });
                                    },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Post Settings
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.createPostSettings,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),

                            // Allow Comments
                            SwitchListTile(
                                title: Text(l10n.createPostAllowComments),
                                subtitle: Text(l10n.createPostAllowCommentsSubtitle),
                              value: _allowComments,
                              onChanged: _isLoading
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _allowComments = value;
                                      });
                                    },
                            ),

                            // Allow Comment Links
                            SwitchListTile(
                                title: Text(l10n.createPostAllowLinks),
                                subtitle: Text(l10n.createPostAllowLinksSubtitle),
                              value: _allowCommentLinks,
                              onChanged: _isLoading
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _allowCommentLinks = value;
                                      });
                                    },
                            ),

                            // Pin Post
                            SwitchListTile(
                              title: Text(l10n.createPostPinPost),
                              subtitle: Text(l10n.createPostPinPostSubtitle),
                              value: _isPinned,
                              onChanged: _isLoading
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _isPinned = value;
                                      });
                                    },
                            ),

                            // NSFW
                            SwitchListTile(
                              title: Text(l10n.createPostNsfw),
                              subtitle: Text(l10n.createPostNsfwSubtitle),
                              value: _isNsfw,
                              onChanged: _isLoading
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _isNsfw = value;
                                      });
                                    },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Who Can Reply
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.createPostWhoCanReply,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: _replyRestriction,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                              ),
                                items: [
                                DropdownMenuItem(
                                    value: 'FOLLOWERS',
                                  child: Text(l10n.createPostFollowers)),
                                DropdownMenuItem(
                                    value: 'PAID_VIEWERS',
                                  child: Text(l10n.createPostPaidViewers)),
                                DropdownMenuItem(
                                    value: 'FOLLOWING',
                                  child: Text(l10n.createPostPeopleYouFollow)),
                                DropdownMenuItem(
                                    value: 'VERIFIED_FOLLOWING',
                                  child: Text(l10n.createPostVerifiedFollowers)),
                                DropdownMenuItem(
                                  value: 'NO_ONE', child: Text(l10n.createPostNoOne)),
                              ],
                              onChanged: _isLoading
                                  ? null
                                  : (value) {
                                      if (value != null) {
                                        setState(() {
                                          _replyRestriction = value;
                                        });
                                      }
                                    },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Tags (Optional)
                    TextFormField(
                      controller: _tagsController,
                      decoration: InputDecoration(
                        labelText: l10n.tagsOptional,
                        border: OutlineInputBorder(),
                        hintText: l10n.tagExamples,
                        helperText: l10n.separateTagsWithCommas,
                      ),
                      enabled: !_isLoading,
                    ),

                    const SizedBox(height: 32),

                    // Create Post Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_isLoading || _isProcessingVideos)
                            ? null
                            : _createPost,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                              l10n.createPost,
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMediaPreview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).selectedMedia,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            // Images
            if (_selectedImages.isNotEmpty) ...[
              Text('${AppLocalizations.of(context).imagesLabel}:', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _selectedImages[index],
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedImages.removeAt(index);
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Videos
            if (_selectedVideos.isNotEmpty) ...[
              Text('${AppLocalizations.of(context).videosLabel}:', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedVideos.length,
                  itemBuilder: (context, index) {
                    final thumbnail = _videoThumbnails[index];
                    final duration = _videoDurations[index];

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          // Video thumbnail or placeholder
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0E0E0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: thumbnail != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      thumbnail,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : const Icon(Icons.videocam, size: 32),
                          ),
                          // Duration overlay
                          if (duration != null && duration > 0)
                            Positioned(
                              bottom: 4,
                              left: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  _formatDuration(duration),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 8),
                                ),
                              ),
                            ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedVideos.removeAt(index);
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDuration(int durationSeconds) {
    final minutes = durationSeconds ~/ 60;
    final remainingSeconds = durationSeconds % 60;
    return '${minutes}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}

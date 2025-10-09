import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/api_service.dart';

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
        for (var file in result.files) {
          if (file.path != null) {
            final File mediaFile = File(file.path!);
            final String extension = file.extension?.toLowerCase() ?? '';

            if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension)) {
              _selectedImages.add(mediaFile);
            } else if (['mp4', 'mkv', 'mov', 'avi', 'webm']
                .contains(extension)) {
              _selectedVideos.add(mediaFile);
            }
          }
        }

        setState(() {});
      }
    } catch (e) {
      print('Error picking media: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting media: $e')),
        );
      }
    }
  }

  Future<void> _createPost() async {
    if (!_formKey.currentState!.validate()) return;

    if (_contentController.text.trim().isEmpty &&
        _selectedImages.isEmpty &&
        _selectedVideos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add some content or media')),
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

      // Call API service to create post with file uploads
      final response = await _apiService.createCommunityPost(
        content: _contentController.text.trim().isNotEmpty
            ? _contentController.text.trim()
            : null,
        type: 'MEDIA', // Always MEDIA type for posts with text + media
        imageFiles: _selectedImages.isNotEmpty ? _selectedImages : null,
        videoFiles: _selectedVideos.isNotEmpty ? _selectedVideos : null,
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post created successfully!')),
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
          SnackBar(content: Text('Error creating post: $e')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createPost,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Post'),
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
                      decoration: const InputDecoration(
                        hintText: 'What\'s on your mind?',
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
                        title: const Text('Add Media'),
                        subtitle: Text(
                          '${_selectedImages.length} images, ${_selectedVideos.length} videos selected',
                        ),
                        trailing: const Icon(Icons.add),
                        onTap: _isLoading ? null : _pickMedia,
                      ),
                    ),

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
                              'Audience',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),

                            // Cost
                            TextFormField(
                              controller: _costController,
                              decoration: const InputDecoration(
                                labelText: 'Cost (Coins)',
                                hintText: '0',
                                border: OutlineInputBorder(),
                                helperText: '0 = Free post',
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value != null && value.isNotEmpty) {
                                  final cost = int.tryParse(value);
                                  if (cost == null || cost < 0) {
                                    return 'Please enter a valid cost (0 or greater)';
                                  }
                                }
                                return null;
                              },
                              enabled: !_isLoading,
                            ),

                            const SizedBox(height: 16),

                            // VIP Requirement
                            SwitchListTile(
                              title: const Text('VIP Only'),
                              subtitle: const Text(
                                  'Only VIP users can view this post'),
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
                              title: const Text('Make Public'),
                              subtitle: Text(
                                _isPublic
                                    ? 'Anyone can see this post'
                                    : 'Only people you follow can see this post',
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
                              'Post Settings',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),

                            // Allow Comments
                            SwitchListTile(
                              title: const Text('Allow Comments'),
                              subtitle:
                                  const Text('Let people comment on this post'),
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
                              title: const Text('Allow Links in Comments'),
                              subtitle: const Text(
                                  'Let people post links in comments'),
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
                              title: const Text('Pin This Post'),
                              subtitle: const Text('Keep this post at the top'),
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
                              title: const Text('NSFW Content'),
                              subtitle: const Text('Mark as not safe for work'),
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
                              'Who Can Reply?',
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
                              items: const [
                                DropdownMenuItem(
                                    value: 'FOLLOWERS',
                                    child: Text('Followers')),
                                DropdownMenuItem(
                                    value: 'PAID_VIEWERS',
                                    child: Text('Paid Viewers')),
                                DropdownMenuItem(
                                    value: 'FOLLOWING',
                                    child: Text('People You Follow')),
                                DropdownMenuItem(
                                    value: 'VERIFIED_FOLLOWING',
                                    child: Text('Verified Followers')),
                                DropdownMenuItem(
                                    value: 'NO_ONE', child: Text('No One')),
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
                      decoration: const InputDecoration(
                        labelText: 'Tags (Optional)',
                        border: OutlineInputBorder(),
                        hintText: 'tag1, tag2, tag3',
                        helperText: 'Separate tags with commas',
                      ),
                      enabled: !_isLoading,
                    ),

                    const SizedBox(height: 32),

                    // Create Post Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _createPost,
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
                            : const Text(
                                'Create Post',
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
              'Selected Media',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            // Images
            if (_selectedImages.isNotEmpty) ...[
              Text('Images:', style: Theme.of(context).textTheme.titleSmall),
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
              Text('Videos:', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedVideos.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0E0E0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.videocam, size: 32),
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
}

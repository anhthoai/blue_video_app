import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import '../../core/services/api_service.dart';
import '../../core/utils/video_utils.dart';
import '../../models/category_model.dart';

class UploadVideoScreenNew extends ConsumerStatefulWidget {
  const UploadVideoScreenNew({super.key});

  @override
  ConsumerState<UploadVideoScreenNew> createState() =>
      _UploadVideoScreenNewState();
}

class _UploadVideoScreenNewState extends ConsumerState<UploadVideoScreenNew> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();
  final _costController = TextEditingController(text: '0');
  final ApiService _apiService = ApiService();

  File? _videoFile;
  File? _thumbnailFile;
  String? _videoFileName;
  int? _videoDuration;
  List<CategoryModel> _categories = [];
  CategoryModel? _selectedCategory;
  bool _isPublic = true;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  // Thumbnail generation
  List<String> _generatedThumbnails = [];
  int _selectedThumbnailIndex = 0;
  bool _isGeneratingThumbnails = false;

  // Subtitle extraction
  Map<String, String> _extractedSubtitles = {}; // langCode -> file path
  List<String> _subtitleLanguages = []; // List of language codes

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    _costController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _apiService.getCategories();
      setState(() {
        _categories =
            categories.map((json) => CategoryModel.fromJson(json)).toList();
        // Select "Members" category by default if available
        _selectedCategory = _categories.firstWhere(
          (cat) => cat.categoryName == 'Members',
          orElse: () =>
              _categories.isNotEmpty ? _categories.first : _selectedCategory!,
        );
      });
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  Future<void> _extractVideoInfoAndGenerateThumbnails(File videoFile) async {
    setState(() {
      _isGeneratingThumbnails = true;
    });

    try {
      // Extract video duration
      final duration = await VideoUtils.getVideoDuration(videoFile);
      print('📹 Video duration extracted: ${duration}s');

      // Generate 5 thumbnails
      final thumbnails = await VideoUtils.generateThumbnails(videoFile, 5);
      print('🖼️  Generated ${thumbnails.length} thumbnails');

      // Extract embedded subtitles (especially from MKV files)
      final subtitles = await VideoUtils.extractSubtitles(videoFile);
      print('📝 Extracted ${subtitles.length} subtitle(s)');

      setState(() {
        _videoDuration = duration;
        _generatedThumbnails = thumbnails;
        _selectedThumbnailIndex = 0;
        _extractedSubtitles = subtitles;
        _subtitleLanguages = subtitles.keys.toList();
        _isGeneratingThumbnails = false;
      });

      if (mounted) {
        final subtitleInfo =
            subtitles.isNotEmpty ? ', ${subtitles.length} subtitle(s)' : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Video processed: ${duration}s, ${thumbnails.length} thumbnails$subtitleInfo',
            ),
          ),
        );
      }
    } catch (e) {
      print('⚠️  Error processing video: $e');
      setState(() {
        _videoDuration = null;
        _generatedThumbnails = [];
        _extractedSubtitles = {};
        _subtitleLanguages = [];
        _isGeneratingThumbnails = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing video: $e')),
        );
      }
    }
  }

  Future<void> _pickVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'mp4',
          'mkv',
          'm4v',
          'mov',
          'webm',
          'avi',
          'flv',
          'wmv'
        ],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileName =
            path.basenameWithoutExtension(result.files.single.name);

        setState(() {
          _videoFile = file;
          _videoFileName = result.files.single.name;
          // Auto-fill title with filename
          if (_titleController.text.isEmpty) {
            _titleController.text = fileName;
          }
        });

        // Extract video duration and generate thumbnails
        _extractVideoInfoAndGenerateThumbnails(file);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Processing video...')),
        );
      }
    } catch (e) {
      print('Error picking video: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting video: $e')),
      );
    }
  }

  Future<void> _pickThumbnail() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _thumbnailFile = File(result.files.single.path!);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thumbnail selected')),
        );
      }
    } catch (e) {
      print('Error picking thumbnail: $e');
    }
  }

  Future<void> _uploadVideo() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_videoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a video file')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      // Parse tags
      final tags = _tagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      // Parse cost
      final cost = int.tryParse(_costController.text) ?? 0;

      // Determine status based on isPublic
      final status = _isPublic ? 'PUBLIC' : 'VIP';

      // Use selected generated thumbnail or custom thumbnail
      File? thumbnailToUpload = _thumbnailFile;
      if (thumbnailToUpload == null && _generatedThumbnails.isNotEmpty) {
        thumbnailToUpload = File(_generatedThumbnails[_selectedThumbnailIndex]);
      }

      // Prepare subtitle files for upload
      Map<String, File>? subtitleFilesToUpload;
      if (_extractedSubtitles.isNotEmpty) {
        subtitleFilesToUpload = {};
        for (final entry in _extractedSubtitles.entries) {
          subtitleFilesToUpload[entry.key] = File(entry.value);
        }
      }

      // Upload video
      final response = await _apiService.uploadVideo(
        videoFile: _videoFile!,
        thumbnailFile: thumbnailToUpload,
        title: _titleController.text,
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        categoryId: _selectedCategory?.id,
        tags: tags,
        cost: cost,
        status: status,
        duration: _videoDuration,
        subtitleFiles: subtitleFilesToUpload,
        onProgress: (progress) {
          setState(() {
            _uploadProgress = progress;
          });
        },
      );

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video uploaded successfully!')),
          );
          context.pop();
        }
      } else {
        throw Exception(response['message'] ?? 'Upload failed');
      }
    } catch (e) {
      print('Error uploading video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Video'),
        centerTitle: true,
      ),
      body: _isUploading ? _buildUploadingView() : _buildForm(),
    );
  }

  Widget _buildUploadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'Uploading... ${(_uploadProgress * 100).toStringAsFixed(0)}%',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: LinearProgressIndicator(value: _uploadProgress),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Video Selection
          Card(
            child: ListTile(
              leading: const Icon(Icons.video_library),
              title:
                  Text(_videoFile != null ? _videoFileName! : 'Select Video'),
              subtitle: _videoFile != null
                  ? Text(
                      'Size: ${(_videoFile!.lengthSync() / 1024 / 1024).toStringAsFixed(2)} MB')
                  : const Text('Tap to select video file'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _isUploading ? null : _pickVideo,
            ),
          ),
          const SizedBox(height: 16),

          // Thumbnail Selection
          Card(
            child: ListTile(
              leading: const Icon(Icons.image),
              title: Text(_thumbnailFile != null
                  ? 'Thumbnail Selected'
                  : 'Select Thumbnail (Optional)'),
              subtitle: _thumbnailFile != null
                  ? Text(path.basename(_thumbnailFile!.path))
                  : const Text('Tap to select thumbnail image'),
              trailing: _thumbnailFile != null
                  ? Image.file(_thumbnailFile!,
                      width: 60, height: 60, fit: BoxFit.cover)
                  : const Icon(Icons.chevron_right),
              onTap: _isUploading ? null : _pickThumbnail,
            ),
          ),
          const SizedBox(height: 16),

          // Auto-Generated Thumbnails
          if (_isGeneratingThumbnails)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 16),
                    Text('Generating thumbnails...'),
                  ],
                ),
              ),
            ),

          if (_generatedThumbnails.isNotEmpty && !_isGeneratingThumbnails) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Auto-Generated Thumbnails',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Select a thumbnail or upload your own',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _generatedThumbnails.length,
                        itemBuilder: (context, index) {
                          final isSelected = _selectedThumbnailIndex == index;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedThumbnailIndex = index;
                                  _thumbnailFile =
                                      null; // Clear custom thumbnail
                                });
                              },
                              child: Container(
                                width: 120,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isSelected
                                        ? Theme.of(context).primaryColor
                                        : Colors.grey,
                                    width: isSelected ? 3 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Stack(
                                    children: [
                                      Image.file(
                                        File(_generatedThumbnails[index]),
                                        width: 120,
                                        height: 80,
                                        fit: BoxFit.cover,
                                      ),
                                      if (isSelected)
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .primaryColor,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.check,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      Positioned(
                                        bottom: 4,
                                        right: 4,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black54,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '#${index + 1}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          const SizedBox(height: 8),

          // Title
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Video Title *',
              border: OutlineInputBorder(),
              hintText: 'Enter video title',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a title';
              }
              return null;
            },
            enabled: !_isUploading,
          ),
          const SizedBox(height: 16),

          // Description
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
              hintText: 'Enter video description',
            ),
            maxLines: 3,
            enabled: !_isUploading,
          ),
          const SizedBox(height: 16),

          // Category
          DropdownButtonFormField<CategoryModel>(
            value: _selectedCategory,
            decoration: const InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(),
            ),
            items: _categories.map((category) {
              return DropdownMenuItem(
                value: category,
                child: Text(category.categoryName),
              );
            }).toList(),
            onChanged: _isUploading
                ? null
                : (value) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  },
          ),
          const SizedBox(height: 16),

          // Tags
          TextFormField(
            controller: _tagsController,
            decoration: const InputDecoration(
              labelText: 'Tags',
              border: OutlineInputBorder(),
              hintText: 'tag1, tag2, tag3',
              helperText: 'Separate tags with commas',
            ),
            enabled: !_isUploading,
          ),
          const SizedBox(height: 16),

          // Cost
          TextFormField(
            controller: _costController,
            decoration: const InputDecoration(
              labelText: 'Cost (Coins)',
              border: OutlineInputBorder(),
              hintText: '0',
              helperText: '0 = Free video',
              prefixIcon: Icon(Icons.monetization_on),
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
            enabled: !_isUploading,
          ),
          const SizedBox(height: 16),

          // Public/VIP Switch
          Card(
            child: SwitchListTile(
              title: const Text('Make Video Public'),
              subtitle: Text(
                _isPublic
                    ? 'Anyone can watch this video'
                    : 'Only VIP users can watch this video',
              ),
              value: _isPublic,
              onChanged: _isUploading
                  ? null
                  : (value) {
                      setState(() {
                        _isPublic = value;
                      });
                    },
            ),
          ),
          const SizedBox(height: 32),

          // Upload Button
          ElevatedButton(
            onPressed: _isUploading ? null : _uploadVideo,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text(
              'Upload Video',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

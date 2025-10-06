import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import '../../core/services/api_service.dart';
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

        // TODO: Extract video info using flutter_ffmpeg
        // For now, set a placeholder duration
        setState(() {
          _videoDuration = 0;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Video selected: $_videoFileName')),
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

      // Upload video
      final response = await _apiService.uploadVideo(
        videoFile: _videoFile!,
        thumbnailFile: _thumbnailFile,
        title: _titleController.text,
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        categoryId: _selectedCategory?.id,
        tags: tags,
        cost: cost,
        status: status,
        duration: _videoDuration,
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
          const SizedBox(height: 24),

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

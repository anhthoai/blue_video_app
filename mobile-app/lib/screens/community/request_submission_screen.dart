import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mime/mime.dart';

import '../../core/providers/community_hub_provider.dart';
import '../../core/utils/video_utils.dart';
import '../../models/community_hub_models.dart';
import '../../widgets/community/request_linked_media_picker.dart';

class RequestSubmissionScreen extends ConsumerStatefulWidget {
  final String requestId;

  const RequestSubmissionScreen({
    super.key,
    required this.requestId,
  });

  @override
  ConsumerState<RequestSubmissionScreen> createState() =>
      _RequestSubmissionScreenState();
}

class _RequestSubmissionScreenState
    extends ConsumerState<RequestSubmissionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _searchKeywordController = TextEditingController();
  final _linkController = TextEditingController();

  CommunityRequestSubmissionType _submissionType =
      CommunityRequestSubmissionType.linkedVideo;
  CommunityLinkedMedia? _selectedLinkedMedia;
  PlatformFile? _pickedFile;
  File? _generatedThumbnailFile;
  bool _isSubmitting = false;
  bool _isBootstrapping = true;
  bool _isPreparingPreview = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRequest();
    });
  }

  @override
  void dispose() {
    _deleteGeneratedThumbnail();
    _titleController.dispose();
    _descriptionController.dispose();
    _searchKeywordController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final request = ref.watch(communityHubProvider.select((state) {
      for (final item in state.requests) {
        if (item.id == widget.requestId) {
          return item;
        }
      }
      return null;
    }));

    if (request == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Recommend Media')),
        body: Center(
          child: _isBootstrapping
              ? const CircularProgressIndicator()
              : const Text('Request not found'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text('Recommend Media'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xFF6B8DFF), Color(0xFF58C6FF)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Submit a match',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _requestSummaryText(request),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Form(
              key: _formKey,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'How do you want to help?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTypeButton(
                            label: 'Link media',
                            value: CommunityRequestSubmissionType.linkedVideo,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildTypeButton(
                            label: 'Upload file',
                            value: CommunityRequestSubmissionType.fileUpload,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_submissionType ==
                        CommunityRequestSubmissionType.linkedVideo)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F8FF),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.search_rounded,
                              color: Color(0xFF4F82FF),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Attach an existing search result or external link. This path is free for the contributor and works for images, videos, and other media that already exist.',
                                style: TextStyle(height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_submissionType ==
                        CommunityRequestSubmissionType.fileUpload) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F8FE),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE0E7FF)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'File upload',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _pickedFile == null
                                  ? 'Pick a local file to attach to this request.'
                                  : '${_pickedFile!.name} (${_pickedFile!.size} bytes)',
                            ),
                            if (_isPreparingPreview) ...[
                              const SizedBox(height: 8),
                              const Text(
                                'Generating video preview...',
                                style: TextStyle(color: Color(0xFF64748B)),
                              ),
                            ] else if (_generatedThumbnailFile != null) ...[
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.file(
                                  _generatedThumbnailFile!,
                                  height: 120,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _pickFile,
                              icon: const Icon(Icons.attach_file_rounded),
                              label: Text(
                                _pickedFile == null
                                    ? 'Choose file'
                                    : 'Change file',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Submission title',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter a title';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Why this matches',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Describe the match';
                        }
                        return null;
                      },
                    ),
                    if (_submissionType ==
                        CommunityRequestSubmissionType.linkedVideo) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _searchKeywordController,
                        decoration: const InputDecoration(
                          labelText: 'Search keywords used',
                          hintText: 'Example: backstage mic check',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Attach from app library',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (_selectedLinkedMedia != null)
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _selectedLinkedMedia = null;
                                });
                              },
                              child: const Text('Clear'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _openLinkedMediaPicker,
                        icon: const Icon(Icons.search_rounded),
                        label: Text(
                          _selectedLinkedMedia == null
                              ? 'Search app library'
                              : 'Change library selection',
                        ),
                      ),
                      if (_selectedLinkedMedia != null) ...[
                        const SizedBox(height: 14),
                        _buildSelectedLinkedMediaCard(_selectedLinkedMedia!),
                      ] else ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _linkController,
                          decoration: const InputDecoration(
                            labelText: 'External media link',
                            hintText: 'Paste a media link if it is not in the app library',
                          ),
                          validator: (value) {
                            if (_submissionType !=
                                CommunityRequestSubmissionType.linkedVideo) {
                              return null;
                            }
                            if (_selectedLinkedMedia != null) {
                              return null;
                            }
                            if (value == null || value.trim().isEmpty) {
                              return 'Pick a library result or paste a link';
                            }
                            return null;
                          },
                        ),
                      ],
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isSubmitting ? null : _submit,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                        label: Text(
                          _isSubmitting ? 'Submitting...' : 'Send Recommendation',
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeButton({
    required String label,
    required CommunityRequestSubmissionType value,
  }) {
    final isSelected = _submissionType == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _submissionType = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isSelected ? const Color(0xFFEDF3FF) : const Color(0xFFF7F8FC),
          border: Border.all(
            color: isSelected ? const Color(0xFF4F82FF) : const Color(0xFFD9E1F5),
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? const Color(0xFF2D67F6) : const Color(0xFF576074),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.any,
    );

    if (result != null && result.files.isNotEmpty) {
      final pickedFile = result.files.first;
      setState(() {
        _pickedFile = pickedFile;
      });

      await _prepareThumbnailForPickedFile(pickedFile);
    }
  }

  Future<void> _deleteGeneratedThumbnail() async {
    final thumbnailFile = _generatedThumbnailFile;
    _generatedThumbnailFile = null;

    if (thumbnailFile == null) {
      return;
    }

    try {
      if (await thumbnailFile.exists()) {
        await thumbnailFile.delete();
      }
    } catch (_) {}
  }

  bool _isVideoFile(PlatformFile file) {
    final candidatePath = file.path ?? file.name;
    final mimeType = lookupMimeType(candidatePath)?.toLowerCase();
    if (mimeType != null && mimeType.startsWith('video/')) {
      return true;
    }

    final normalizedName = file.name.toLowerCase();
    return normalizedName.endsWith('.mp4') ||
        normalizedName.endsWith('.m4v') ||
        normalizedName.endsWith('.mov') ||
        normalizedName.endsWith('.webm') ||
        normalizedName.endsWith('.avi') ||
        normalizedName.endsWith('.mkv');
  }

  Future<void> _prepareThumbnailForPickedFile(PlatformFile file) async {
    await _deleteGeneratedThumbnail();

    final filePath = file.path;
    if (filePath == null || filePath.isEmpty || !_isVideoFile(file)) {
      if (mounted) {
        setState(() {
          _isPreparingPreview = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isPreparingPreview = true;
      });
    }

    try {
      final videoFile = File(filePath);
      final duration = await VideoUtils.getVideoDuration(videoFile);
      final previewTimestamp = duration != null && duration > 2
          ? duration ~/ 2
          : 0;
      final thumbnailPath = await VideoUtils.generateThumbnail(
        videoFile,
        previewTimestamp,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _generatedThumbnailFile = File(thumbnailPath);
        _isPreparingPreview = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isPreparingPreview = false;
      });
    }
  }

  Future<void> _loadRequest() async {
    try {
      await ref.read(communityHubProvider.notifier).fetchRequest(widget.requestId);
    } finally {
      if (mounted) {
        setState(() {
          _isBootstrapping = false;
        });
      }
    }
  }

  Future<void> _openLinkedMediaPicker() async {
    final selection = await showRequestLinkedMediaPicker(
      context,
      initialQuery: _searchKeywordController.text.trim(),
    );
    if (!mounted || selection == null) {
      return;
    }

    setState(() {
      _selectedLinkedMedia = selection.media;
      _linkController.clear();
      if (_searchKeywordController.text.trim().isEmpty) {
        _searchKeywordController.text = selection.searchQuery;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_submissionType == CommunityRequestSubmissionType.fileUpload &&
        _isPreparingPreview) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for the file preview to finish generating.')),
      );
      return;
    }

    if (_submissionType == CommunityRequestSubmissionType.fileUpload &&
        _pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a file first')),
      );
      return;
    }

    if (_submissionType == CommunityRequestSubmissionType.fileUpload &&
        (_pickedFile?.path == null || _pickedFile!.path!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This file cannot be uploaded from the current picker result.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final trimmedLink = _linkController.text.trim();
      final linkedMedia = _submissionType ==
              CommunityRequestSubmissionType.linkedVideo
          ? (_selectedLinkedMedia ??
              (trimmedLink.isNotEmpty
                  ? buildCommunityLinkedMediaFromExternalUrl(
                      trimmedLink,
                      title: _titleController.text.trim(),
                    )
                  : null))
          : null;

      final submissionId = await ref.read(communityHubProvider.notifier).addSubmission(
            requestId: widget.requestId,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            type: _submissionType,
            linkedVideoUrl: _submissionType ==
                    CommunityRequestSubmissionType.linkedVideo
                ? linkedMedia?.primaryUrl
                : null,
            linkedMedia: linkedMedia,
            searchKeyword: _submissionType ==
                    CommunityRequestSubmissionType.linkedVideo
                ? _searchKeywordController.text.trim()
                : null,
            filePath: _submissionType == CommunityRequestSubmissionType.fileUpload
                ? _pickedFile?.path
                : null,
            thumbnailFile: _submissionType ==
                CommunityRequestSubmissionType.fileUpload
              ? _generatedThumbnailFile
              : null,
          );

      if (!mounted) {
        return;
      }

      context.pop(submissionId);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildSelectedLinkedMediaCard(CommunityLinkedMedia linkedMedia) {
    final previewImageUrl = linkedMedia.previewImageUrl;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD9E4F7)),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF1FF),
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: previewImageUrl != null
                ? Image.network(
                    previewImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return Icon(
                        communityLinkedMediaPreviewIcon(linkedMedia),
                        color: const Color(0xFF2D67F6),
                      );
                    },
                  )
                : Icon(
                    communityLinkedMediaPreviewIcon(linkedMedia),
                    color: const Color(0xFF2D67F6),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  linkedMedia.displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildMetaPill(communityLinkedMediaPreviewLabel(linkedMedia)),
                    _buildMetaPill(communityLinkedMediaSourceLabel(linkedMedia)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'This selection will be attached as a recommended media item.',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF4B5563),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _requestSummaryText(CommunityRequest request) {
    final description = request.description.trim();
    if (description.isNotEmpty) {
      return description;
    }

    return request.title.trim();
  }
}

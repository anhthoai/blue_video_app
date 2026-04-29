import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/providers/community_hub_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';

class CreateRequestScreen extends ConsumerStatefulWidget {
  const CreateRequestScreen({super.key});

  @override
  ConsumerState<CreateRequestScreen> createState() =>
      _CreateRequestScreenState();
}

class _CreateRequestScreenState extends ConsumerState<CreateRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _keywordsController = TextEditingController();
  final _coinsController = TextEditingController(text: '0');
  final ImagePicker _imagePicker = ImagePicker();
  final List<XFile> _selectedImages = <XFile>[];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _keywordsController.dispose();
    _coinsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keywords = _parseKeywords(_keywordsController.text);
    final currentUser = ref.watch(authServiceProvider).currentUser;
    final currentBalance = currentUser?.coinBalance ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF),
      appBar: AppBar(
        title: const Text('Request'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xFF5D95FF), Color(0xFF7A5CFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Set a bounty and collect matches from the community',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Others can upload files or attach an existing media link from search. You approve the best match and release the coins.',
                    style: TextStyle(
                      color: Colors.white70,
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
                    TextFormField(
                      controller: _descriptionController,
                      minLines: 4,
                      maxLines: 7,
                      decoration: const InputDecoration(
                        labelText: 'What are you looking for?',
                        hintText:
                            'Describe the full album, video, or files you want. Add scene details, names, or keywords to help others search.',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Describe what you need';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'The first line becomes the request headline automatically, so you only need one post-style description here.',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _keywordsController,
                      decoration: const InputDecoration(
                        labelText: 'Keywords',
                        hintText: 'Separate keywords with commas',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    if (keywords.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: keywords.map((keyword) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F5FF),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '#$keyword',
                              style: const TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _buildAttachmentSection(),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _coinsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Coin bounty',
                        prefixIcon: Icon(Icons.monetization_on_outlined),
                        helperText: '0 is allowed. You can add more coins later from the detail screen.',
                      ),
                      validator: (value) {
                        final coins = int.tryParse(value ?? '');
                        if (coins == null || coins < 0) {
                          return 'Coins cannot be negative';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Available balance: $currentBalance coins',
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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
                            : const Icon(Icons.campaign_outlined),
                        label: Text(
                          _isSubmitting ? 'Publishing...' : 'Publish Request',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
  final description = _descriptionController.text.trim();
      final requestId = await ref.read(communityHubProvider.notifier).createRequest(
    title: _buildRequestTitle(description),
    description: description,
            coins: int.parse(_coinsController.text.trim()),
            keywords: _parseKeywords(_keywordsController.text),
    previewHints: _parseKeywords(_keywordsController.text).take(4).toList(),
    imagePaths:
        _selectedImages.map((image) => image.path).toList(growable: false),
          );

      if (!mounted) {
        return;
      }

      context.pop(requestId);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildAttachmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Reference images',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _isSubmitting ? null : _pickImages,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Attach'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Optional. Add screenshots or cover images so contributors know what full album, video, or set you want.',
          style: TextStyle(
            color: Color(0xFF6B7280),
            height: 1.35,
          ),
        ),
        if (_selectedImages.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final image = _selectedImages[index];
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.file(
                        File(image.path),
                        width: 92,
                        height: 92,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: InkWell(
                        onTap: _isSubmitting ? null : () => _removeImage(index),
                        borderRadius: BorderRadius.circular(99),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickImages() async {
    try {
      final images = await _imagePicker.pickMultiImage(imageQuality: 85);
      if (images.isEmpty || !mounted) {
        return;
      }

      setState(() {
        final merged = <XFile>[..._selectedImages, ...images];
        _selectedImages
          ..clear()
          ..addAll(merged.take(6));
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to attach images: $error')),
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  List<String> _parseKeywords(String source) {
    return source
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
  }

  String _buildRequestTitle(String content) {
    final normalized = content
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join(' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (normalized.length <= 72) {
      return normalized;
    }

    return '${normalized.substring(0, 72).trimRight()}...';
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    if (message.toLowerCase().contains('insufficient')) {
      return 'You do not have enough coins for this bounty.';
    }
    return message;
  }
}

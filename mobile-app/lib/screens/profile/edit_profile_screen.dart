import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/services/auth_service.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _bioController = TextEditingController();
  bool _isLoading = false;
  bool _isUploadingAvatar = false;
  bool _isUploadingBanner = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final user = ref.read(currentUserProvider);
    if (user != null) {
      _usernameController.text = user.username;
      _firstNameController.text = user.firstName ?? '';
      _lastNameController.text = user.lastName ?? '';
      _bioController.text = user.bio ?? '';
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final updatedUser = await authService.updateUserProfile(
        username: _usernameController.text.trim(),
        bio: _bioController.text.trim(),
        firstName: _firstNameController.text.trim().isNotEmpty
            ? _firstNameController.text.trim()
            : null,
        lastName: _lastNameController.text.trim().isNotEmpty
            ? _lastNameController.text.trim()
            : null,
      );

      if (updatedUser != null && mounted) {
        // Invalidate provider to force UI update everywhere
        ref.invalidate(currentUserProvider);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update profile'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
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

  void _reloadUserData() {
    // Trigger a rebuild which will re-read from the provider
    // The AuthService has already updated _currentUser, so the provider will return fresh data
    setState(() {
      final user = ref.read(currentUserProvider);
      if (user != null) {
        _usernameController.text = user.username;
        _firstNameController.text = user.firstName ?? '';
        _lastNameController.text = user.lastName ?? '';
        _bioController.text = user.bio ?? '';
      }
    });
  }

  Future<void> _pickAvatar() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _isUploadingAvatar = true;
      });

      try {
        final authService = ref.read(authServiceProvider);
        final updatedUser = await authService.uploadAvatar(image.path);

        if (updatedUser != null && mounted) {
          _reloadUserData(); // Reload the form with updated data
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Avatar updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to upload avatar'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error uploading avatar: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isUploadingAvatar = false;
          });
        }
      }
    }
  }

  Future<void> _pickBanner() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 600,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _isUploadingBanner = true;
      });

      try {
        final authService = ref.read(authServiceProvider);
        final updatedUser = await authService.uploadBanner(image.path);

        if (updatedUser != null && mounted) {
          _reloadUserData(); // Reload the form with updated data
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Banner updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to upload banner'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error uploading banner: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isUploadingBanner = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveProfile,
              child: const Text('Save',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Banner Section
              Stack(
                children: [
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.secondary,
                        ],
                      ),
                    ),
                    child: user.bannerUrl != null && user.bannerUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: user.bannerUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[300],
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.error),
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: FloatingActionButton.small(
                      onPressed: _isUploadingBanner ? null : _pickBanner,
                      child: _isUploadingBanner
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.camera_alt),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Avatar Section
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey[300],
                      backgroundImage:
                          user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                              ? NetworkImage(user.avatarUrl!)
                              : null,
                      child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                          ? const Icon(Icons.person,
                              size: 60, color: Colors.grey)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: FloatingActionButton.small(
                        onPressed: _isUploadingAvatar ? null : _pickAvatar,
                        child: _isUploadingAvatar
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Icon(Icons.camera_alt, size: 20),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Form Fields
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Email (Read-only)
                    TextFormField(
                      initialValue: user.email,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email),
                        enabled: false,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Username
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.person),
                        hintText: 'Enter your username',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a username';
                        }
                        if (value.length < 3) {
                          return 'Username must be at least 3 characters';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // First Name
                    TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                        prefixIcon: Icon(Icons.person_outline),
                        hintText: 'Enter your first name',
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Last Name
                    TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Last Name',
                        prefixIcon: Icon(Icons.person_outline),
                        hintText: 'Enter your last name',
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Bio
                    TextFormField(
                      controller: _bioController,
                      decoration: const InputDecoration(
                        labelText: 'Bio',
                        prefixIcon: Icon(Icons.info),
                        hintText: 'Tell us about yourself',
                        alignLabelWithHint: true,
                      ),
                      maxLines: 4,
                      maxLength: 200,
                      validator: (value) {
                        if (value != null && value.length > 200) {
                          return 'Bio must be less than 200 characters';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    // Account Info
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Account Information',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            _buildInfoRow(
                              'Account ID',
                              user.id.substring(0, 8) + '...',
                              Icons.fingerprint,
                            ),
                            const Divider(height: 24),
                            _buildInfoRow(
                              'Verified',
                              user.isVerified ? 'Yes' : 'No',
                              user.isVerified ? Icons.verified : Icons.pending,
                            ),
                            const Divider(height: 24),
                            _buildInfoRow(
                              'Member Since',
                              _formatDate(user.createdAt),
                              Icons.calendar_today,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Danger Zone
                    Card(
                      color: Colors.red[50],
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Danger Zone',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red[900],
                                  ),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: () {
                                _showDeleteAccountDialog();
                              },
                              icon: const Icon(Icons.delete_forever),
                              label: const Text('Delete Account'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Save Button
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Save Changes',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Account deletion coming soon'),
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/dating_service.dart';
import '../../l10n/app_localizations.dart';
import '../../models/dating_model.dart';
import '../dating/dating_profile_edit_screen.dart';
import '../dating/private_album_screen.dart';
import '../../widgets/common/presigned_image.dart';

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
  bool _isLoadingDatingProfile = false;
  bool _isUploadingDatingPhoto = false;
  DatingProfile? _datingProfile;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadDatingProfile();
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
    final l10n = AppLocalizations.of(context);

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
          SnackBar(
            content: Text(l10n.updatedSuccessfully),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.profileProfileUpdateFailed),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.error}: $e')),
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
    final l10n = AppLocalizations.of(context);
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
            SnackBar(
              content: Text(l10n.updatedSuccessfully),
              backgroundColor: Colors.green,
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.uploadFailed),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${l10n.errorUploadingFile}: $e')),
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
    final l10n = AppLocalizations.of(context);
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
            SnackBar(
              content: Text(l10n.updatedSuccessfully),
              backgroundColor: Colors.green,
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.uploadFailed),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${l10n.errorUploadingFile}: $e')),
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

  Future<void> _loadDatingProfile() async {
    if (_isLoadingDatingProfile) return;
    setState(() => _isLoadingDatingProfile = true);
    try {
      final profile = await DatingService().getMyDatingProfile();
      if (!mounted) return;
      setState(() => _datingProfile = profile);
    } catch (_) {
      // Ignore - user may not have created dating profile yet.
    } finally {
      if (mounted) setState(() => _isLoadingDatingProfile = false);
    }
  }

  Future<void> _pickDatingAvatarPhoto() async {
    if (_isUploadingDatingPhoto) return;
    final l10n = AppLocalizations.of(context);

    final currentCount = _datingProfile?.publicPhotos.length ?? 0;
    if (currentCount >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.profileDatingMaxPhotosReached)),
      );
      return;
    }

    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 90,
    );
    if (image == null) return;

    setState(() => _isUploadingDatingPhoto = true);
    try {
      await DatingService().uploadPublicPhoto(File(image.path));
      await _loadDatingProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.profileDatingAvatarAdded)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.errorUploadingFile}: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploadingDatingPhoto = false);
    }
  }

  Future<void> _deleteDatingAvatarPhoto(int index) async {
    final l10n = AppLocalizations.of(context);
    try {
      await DatingService().deletePublicPhoto(index);
      await _loadDatingProfile();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.error}: ${l10n.profileDatingAvatarDeleteError}: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return Scaffold(
        body: Center(child: Text(l10n.profilePleaseLogIn)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.editProfile),
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
              child: Text(l10n.save,
              style: const TextStyle(fontWeight: FontWeight.bold)),
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
                        ? PresignedImage(
                            imageUrl: user.bannerUrl,
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                            placeholder: Container(
                              color: Colors.grey[300],
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            errorWidget: Container(
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
                      heroTag: 'edit_profile_banner_camera',
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
                    SizedBox(
                      width: 120,
                      height: 120,
                      child:
                          user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                              ? ClipOval(
                                  child: PresignedImage(
                                    imageUrl: user.avatarUrl,
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.cover,
                                    errorWidget: const CircleAvatar(
                                      radius: 60,
                                      backgroundColor: Colors.grey,
                                      child: Icon(Icons.person,
                                          size: 60, color: Colors.white),
                                    ),
                                  ),
                                )
                              : const CircleAvatar(
                                  radius: 60,
                                  backgroundColor: Colors.grey,
                                  child: Icon(Icons.person,
                                      size: 60, color: Colors.white),
                                ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: FloatingActionButton.small(
                        onPressed: _isUploadingAvatar ? null : _pickAvatar,
                        heroTag: 'edit_profile_avatar_camera',
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
                      decoration: InputDecoration(
                        labelText: l10n.email,
                        prefixIcon: const Icon(Icons.email),
                        enabled: false,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Username
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: l10n.username,
                        prefixIcon: const Icon(Icons.person),
                        hintText: l10n.profileEnterUsername,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return l10n.profileUsernameRequired;
                        }
                        if (value.length < 3) {
                          return l10n.profileUsernameMinLength;
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // First Name
                    TextFormField(
                      controller: _firstNameController,
                      decoration: InputDecoration(
                        labelText: l10n.profileFirstName,
                        prefixIcon: const Icon(Icons.person_outline),
                        hintText: l10n.profileEnterFirstName,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Last Name
                    TextFormField(
                      controller: _lastNameController,
                      decoration: InputDecoration(
                        labelText: l10n.profileLastName,
                        prefixIcon: const Icon(Icons.person_outline),
                        hintText: l10n.profileEnterLastName,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Bio
                    TextFormField(
                      controller: _bioController,
                      decoration: InputDecoration(
                        labelText: l10n.bio,
                        prefixIcon: const Icon(Icons.info),
                        hintText: l10n.profileBioHint,
                        alignLabelWithHint: true,
                      ),
                      maxLines: 4,
                      maxLength: 200,
                      validator: (value) {
                        if (value != null && value.length > 200) {
                          return l10n.profileBioMaxLength;
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.profileDatingAvatarsMax6,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.profileDatingAvatarsHelp,
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _buildMainAvatarCell(user.avatarUrl),
                                ...(_datingProfile?.publicPhotos ?? [])
                                    .asMap()
                                    .entries
                                    .map((entry) => _buildDatingExtraCell(entry.key, entry.value)),
                                if ((_datingProfile?.publicPhotos.length ?? 0) < 5)
                                  _buildAddDatingPhotoCell(),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.favorite_outline),
                              ),
                              title: Text(l10n.datingEditProfile),
                              subtitle: Text(l10n.profileEditDatingProfileSubtitle),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const DatingProfileEditScreen(),
                                  ),
                                );
                              },
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.lock_outline),
                              ),
                              title: Text(l10n.profilePrivateAlbumMax9Images),
                              subtitle: Text(l10n.profilePrivateAlbumSubtitle),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const PrivateAlbumScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
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
                              l10n.profileAccountInformation,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            _buildInfoRow(
                              l10n.profileAccountId,
                              '${user.id.substring(0, 8)}...',
                              Icons.fingerprint,
                            ),
                            const Divider(height: 24),
                            _buildInfoRow(
                              l10n.profileVerified,
                              user.isVerified ? l10n.profileYes : l10n.profileNo,
                              user.isVerified ? Icons.verified : Icons.pending,
                            ),
                            const Divider(height: 24),
                            _buildInfoRow(
                              l10n.profileMemberSince,
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
                              l10n.profileDangerZone,
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
                              label: Text(l10n.profileDeleteAccount),
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
                                : Text(
                                  l10n.saveChanges,
                                  style: const TextStyle(
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

  Widget _buildMainAvatarCell(String? avatarUrl) {
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: avatarUrl != null && avatarUrl.isNotEmpty
                ? PresignedImage(
                    imageUrl: avatarUrl,
                    fit: BoxFit.cover,
                    errorWidget: Container(
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.person),
                    ),
                  )
                : Container(
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.person),
                  ),
          ),
          Positioned(
            left: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                AppLocalizations.of(context).profileMainAvatar,
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatingExtraCell(int index, String imageUrl) {
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: PresignedImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              errorWidget: Container(
                color: Colors.grey.shade300,
                child: const Icon(Icons.image_not_supported_outlined),
              ),
            ),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: InkWell(
              onTap: () => _deleteDatingAvatarPhoto(index),
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddDatingPhotoCell() {
    return InkWell(
      onTap: _isUploadingDatingPhoto ? null : _pickDatingAvatarPhoto,
      child: Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: _isUploadingDatingPhoto
            ? const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : const Icon(Icons.add_photo_alternate_outlined),
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.profileDeleteAccount),
        content: Text(
          l10n.profileDeleteAccountConfirmMessage,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.profileDeleteAccountComingSoon),
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return DateFormat.yMMMMd(locale).format(date);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/content_protection_service.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  final int initialTab;

  const AdminDashboardScreen({
    super.key,
    this.initialTab = 0,
  });

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  String? _error;
  Map<String, dynamic> _dashboard = const {};
  List<Map<String, dynamic>> _videos = const [];
  List<Map<String, dynamic>> _forums = const [];
  List<Map<String, dynamic>> _users = const [];
  List<Map<String, dynamic>> _categories = const [];
  List<Map<String, dynamic>> _reports = const [];
  List<Map<String, dynamic>> _feedbackEntries = const [];
  final Set<String> _busyKeys = <String>{};

  int get _initialTabIndex {
    if (widget.initialTab < 0) {
      return 0;
    }
    if (widget.initialTab > 6) {
      return 6;
    }
    return widget.initialTab;
  }

  List<Map<String, dynamic>> get _flatCategories {
    final items = <Map<String, dynamic>>[];

    for (final rootCategory in _categories) {
      final root = Map<String, dynamic>.from(rootCategory);
      final children = List<Map<String, dynamic>>.from(
        root['children'] as List? ?? const [],
      );

      items.add({
        ...root,
        'depth': 0,
        'parentName': null,
        'childCount': children.length,
      });

      for (final childCategory in children) {
        items.add({
          ...Map<String, dynamic>.from(childCategory),
          'depth': 1,
          'parentName': root['categoryName'],
          'childCount': 0,
          'videoCount': childCategory['videoCount'] ?? 0,
        });
      }
    }

    return items;
  }

  int get _nextCategoryOrder {
    var maxOrder = -1;

    for (final category in _flatCategories) {
      final orderValue = category['categoryOrder'];
      final order = orderValue is num
          ? orderValue.toInt()
          : int.tryParse('$orderValue') ?? 0;
      if (order > maxOrder) {
        maxOrder = order;
      }
    }

    return maxOrder + 1;
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  bool _isBusy(String key) => _busyKeys.contains(key);

  void _setBusy(String key, bool value) {
    if (!mounted) {
      return;
    }

    setState(() {
      if (value) {
        _busyKeys.add(key);
      } else {
        _busyKeys.remove(key);
      }
    });
  }

  Future<void> _runBusyAction(
      String key, Future<void> Function() action) async {
    _setBusy(key, true);
    try {
      await action();
    } finally {
      _setBusy(key, false);
    }
  }

  Future<void> _loadAll() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait<dynamic>([
        _apiService.getAdminDashboard(),
        _apiService.getAdminVideos(page: 1, limit: 50),
        _apiService.getAdminForums(page: 1, limit: 50),
        _apiService.getAdminUsers(page: 1, limit: 50),
        _apiService.getCategories(),
        _apiService.getAdminReports(limit: 20),
        _apiService.getAdminFeedback(limit: 20),
      ]);

      final dashboardResponse = results[0] as Map<String, dynamic>;
      final videosResponse = results[1] as Map<String, dynamic>;
      final forumsResponse = results[2] as Map<String, dynamic>;
      final usersResponse = results[3] as Map<String, dynamic>;
      final categoriesResponse = results[4] as List<Map<String, dynamic>>;
      final reportsResponse = results[5] as Map<String, dynamic>;
      final feedbackResponse = results[6] as Map<String, dynamic>;

      if (!mounted) {
        return;
      }

      setState(() {
        _dashboard = Map<String, dynamic>.from(
          dashboardResponse['data'] as Map? ?? const {},
        );
        _videos = List<Map<String, dynamic>>.from(
          videosResponse['data'] as List? ?? const [],
        );
        _forums = List<Map<String, dynamic>>.from(
          forumsResponse['data'] as List? ?? const [],
        );
        _users = List<Map<String, dynamic>>.from(
          usersResponse['data'] as List? ?? const [],
        );
        _categories = categoriesResponse;
        _reports = List<Map<String, dynamic>>.from(
          reportsResponse['data'] as List? ?? const [],
        );
        _feedbackEntries = List<Map<String, dynamic>>.from(
          feedbackResponse['data'] as List? ?? const [],
        );
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _updateReport(
    Map<String, dynamic> report,
    String action, {
    String? adminReply,
  }) async {
    final busyKey = 'report:${report['id']}';

    await _runBusyAction(busyKey, () async {
      try {
        final response = await _apiService.updateAdminReport(
          reportType: '${report['type'] ?? ''}',
          reportId: '${report['id'] ?? ''}',
          action: action,
          adminReply: adminReply,
        );

        if (!mounted) {
          return;
        }

        if (response['success'] == true) {
          _showMessage(response['message'] ?? 'Report updated');
          await _loadAll();
        } else {
          _showMessage(response['message'] ?? 'Failed to update report');
        }
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showMessage('Failed to update report: $error');
      }
    });
  }

  Future<void> _replyToReport(Map<String, dynamic> report) async {
    final reply = await _promptForText(
      title: 'Reply to report',
      hintText: 'Add a note for this review',
      actionLabel: 'Send reply',
    );

    if (reply == null || reply.trim().isEmpty) {
      return;
    }

    await _updateReport(report, 'review', adminReply: reply.trim());
  }

  Future<void> _updateFeedback(
    Map<String, dynamic> entry, {
    String? status,
    String? adminReply,
  }) async {
    final busyKey = 'feedback:${entry['id']}';

    await _runBusyAction(busyKey, () async {
      try {
        final response = await _apiService.updateAdminFeedback(
          '${entry['id'] ?? ''}',
          status: status,
          adminReply: adminReply,
        );

        if (!mounted) {
          return;
        }

        if (response['success'] == true) {
          _showMessage(response['message'] ?? 'Feedback updated');
          await _loadAll();
        } else {
          _showMessage(response['message'] ?? 'Failed to update feedback');
        }
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showMessage('Failed to update feedback: $error');
      }
    });
  }

  Future<void> _replyToFeedback(Map<String, dynamic> entry) async {
    final reply = await _promptForText(
      title: 'Reply to feedback',
      hintText: 'Write your response',
      actionLabel: 'Send reply',
    );

    if (reply == null || reply.trim().isEmpty) {
      return;
    }

    await _updateFeedback(
      entry,
      status: 'RESOLVED',
      adminReply: reply.trim(),
    );
  }

  Future<void> _editVideo(Map<String, dynamic> video) async {
    final edits = await _showVideoEditor(video);
    if (edits == null) {
      return;
    }

    final busyKey = 'video:${video['id']}';
    await _runBusyAction(busyKey, () async {
      try {
        final response = await _apiService.updateAdminVideo(
          videoId: '${video['id']}',
          title: edits['title'] as String?,
          description: edits['description'] as String?,
          status: edits['status'] as String?,
          categoryId: edits['categoryId'] as String?,
        );

        if (!mounted) {
          return;
        }

        if (response['success'] == true) {
          _showMessage(response['message'] ?? 'Video updated');
          await _loadAll();
        } else {
          _showMessage(response['message'] ?? 'Failed to update video');
        }
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showMessage('Failed to update video: $error');
      }
    });
  }

  Future<void> _toggleVideoVisibility(Map<String, dynamic> video) async {
    final isVisible = _isVideoVisible(video);
    final confirmed = await _confirmAction(
      title: isVisible ? 'Deactivate video?' : 'Activate video?',
      message: isVisible
          ? 'This video will no longer be visible to the public.'
          : 'This video will be visible to the public again.',
      confirmLabel: isVisible ? 'Deactivate' : 'Activate',
      destructive: isVisible,
    );

    if (!confirmed) {
      return;
    }

    final busyKey = 'video:${video['id']}';
    await _runBusyAction(busyKey, () async {
      try {
        final response = await _apiService.updateAdminVideo(
          videoId: '${video['id']}',
          status: isVisible ? 'PRIVATE' : 'PUBLIC',
        );

        if (!mounted) {
          return;
        }

        if (response['success'] == true) {
          _showMessage(response['message'] ?? 'Video updated');
          await _loadAll();
        } else {
          _showMessage(response['message'] ?? 'Failed to update video');
        }
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showMessage('Failed to update video: $error');
      }
    });
  }

  Future<void> _deleteVideo(Map<String, dynamic> video) async {
    final confirmed = await _confirmAction(
      title: 'Delete video?',
      message:
          'Delete "${video['title'] ?? 'this video'}" permanently? This action cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );

    if (!confirmed) {
      return;
    }

    final busyKey = 'video:${video['id']}';
    await _runBusyAction(busyKey, () async {
      try {
        final response = await _apiService.deleteAdminVideo('${video['id']}');

        if (!mounted) {
          return;
        }

        if (response['success'] == true) {
          _showMessage(response['message'] ?? 'Video deleted');
          await _loadAll();
        } else {
          _showMessage(response['message'] ?? 'Failed to delete video');
        }
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showMessage('Failed to delete video: $error');
      }
    });
  }

  Future<void> _updateContentProtectionSetting(bool enabled) async {
    const busyKey = 'app-settings';

    await _runBusyAction(busyKey, () async {
      try {
        final response = await _apiService.updateAdminAppSettings(
          contentProtectionEnabled: enabled,
        );

        if (!mounted) {
          return;
        }

        if (response['success'] == true) {
          final updatedSettings = Map<String, dynamic>.from(
            response['data'] as Map? ??
                <String, dynamic>{'contentProtectionEnabled': enabled},
          );

          setState(() {
            _dashboard = <String, dynamic>{
              ..._dashboard,
              'appSettings': updatedSettings,
            };
          });

          await ContentProtectionService.instance.setEnabled(
            updatedSettings['contentProtectionEnabled'] == true,
          );
          _showMessage(response['message'] ?? 'App settings updated');
        } else {
          _showMessage(response['message'] ?? 'Failed to update app settings');
        }
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showMessage('Failed to update app settings: $error');
      }
    });
  }

  Future<void> _createForum() async {
    final values = await _showForumEditorDialog();
    if (values == null) {
      return;
    }

    await _runBusyAction('forum:create', () async {
      try {
        final response = await _apiService.createAdminForum(
          title: values['title'] as String,
          subtitle: values['subtitle'] as String,
          description: values['description'] as String?,
          slug: values['slug'] as String?,
          keywords: values['keywords'] as List<String>?,
          isHot: values['isHot'] as bool?,
          sortOrder: values['sortOrder'] as int?,
          accentStart: values['accentStart'] as String?,
          accentEnd: values['accentEnd'] as String?,
        );

        if (!mounted) {
          return;
        }

        if (response['success'] == true) {
          _showMessage(response['message'] ?? 'Forum created');
          await _loadAll();
        } else {
          _showMessage(response['message'] ?? 'Failed to create forum');
        }
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showMessage('Failed to create forum: $error');
      }
    });
  }

  Future<void> _editForum(Map<String, dynamic> forum) async {
    final edits = await _showForumEditorDialog(forum: forum);
    if (edits == null) {
      return;
    }

    final busyKey = 'forum:${forum['id']}';
    await _runBusyAction(busyKey, () async {
      try {
        final response = await _apiService.updateAdminForum(
          forumId: '${forum['id']}',
          title: edits['title'] as String?,
          subtitle: edits['subtitle'] as String?,
          description: edits['description'] as String?,
          slug: edits['slug'] as String?,
          keywords: edits['keywords'] as List<String>?,
          isHot: edits['isHot'] as bool?,
          sortOrder: edits['sortOrder'] as int?,
          accentStart: edits['accentStart'] as String?,
          accentEnd: edits['accentEnd'] as String?,
        );

        if (!mounted) {
          return;
        }

        if (response['success'] == true) {
          _showMessage(response['message'] ?? 'Forum updated');
          await _loadAll();
        } else {
          _showMessage(response['message'] ?? 'Failed to update forum');
        }
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showMessage('Failed to update forum: $error');
      }
    });
  }

  Future<void> _deleteForum(Map<String, dynamic> forum) async {
    final confirmed = await _confirmAction(
      title: 'Delete forum?',
      message:
          'Delete "${forum['title'] ?? 'this forum'}" permanently? Posts will remain but lose their forum assignment.',
      confirmLabel: 'Delete',
      destructive: true,
    );

    if (!confirmed) {
      return;
    }

    final busyKey = 'forum:${forum['id']}';
    await _runBusyAction(busyKey, () async {
      try {
        final response = await _apiService.deleteAdminForum('${forum['id']}');

        if (!mounted) {
          return;
        }

        if (response['success'] == true) {
          _showMessage(response['message'] ?? 'Forum deleted');
          await _loadAll();
        } else {
          _showMessage(response['message'] ?? 'Failed to delete forum');
        }
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showMessage('Failed to delete forum: $error');
      }
    });
  }

  Future<void> _editCategory(Map<String, dynamic> category) async {
    final edits = await _showCategoryEditor(category);
    if (edits == null) {
      return;
    }

    final busyKey = 'category:${category['id']}';
    await _runBusyAction(busyKey, () async {
      try {
        final response = await _apiService.updateAdminCategory(
          categoryId: '${category['id']}',
          categoryName: edits['categoryName'] as String?,
          categoryDesc: edits['categoryDesc'] as String?,
          categoryOrder: edits['categoryOrder'] as int?,
        );

        if (!mounted) {
          return;
        }

        if (response['success'] == true) {
          _showMessage(response['message'] ?? 'Category updated');
          await _loadAll();
        } else {
          _showMessage(response['message'] ?? 'Failed to update category');
        }
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showMessage('Failed to update category: $error');
      }
    });
  }

  Future<void> _deleteCategory(Map<String, dynamic> category) async {
    final confirmed = await _confirmAction(
      title: 'Delete category?',
      message:
          'Delete "${category['categoryName'] ?? 'this category'}" permanently? Categories with subcategories or videos cannot be deleted.',
      confirmLabel: 'Delete',
      destructive: true,
    );

    if (!confirmed) {
      return;
    }

    final busyKey = 'category:${category['id']}';
    await _runBusyAction(busyKey, () async {
      try {
        final response =
            await _apiService.deleteAdminCategory('${category['id']}');

        if (!mounted) {
          return;
        }

        if (response['success'] == true) {
          _showMessage(response['message'] ?? 'Category deleted');
          await _loadAll();
        } else {
          _showMessage(response['message'] ?? 'Failed to delete category');
        }
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showMessage('Failed to delete category: $error');
      }
    });
  }

  Future<void> _createVideo() async {
    await context.push('/main/upload');

    if (!mounted) {
      return;
    }

    await _loadAll();
  }

  Future<void> _createCategory() async {
    final values = await _showCreateCategoryDialog();
    if (values == null) {
      return;
    }

    await _runBusyAction('category:create', () async {
      try {
        final response = await _apiService.createAdminCategory(
          categoryName: values['categoryName'] as String,
          categoryDesc: values['categoryDesc'] as String?,
          categoryOrder: values['categoryOrder'] as int?,
          parentId: values['parentId'] as String?,
        );

        if (!mounted) {
          return;
        }

        if (response['success'] == true) {
          _showMessage(response['message'] ?? 'Category created');
          await _loadAll();
        } else {
          _showMessage(response['message'] ?? 'Failed to create category');
        }
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showMessage('Failed to create category: $error');
      }
    });
  }

  Future<void> _createUser() async {
    final values = await _showCreateUserDialog();
    if (values == null) {
      return;
    }

    await _runBusyAction('user:create', () async {
      try {
        final response = await _apiService.createAdminUser(
          username: values['username'] as String,
          email: values['email'] as String,
          password: values['password'] as String,
          firstName: values['firstName'] as String?,
          lastName: values['lastName'] as String?,
          role: values['role'] as String?,
          isVerified: values['isVerified'] as bool?,
          isActive: values['isActive'] as bool?,
        );

        if (!mounted) {
          return;
        }

        if (response['success'] == true) {
          _showMessage(response['message'] ?? 'User created');
          await _loadAll();
        } else {
          _showMessage(response['message'] ?? 'Failed to create user');
        }
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showMessage('Failed to create user: $error');
      }
    });
  }

  Future<void> _editUser(Map<String, dynamic> user) async {
    final edits = await _showUserEditor(user);
    if (edits == null) {
      return;
    }

    final busyKey = 'user:${user['id']}';
    await _runBusyAction(busyKey, () async {
      try {
        final response = await _apiService.updateAdminUser(
          userId: '${user['id']}',
          username: edits['username'] as String?,
          firstName: edits['firstName'] as String?,
          lastName: edits['lastName'] as String?,
          isVerified: edits['isVerified'] as bool?,
          isActive: edits['isActive'] as bool?,
          role: edits['role'] as String?,
        );

        if (!mounted) {
          return;
        }

        if (response['success'] == true) {
          _showMessage(response['message'] ?? 'User updated');
          await _loadAll();
        } else {
          _showMessage(response['message'] ?? 'Failed to update user');
        }
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showMessage('Failed to update user: $error');
      }
    });
  }

  Future<void> _toggleUserStatus(Map<String, dynamic> user) async {
    final isActive = user['isActive'] != false;
    final confirmed = await _confirmAction(
      title: isActive ? 'Deactivate user?' : 'Activate user?',
      message: isActive
          ? 'This account will lose access until you reactivate it.'
          : 'This account will be able to sign in again.',
      confirmLabel: isActive ? 'Deactivate' : 'Activate',
      destructive: isActive,
    );

    if (!confirmed) {
      return;
    }

    final busyKey = 'user:${user['id']}';
    await _runBusyAction(busyKey, () async {
      try {
        final response = await _apiService.updateAdminUser(
          userId: '${user['id']}',
          isActive: !isActive,
        );

        if (!mounted) {
          return;
        }

        if (response['success'] == true) {
          _showMessage(response['message'] ?? 'User updated');
          await _loadAll();
        } else {
          _showMessage(response['message'] ?? 'Failed to update user');
        }
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showMessage('Failed to update user: $error');
      }
    });
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final confirmed = await _confirmAction(
      title: 'Delete user?',
      message:
          'Delete @${user['username'] ?? 'this user'} permanently? This action cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );

    if (!confirmed) {
      return;
    }

    final busyKey = 'user:${user['id']}';
    await _runBusyAction(busyKey, () async {
      try {
        final response = await _apiService.deleteAdminUser('${user['id']}');

        if (!mounted) {
          return;
        }

        if (response['success'] == true) {
          _showMessage(response['message'] ?? 'User deleted');
          await _loadAll();
        } else {
          _showMessage(response['message'] ?? 'Failed to delete user');
        }
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showMessage('Failed to delete user: $error');
      }
    });
  }

  Future<Map<String, dynamic>?> _showVideoEditor(
    Map<String, dynamic> video,
  ) async {
    final titleController = TextEditingController(
      text: '${video['title'] ?? ''}',
    );
    final descriptionController = TextEditingController(
      text: '${video['description'] ?? ''}',
    );
    var selectedStatus = '${video['status'] ?? 'PUBLIC'}'.toUpperCase();
    var selectedCategoryId = '${video['categoryId'] ?? ''}';

    final availableCategoryIds = _flatCategories
        .map((category) => '${category['id'] ?? ''}')
        .where((id) => id.isNotEmpty)
        .toSet();

    if (selectedCategoryId.isNotEmpty &&
        !availableCategoryIds.contains(selectedCategoryId)) {
      selectedCategoryId = '';
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Edit video'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'PUBLIC', child: Text('Public')),
                    DropdownMenuItem(value: 'VIP', child: Text('VIP')),
                    DropdownMenuItem(
                      value: 'PRIVATE',
                      child: Text('Private'),
                    ),
                    DropdownMenuItem(
                      value: 'UNLISTED',
                      child: Text('Unlisted'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setDialogState(() {
                      selectedStatus = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('No category'),
                    ),
                    ..._flatCategories.map(
                      (category) => DropdownMenuItem(
                        value: '${category['id'] ?? ''}',
                        child: Text(_categoryDisplayName(category)),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      selectedCategoryId = value ?? '';
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'title': titleController.text.trim(),
                'description': descriptionController.text.trim(),
                'status': selectedStatus,
                'categoryId':
                    selectedCategoryId.isEmpty ? null : selectedCategoryId,
              }),
              child: const Text('Save changes'),
            ),
          ],
        ),
      ),
    );

    titleController.dispose();
    descriptionController.dispose();
    return result;
  }

  Future<Map<String, dynamic>?> _showForumEditorDialog({
    Map<String, dynamic>? forum,
  }) async {
    final titleController = TextEditingController(
      text: '${forum?['title'] ?? ''}',
    );
    final subtitleController = TextEditingController(
      text: '${forum?['subtitle'] ?? ''}',
    );
    final descriptionController = TextEditingController(
      text: '${forum?['description'] ?? ''}',
    );
    final slugController = TextEditingController(
      text: '${forum?['slug'] ?? ''}',
    );
    final keywordsController = TextEditingController(
      text: List<String>.from(forum?['keywords'] as List? ?? const [])
          .join(', '),
    );
    final orderController = TextEditingController(
      text: '${forum?['sortOrder'] ?? _forums.length}',
    );
    final accentStartController = TextEditingController(
      text: '${forum?['accentStart'] ?? '#4F7DFF'}',
    );
    final accentEndController = TextEditingController(
      text: '${forum?['accentEnd'] ?? '#5FD4FF'}',
    );
    var isHot = forum?['isHot'] == true;
    String? validationMessage;
    final isEditing = forum != null;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Edit forum' : 'Create forum'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Forum title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: subtitleController,
                  decoration: const InputDecoration(
                    labelText: 'Subtitle',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: slugController,
                  decoration: const InputDecoration(
                    labelText: 'Slug',
                    helperText: 'Optional. Leave blank to derive from the title.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: keywordsController,
                  decoration: const InputDecoration(
                    labelText: 'Keywords',
                    helperText: 'Separate keywords with commas.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: orderController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Sort order',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: accentStartController,
                  decoration: const InputDecoration(
                    labelText: 'Accent start',
                    helperText: 'Hex color like #4F7DFF',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: accentEndController,
                  decoration: const InputDecoration(
                    labelText: 'Accent end',
                    helperText: 'Hex color like #5FD4FF',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  value: isHot,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show in Hot Forums'),
                  onChanged: (value) {
                    setDialogState(() {
                      isHot = value;
                    });
                  },
                ),
                if (validationMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      validationMessage!,
                      style: TextStyle(
                        color: Theme.of(dialogContext).colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final title = titleController.text.trim();
                final subtitle = subtitleController.text.trim();
                if (title.isEmpty || subtitle.isEmpty) {
                  setDialogState(() {
                    validationMessage = 'Title and subtitle are required.';
                  });
                  return;
                }

                Navigator.pop(dialogContext, {
                  'title': title,
                  'subtitle': subtitle,
                  'description': descriptionController.text.trim(),
                  'slug': slugController.text.trim().isEmpty
                      ? null
                      : slugController.text.trim(),
                  'keywords': keywordsController.text
                      .split(',')
                      .map((value) => value.trim())
                      .where((value) => value.isNotEmpty)
                      .toList(growable: false),
                  'sortOrder': int.tryParse(orderController.text.trim()) ?? 0,
                  'accentStart': accentStartController.text.trim(),
                  'accentEnd': accentEndController.text.trim(),
                  'isHot': isHot,
                });
              },
              child: Text(isEditing ? 'Save changes' : 'Create'),
            ),
          ],
        ),
      ),
    );

    titleController.dispose();
    subtitleController.dispose();
    descriptionController.dispose();
    slugController.dispose();
    keywordsController.dispose();
    orderController.dispose();
    accentStartController.dispose();
    accentEndController.dispose();
    return result;
  }

  Future<Map<String, dynamic>?> _showCategoryEditor(
    Map<String, dynamic> category,
  ) async {
    final nameController = TextEditingController(
      text: '${category['categoryName'] ?? ''}',
    );
    final descriptionController = TextEditingController(
      text: '${category['categoryDesc'] ?? ''}',
    );
    final orderController = TextEditingController(
      text: '${category['categoryOrder'] ?? 0}',
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit category'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Category name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: orderController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Sort order',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, {
              'categoryName': nameController.text.trim(),
              'categoryDesc': descriptionController.text.trim(),
              'categoryOrder': int.tryParse(orderController.text.trim()) ?? 0,
            }),
            child: const Text('Save changes'),
          ),
        ],
      ),
    );

    nameController.dispose();
    descriptionController.dispose();
    orderController.dispose();
    return result;
  }

  Future<Map<String, dynamic>?> _showCreateCategoryDialog() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final orderController = TextEditingController(text: '$_nextCategoryOrder');
    var selectedParentId = '';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Create category'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Category name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedParentId,
                  decoration: const InputDecoration(
                    labelText: 'Parent category',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Top level'),
                    ),
                    ..._flatCategories.map(
                      (category) => DropdownMenuItem(
                        value: '${category['id'] ?? ''}',
                        child: Text(_categoryDisplayName(category)),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      selectedParentId = value ?? '';
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: orderController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Sort order',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'categoryName': nameController.text.trim(),
                'categoryDesc': descriptionController.text.trim(),
                'parentId': selectedParentId.isEmpty ? null : selectedParentId,
                'categoryOrder': int.tryParse(orderController.text.trim()) ?? 0,
              }),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    descriptionController.dispose();
    orderController.dispose();
    return result;
  }

  Future<Map<String, dynamic>?> _showUserEditor(
    Map<String, dynamic> user,
  ) async {
    final usernameController = TextEditingController(
      text: '${user['username'] ?? ''}',
    );
    final firstNameController = TextEditingController(
      text: '${user['firstName'] ?? ''}',
    );
    final lastNameController = TextEditingController(
      text: '${user['lastName'] ?? ''}',
    );
    var isVerified = user['isVerified'] == true;
    var isActive = user['isActive'] != false;
    var role = '${user['role'] ?? 'USER'}'.toUpperCase();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Edit user'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${user['email'] ?? 'No email'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: firstNameController,
                  decoration: const InputDecoration(
                    labelText: 'First name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lastNameController,
                  decoration: const InputDecoration(
                    labelText: 'Last name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'USER', child: Text('User')),
                    DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setDialogState(() {
                      role = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Verified account'),
                  value: isVerified,
                  onChanged: (value) {
                    setDialogState(() {
                      isVerified = value;
                    });
                  },
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Account active'),
                  value: isActive,
                  onChanged: (value) {
                    setDialogState(() {
                      isActive = value;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'username': usernameController.text.trim(),
                'firstName': firstNameController.text.trim(),
                'lastName': lastNameController.text.trim(),
                'isVerified': isVerified,
                'isActive': isActive,
                'role': role,
              }),
              child: const Text('Save changes'),
            ),
          ],
        ),
      ),
    );

    usernameController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    return result;
  }

  Future<Map<String, dynamic>?> _showCreateUserDialog() async {
    final usernameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    var isVerified = true;
    var isActive = true;
    var role = 'USER';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Create user'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Temporary password',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: firstNameController,
                  decoration: const InputDecoration(
                    labelText: 'First name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lastNameController,
                  decoration: const InputDecoration(
                    labelText: 'Last name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'USER', child: Text('User')),
                    DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setDialogState(() {
                      role = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Verified account'),
                  value: isVerified,
                  onChanged: (value) {
                    setDialogState(() {
                      isVerified = value;
                    });
                  },
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Account active'),
                  value: isActive,
                  onChanged: (value) {
                    setDialogState(() {
                      isActive = value;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'username': usernameController.text.trim(),
                'email': emailController.text.trim(),
                'password': passwordController.text,
                'firstName': firstNameController.text.trim(),
                'lastName': lastNameController.text.trim(),
                'role': role,
                'isVerified': isVerified,
                'isActive': isActive,
              }),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    return result;
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  )
                : null,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );

    return result == true;
  }

  Future<String?> _promptForText({
    required String title,
    required String hintText,
    required String actionLabel,
  }) async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 6,
          decoration: InputDecoration(
            hintText: hintText,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(actionLabel),
          ),
        ],
      ),
    );

    controller.dispose();
    return result;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  bool _isVideoVisible(Map<String, dynamic> video) {
    final status = '${video['status'] ?? ''}'.toUpperCase();
    return video['isPublic'] == true &&
        status != 'PRIVATE' &&
        status != 'UNLISTED';
  }

  String _categoryDisplayName(Map<String, dynamic> category) {
    final depth = category['depth'] as int? ?? 0;
    final name = '${category['categoryName'] ?? 'Unnamed category'}';
    final parentName = '${category['parentName'] ?? ''}'.trim();

    if (depth == 0 || parentName.isEmpty) {
      return name;
    }

    return '$parentName / $name';
  }

  String _userDisplayName(Map<String, dynamic> user) {
    final parts = [
      '${user['firstName'] ?? ''}'.trim(),
      '${user['lastName'] ?? ''}'.trim(),
    ].where((part) => part.isNotEmpty).toList();

    return parts.isEmpty ? 'No display name set' : parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(authServiceProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isAdmin = authService.isAdmin;

    return DefaultTabController(
      initialIndex: _initialTabIndex,
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          title: const Text('Management Dashboard'),
          actions: [
            IconButton(
              onPressed: _loadAll,
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            labelColor: colorScheme.onPrimary,
            unselectedLabelColor: colorScheme.onPrimary.withValues(alpha: 0.78),
            indicatorColor: colorScheme.onPrimary,
            dividerColor: Colors.transparent,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700),
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Videos'),
              Tab(text: 'Forums'),
              Tab(text: 'Categories'),
              Tab(text: 'Users'),
              Tab(text: 'Reports'),
              Tab(text: 'Feedback'),
            ],
          ),
        ),
        body: !isAdmin
            ? _buildRestrictedView()
            : _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildErrorView()
                    : TabBarView(
                        children: [
                          _buildOverviewTab(),
                          _buildVideosTab(),
                          _buildForumsTab(),
                          _buildCategoriesTab(),
                          _buildUsersTab(),
                          _buildReportsTab(),
                          _buildFeedbackTab(),
                        ],
                      ),
      ),
    );
  }

  Widget _buildRestrictedView() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.admin_panel_settings_outlined, size: 56),
            SizedBox(height: 16),
            Text(
              'Admin access required',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 8),
            Text(
              'This screen is only available to administrator accounts.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Unable to load admin data',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadAll,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    final statistics = Map<String, dynamic>.from(
      _dashboard['statistics'] as Map? ?? const {},
    );
    final moderation = Map<String, dynamic>.from(
      _dashboard['moderation'] as Map? ?? const {},
    );
    final appSettings = Map<String, dynamic>.from(
      _dashboard['appSettings'] as Map? ?? const {},
    );
    final recentFeedback = List<Map<String, dynamic>>.from(
      _dashboard['recentFeedback'] as List? ?? const [],
    );
    final metrics = <_DashboardMetric>[
      _DashboardMetric(
        label: 'Users',
        value: statistics['totalUsers'] ?? 0,
        icon: Icons.people_outline,
        color: Colors.blue,
      ),
      _DashboardMetric(
        label: 'Videos',
        value: statistics['totalVideos'] ?? 0,
        icon: Icons.play_circle_outline,
        color: Colors.red,
      ),
      _DashboardMetric(
        label: 'Categories',
        value: statistics['totalCategories'] ?? 0,
        icon: Icons.category_outlined,
        color: Colors.green,
      ),
      _DashboardMetric(
        label: 'Forums',
        value: statistics['totalForums'] ?? 0,
        icon: Icons.forum_outlined,
        color: Colors.indigo,
      ),
      _DashboardMetric(
        label: 'Posts',
        value: statistics['totalPosts'] ?? 0,
        icon: Icons.forum_outlined,
        color: Colors.orange,
      ),
      _DashboardMetric(
        label: 'Pending Reports',
        value: moderation['pendingReports'] ?? 0,
        icon: Icons.flag_outlined,
        color: Colors.deepOrange,
      ),
      _DashboardMetric(
        label: 'Pending Feedback',
        value: moderation['pendingFeedback'] ?? 0,
        icon: Icons.feedback_outlined,
        color: Colors.teal,
      ),
    ];

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth >= 880 ? 3 : 2;
              final childAspectRatio = constraints.maxWidth < 380
                  ? 0.82
                  : constraints.maxWidth < 600
                      ? 1.02
                      : 1.45;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: metrics.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: childAspectRatio,
                ),
                itemBuilder: (context, index) {
                  return _buildMetricCard(metrics[index]);
                },
              );
            },
          ),
          const SizedBox(height: 24),
          Card(
            child: SwitchListTile.adaptive(
              secondary: _isBusy('app-settings')
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.shield_outlined),
              title: const Text('Screen capture protection'),
              subtitle: const Text(
                'Blocks screenshots and recording on Android and applies best-effort masking on iOS for protected content.',
              ),
              value: appSettings['contentProtectionEnabled'] == true,
              onChanged: _isBusy('app-settings')
                  ? null
                  : _updateContentProtectionSetting,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Recent feedback',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          if (recentFeedback.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No feedback has been submitted yet.'),
              ),
            )
          else
            ...recentFeedback.map(_buildRecentFeedbackCard),
        ],
      ),
    );
  }

  Widget _buildMetricCard(_DashboardMetric metric) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: metric.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(metric.icon, color: metric.color),
            ),
            const SizedBox(height: 16),
            Text(
              '${metric.value}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Flexible(
              child: Text(
                metric.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentFeedbackCard(Map<String, dynamic> entry) {
    final user = Map<String, dynamic>.from(entry['user'] as Map? ?? const {});

    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.feedback_outlined),
        ),
        title: Text('${entry['subject'] ?? 'General feedback'}'),
        subtitle: Text(
          '${user['username'] ?? 'Unknown'}\n${entry['message'] ?? ''}',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildVideosTab() {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _buildTabActionBar(
            title: 'Videos',
            createLabel: 'Create video',
            createIcon: Icons.add_circle_outline,
            onCreate: _createVideo,
          ),
          const SizedBox(height: 12),
          if (_videos.isEmpty)
            _buildInlineEmptyCard('No videos available')
          else
            ..._videos.map((video) {
              final user = Map<String, dynamic>.from(
                video['user'] as Map? ?? const {},
              );
              final category = Map<String, dynamic>.from(
                video['category'] as Map? ?? const {},
              );
              final busyKey = 'video:${video['id']}';
              final isVisible = _isVideoVisible(video);
              final description = '${video['description'] ?? ''}'.trim();

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const CircleAvatar(
                              child: Icon(Icons.play_arrow),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${video['title'] ?? 'Untitled video'}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _buildStatusChip(
                                        '${video['status'] ?? 'PUBLIC'}',
                                      ),
                                      _buildStatusChip(
                                        isVisible ? 'ACTIVE' : 'HIDDEN',
                                      ),
                                      if ('${category['categoryName'] ?? ''}'
                                          .isNotEmpty)
                                        _buildInfoChip(
                                          '${category['categoryName']}',
                                          Icons.category_outlined,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('Creator: ${user['username'] ?? 'Unknown'}'),
                        const SizedBox(height: 4),
                        Text(
                          'Views ${video['views'] ?? 0} • Likes ${video['likes'] ?? 0} • Shares ${video['shares'] ?? 0}',
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            description,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 16),
                        _buildResponsiveActions(
                          children: [
                            FilledButton.tonal(
                              onPressed: _isBusy(busyKey)
                                  ? null
                                  : () => _editVideo(video),
                              child: const Text('Edit'),
                            ),
                            FilledButton.tonal(
                              onPressed: _isBusy(busyKey)
                                  ? null
                                  : () => _toggleVideoVisibility(video),
                              child: Text(
                                isVisible ? 'Deactivate' : 'Activate',
                              ),
                            ),
                            OutlinedButton(
                              onPressed: _isBusy(busyKey)
                                  ? null
                                  : () => _deleteVideo(video),
                              style: OutlinedButton.styleFrom(
                                foregroundColor:
                                    Theme.of(context).colorScheme.error,
                              ),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildForumsTab() {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _buildTabActionBar(
            title: 'Forums',
            createLabel: 'Create forum',
            createIcon: Icons.forum_outlined,
            onCreate: _createForum,
          ),
          const SizedBox(height: 12),
          if (_forums.isEmpty)
            _buildInlineEmptyCard('No forums available')
          else
            ..._forums.map((forum) {
              final busyKey = 'forum:${forum['id']}';
              final keywords = List<String>.from(
                forum['keywords'] as List? ?? const [],
              );
              final description = '${forum['description'] ?? ''}'.trim();

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const CircleAvatar(
                              child: Icon(Icons.forum_outlined),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${forum['title'] ?? 'Untitled forum'}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${forum['subtitle'] ?? ''}',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _buildInfoChip(
                                        '${forum['postCount'] ?? 0} posts',
                                        Icons.article_outlined,
                                      ),
                                      _buildInfoChip(
                                        '${forum['followerCount'] ?? 0} followers',
                                        Icons.people_outline,
                                      ),
                                      _buildInfoChip(
                                        'Order ${forum['sortOrder'] ?? 0}',
                                        Icons.sort,
                                      ),
                                      if (forum['isHot'] == true)
                                        _buildStatusChip('HOT'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('Slug: ${forum['slug'] ?? '-'}'),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(description),
                        ],
                        if (keywords.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: keywords
                                .map(
                                  (keyword) => _buildInfoChip(
                                    keyword,
                                    Icons.tag_outlined,
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ],
                        const SizedBox(height: 16),
                        _buildResponsiveActions(
                          children: [
                            FilledButton.tonal(
                              onPressed: _isBusy(busyKey)
                                  ? null
                                  : () => _editForum(forum),
                              child: const Text('Edit'),
                            ),
                            OutlinedButton(
                              onPressed: _isBusy(busyKey)
                                  ? null
                                  : () => _deleteForum(forum),
                              style: OutlinedButton.styleFrom(
                                foregroundColor:
                                    Theme.of(context).colorScheme.error,
                              ),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildCategoriesTab() {
    final categories = _flatCategories;

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _buildTabActionBar(
            title: 'Categories',
            createLabel: 'Create category',
            createIcon: Icons.create_new_folder_outlined,
            onCreate: _createCategory,
          ),
          const SizedBox(height: 12),
          if (categories.isEmpty)
            _buildInlineEmptyCard('No categories available')
          else
            ...categories.map((category) {
              final busyKey = 'category:${category['id']}';
              final description = '${category['categoryDesc'] ?? ''}'.trim();
              final videoCount = category['videoCount'] ?? 0;
              final childCount = category['childCount'] ?? 0;
              final isDefault = category['isDefault'] == true;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              child: Icon(
                                (category['depth'] as int? ?? 0) > 0
                                    ? Icons.subdirectory_arrow_right
                                    : Icons.category_outlined,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _categoryDisplayName(category),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _buildInfoChip(
                                        '$videoCount videos',
                                        Icons.play_arrow_outlined,
                                      ),
                                      _buildInfoChip(
                                        '$childCount subcategories',
                                        Icons.account_tree_outlined,
                                      ),
                                      _buildInfoChip(
                                        'Order ${category['categoryOrder'] ?? 0}',
                                        Icons.sort,
                                      ),
                                      if (isDefault)
                                        _buildStatusChip('DEFAULT'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(description),
                        ],
                        const SizedBox(height: 16),
                        _buildResponsiveActions(
                          children: [
                            FilledButton.tonal(
                              onPressed: _isBusy(busyKey)
                                  ? null
                                  : () => _editCategory(category),
                              child: const Text('Edit'),
                            ),
                            OutlinedButton(
                              onPressed: _isBusy(busyKey)
                                  ? null
                                  : () => _deleteCategory(category),
                              style: OutlinedButton.styleFrom(
                                foregroundColor:
                                    Theme.of(context).colorScheme.error,
                              ),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _buildTabActionBar(
            title: 'Users',
            createLabel: 'Create user',
            createIcon: Icons.person_add_alt_1,
            onCreate: _createUser,
          ),
          const SizedBox(height: 12),
          if (_users.isEmpty)
            _buildInlineEmptyCard('No users available')
          else
            ..._users.map((user) {
              final busyKey = 'user:${user['id']}';
              final isActive = user['isActive'] != false;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              child: Text(
                                ('${user['username'] ?? 'U'}')
                                    .characters
                                    .first
                                    .toUpperCase(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '@${user['username'] ?? 'unknown'}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(_userDisplayName(user)),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _buildStatusChip(
                                        '${user['role'] ?? 'USER'}',
                                      ),
                                      _buildStatusChip(
                                        isActive ? 'ACTIVE' : 'INACTIVE',
                                      ),
                                      if (user['isVerified'] == true)
                                        _buildStatusChip('VERIFIED'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('${user['email'] ?? 'No email'}'),
                        const SizedBox(height: 4),
                        Text(
                          '${user['videoCount'] ?? 0} videos • ${user['postCount'] ?? 0} posts',
                        ),
                        const SizedBox(height: 16),
                        _buildResponsiveActions(
                          children: [
                            FilledButton.tonal(
                              onPressed: _isBusy(busyKey)
                                  ? null
                                  : () => _editUser(user),
                              child: const Text('Edit'),
                            ),
                            FilledButton.tonal(
                              onPressed: _isBusy(busyKey)
                                  ? null
                                  : () => _toggleUserStatus(user),
                              child: Text(
                                isActive ? 'Deactivate' : 'Activate',
                              ),
                            ),
                            OutlinedButton(
                              onPressed: _isBusy(busyKey)
                                  ? null
                                  : () => _deleteUser(user),
                              style: OutlinedButton.styleFrom(
                                foregroundColor:
                                    Theme.of(context).colorScheme.error,
                              ),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildReportsTab() {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: _reports.isEmpty
          ? _buildEmptyList('No reports to review')
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: _reports.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final report = _reports[index];
                final reporter = Map<String, dynamic>.from(
                  report['reporter'] as Map? ?? const {},
                );
                final target = Map<String, dynamic>.from(
                  report['target'] as Map? ?? const {},
                );
                final busyKey = 'report:${report['id']}';
                final targetTitle = report['type'] == 'user'
                    ? '${target['username'] ?? 'Unknown user'}'
                    : '${target['title'] ?? 'Untitled'}';

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildStatusChip('${report['type'] ?? 'report'}'),
                            _buildStatusChip(
                                '${report['status'] ?? 'PENDING'}'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          targetTitle,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text('Reporter: ${reporter['username'] ?? 'Unknown'}'),
                        const SizedBox(height: 4),
                        Text('Reason: ${report['reason'] ?? 'Unspecified'}'),
                        if ((report['description'] ?? '').toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('Details: ${report['description']}'),
                          ),
                        if ((report['adminReply'] ?? '').toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('Admin note: ${report['adminReply']}'),
                          ),
                        const SizedBox(height: 16),
                        _buildResponsiveActions(
                          children: [
                            FilledButton.tonal(
                              onPressed: _isBusy(busyKey)
                                  ? null
                                  : () => _updateReport(report, 'approve'),
                              child: const Text('Approve'),
                            ),
                            FilledButton.tonal(
                              onPressed: _isBusy(busyKey)
                                  ? null
                                  : () => _updateReport(report, 'deny'),
                              child: const Text('Deny'),
                            ),
                            OutlinedButton(
                              onPressed: _isBusy(busyKey)
                                  ? null
                                  : () => _replyToReport(report),
                              child: const Text('Reply'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildFeedbackTab() {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: _feedbackEntries.isEmpty
          ? _buildEmptyList('No feedback entries yet')
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: _feedbackEntries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final entry = _feedbackEntries[index];
                final user = Map<String, dynamic>.from(
                  entry['user'] as Map? ?? const {},
                );
                final busyKey = 'feedback:${entry['id']}';

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${entry['subject'] ?? 'General feedback'}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            _buildStatusChip('${entry['status'] ?? 'PENDING'}'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('From: ${user['username'] ?? 'Unknown'}'),
                        const SizedBox(height: 8),
                        Text('${entry['message'] ?? ''}'),
                        if ((entry['adminReply'] ?? '').toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              'Reply: ${entry['adminReply']}',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        _buildResponsiveActions(
                          children: [
                            FilledButton.tonal(
                              onPressed: _isBusy(busyKey)
                                  ? null
                                  : () => _replyToFeedback(entry),
                              child: const Text('Reply'),
                            ),
                            OutlinedButton(
                              onPressed: _isBusy(busyKey)
                                  ? null
                                  : () => _updateFeedback(
                                        entry,
                                        status: 'DISMISSED',
                                      ),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyList(String message) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 160),
        Center(child: Text(message)),
      ],
    );
  }

  Widget _buildInlineEmptyCard(String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message),
      ),
    );
  }

  Widget _buildTabActionBar({
    required String title,
    required String createLabel,
    required IconData createIcon,
    required VoidCallback onCreate,
  }) {
    return Wrap(
      runSpacing: 12,
      spacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        FilledButton.icon(
          onPressed: onCreate,
          icon: Icon(createIcon),
          label: Text(createLabel),
        ),
      ],
    );
  }

  Widget _buildResponsiveActions({required List<Widget> children}) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: children,
    );
  }

  Widget _buildInfoChip(String label, IconData icon) {
    final color = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label) {
    final color = _statusColor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'RESOLVED':
      case 'APPROVED':
      case 'PUBLIC':
      case 'ACTIVE':
      case 'VERIFIED':
        return Colors.green;
      case 'DISMISSED':
      case 'DENY':
      case 'PRIVATE':
      case 'INACTIVE':
      case 'HIDDEN':
        return Colors.red;
      case 'REVIEWED':
      case 'ADMIN':
        return Colors.blue;
      case 'VIP':
        return Colors.indigo;
      case 'UNLISTED':
        return Colors.brown;
      case 'VIDEO':
        return Colors.deepOrange;
      case 'POST':
        return Colors.purple;
      case 'USER':
      case 'FEEDBACK':
        return Colors.teal;
      case 'DEFAULT':
        return Colors.orange;
      default:
        return Colors.orange;
    }
  }
}

class _DashboardMetric {
  final String label;
  final Object value;
  final IconData icon;
  final Color color;

  const _DashboardMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

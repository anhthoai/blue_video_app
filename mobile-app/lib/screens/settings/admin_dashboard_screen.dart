import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/content_protection_service.dart';
import '../../core/services/version_service.dart';
import '../../l10n/app_localizations.dart';

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

  int _appSettingInt(Map<String, dynamic> appSettings, String key) {
    final value = appSettings[key];
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse('$value') ?? 0;
  }

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

  String _tr(String en, String vi) {
    final languageCode = Localizations.localeOf(context).languageCode;
    return languageCode == 'vi' ? vi : en;
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
          _showMessage(response['message'] ?? _tr('Report updated', 'Đã cập nhật báo cáo'));
          await _loadAll();
        } else {
          _showMessage(response['message'] ?? _tr('Failed to update report', 'Cập nhật báo cáo thất bại'));
        }
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showMessage('${_tr('Failed to update report', 'Cập nhật báo cáo thất bại')}: $error');
      }
    });
  }

  Future<void> _replyToReport(Map<String, dynamic> report) async {
    final reply = await _promptForText(
      title: _tr('Reply to report', 'Trả lời báo cáo'),
      hintText: _tr('Add a note for this review', 'Thêm ghi chú cho đánh giá này'),
      actionLabel: _tr('Send reply', 'Gửi phản hồi'),
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
          _showMessage(response['message'] ?? _tr('Feedback updated', 'Đã cập nhật phản hồi'));
          await _loadAll();
        } else {
          _showMessage(response['message'] ?? _tr('Failed to update feedback', 'Cập nhật phản hồi thất bại'));
        }
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showMessage('${_tr('Failed to update feedback', 'Cập nhật phản hồi thất bại')}: $error');
      }
    });
  }

  Future<void> _replyToFeedback(Map<String, dynamic> entry) async {
    final reply = await _promptForText(
      title: _tr('Reply to feedback', 'Trả lời phản hồi'),
      hintText: _tr('Write your response', 'Nhập nội dung phản hồi'),
      actionLabel: _tr('Send reply', 'Gửi phản hồi'),
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
          _showMessage(response['message'] ?? _tr('Video updated', 'Đã cập nhật video'));
          await _loadAll();
        } else {
          _showMessage(response['message'] ?? _tr('Failed to update video', 'Cập nhật video thất bại'));
        }
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showMessage('${_tr('Failed to update video', 'Cập nhật video thất bại')}: $error');
      }
    });
  }

  Future<void> _toggleVideoVisibility(Map<String, dynamic> video) async {
    final isVisible = _isVideoVisible(video);
    final confirmed = await _confirmAction(
      title: isVisible
          ? _tr('Deactivate video?', 'Ẩn video?')
          : _tr('Activate video?', 'Hiện video?'),
      message: isVisible
          ? _tr('This video will no longer be visible to the public.', 'Video này sẽ không còn hiển thị công khai.')
          : _tr('This video will be visible to the public again.', 'Video này sẽ hiển thị công khai trở lại.'),
      confirmLabel: isVisible ? _tr('Deactivate', 'Ẩn') : _tr('Activate', 'Hiện'),
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
          _showMessage(response['message'] ?? _tr('Video updated', 'Đã cập nhật video'));
          await _loadAll();
        } else {
          _showMessage(response['message'] ?? _tr('Failed to update video', 'Cập nhật video thất bại'));
        }
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showMessage('${_tr('Failed to update video', 'Cập nhật video thất bại')}: $error');
      }
    });
  }

  Future<void> _deleteVideo(Map<String, dynamic> video) async {
    final confirmed = await _confirmAction(
      title: _tr('Delete video?', 'Xóa video?'),
      message:
          '${_tr('Delete', 'Xóa')} "${video['title'] ?? _tr('this video', 'video này')}" ${_tr('permanently? This action cannot be undone.', 'vĩnh viễn? Hành động này không thể hoàn tác.')}',
      confirmLabel: _tr('Delete', 'Xóa'),
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
          _showMessage(response['message'] ?? _tr('Video deleted', 'Đã xóa video'));
          await _loadAll();
        } else {
          _showMessage(response['message'] ?? _tr('Failed to delete video', 'Xóa video thất bại'));
        }
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showMessage('${_tr('Failed to delete video', 'Xóa video thất bại')}: $error');
      }
    });
  }

  Future<void> _updateAppSettings({
    bool? contentProtectionEnabled,
    bool? datingEnabled,
    int? datingSearchRadiusKm,
    String? datingAiProvider,
    String? datingAiModel,
    String? datingAiApiKey,
    int? freeCommunityPostBonusCoins,
    int? freeVideoBonusCoins,
    int? libraryItemDownloadCoins,
  }) async {
    const busyKey = 'app-settings';

    await _runBusyAction(busyKey, () async {
      try {
        final response = await _apiService.updateAdminAppSettings(
          contentProtectionEnabled: contentProtectionEnabled,
          datingEnabled: datingEnabled,
          datingSearchRadiusKm: datingSearchRadiusKm,
          datingAiProvider: datingAiProvider,
          datingAiModel: datingAiModel,
          datingAiApiKey: datingAiApiKey,
          freeCommunityPostBonusCoins: freeCommunityPostBonusCoins,
          freeVideoBonusCoins: freeVideoBonusCoins,
          libraryItemDownloadCoins: libraryItemDownloadCoins,
        );

        if (!mounted) {
          return;
        }

        if (response['success'] == true) {
          final existingSettings = Map<String, dynamic>.from(
            _dashboard['appSettings'] as Map? ?? const {},
          );
          final updatedSettings = Map<String, dynamic>.from(
            response['data'] as Map? ??
                <String, dynamic>{
                  ...existingSettings,
                  if (contentProtectionEnabled != null)
                    'contentProtectionEnabled': contentProtectionEnabled,
                  if (datingEnabled != null) 'datingEnabled': datingEnabled,
                  if (datingSearchRadiusKm != null)
                    'datingSearchRadiusKm': datingSearchRadiusKm,
                  if (datingAiProvider != null)
                    'datingAiProvider': datingAiProvider,
                  if (datingAiModel != null) 'datingAiModel': datingAiModel,
                  if (datingAiApiKey != null)
                    'datingAiApiKeyConfigured': datingAiApiKey.trim().isNotEmpty,
                  if (freeCommunityPostBonusCoins != null)
                    'freeCommunityPostBonusCoins': freeCommunityPostBonusCoins,
                  if (freeVideoBonusCoins != null)
                    'freeVideoBonusCoins': freeVideoBonusCoins,
                  if (libraryItemDownloadCoins != null)
                    'libraryItemDownloadCoins': libraryItemDownloadCoins,
                },
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
          ref.read(datingEnabledProvider.notifier).state =
              updatedSettings['datingEnabled'] == true;
          _showMessage(response['message'] ?? _tr('App settings updated', 'Đã cập nhật cài đặt ứng dụng'));
        } else {
          _showMessage(response['message'] ?? _tr('Failed to update app settings', 'Cập nhật cài đặt ứng dụng thất bại'));
        }
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showMessage('${_tr('Failed to update app settings', 'Cập nhật cài đặt ứng dụng thất bại')}: $error');
      }
    });
  }

  Future<void> _updateContentProtectionSetting(bool enabled) async {
    await _updateAppSettings(contentProtectionEnabled: enabled);
  }

  Future<void> _updateDatingSetting(bool enabled) async {
    await _updateAppSettings(datingEnabled: enabled);
  }

  Future<void> _editDatingRadiusSettings(Map<String, dynamic> appSettings) async {
    final l10n = AppLocalizations.of(context);
    final radiusCtrl = TextEditingController(
      text: '${appSettings['datingSearchRadiusKm'] ?? 3}',
    );
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.searchRadius),
        content: TextField(
          controller: radiusCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: _tr('Max distance (km)', 'Khoảng cách tối đa (km)'),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(radiusCtrl.text.trim());
              Navigator.pop(ctx, v);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (result != null && result > 0) {
      await _updateAppSettings(datingSearchRadiusKm: result);
    }
  }

  Future<void> _editAiMatchingSettings(Map<String, dynamic> appSettings) async {
    final l10n = AppLocalizations.of(context);
    final providerCtrl = TextEditingController(
      text: '${appSettings['datingAiProvider'] ?? 'openai'}',
    );
    final modelCtrl = TextEditingController(
      text: '${appSettings['datingAiModel'] ?? 'gpt-4o-mini'}',
    );
    final apiKeyCtrl = TextEditingController();

    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.aiMatchingProvider),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: providerCtrl,
                decoration: InputDecoration(
                  labelText: _tr('Provider', 'Nhà cung cấp'),
                  helperText: _tr('Example: openai, gemini, anthropic', 'Ví dụ: openai, gemini, anthropic'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: modelCtrl,
                decoration: InputDecoration(
                  labelText: _tr('Model', 'Mô hình'),
                  helperText: _tr('Example: gpt-4o-mini', 'Ví dụ: gpt-4o-mini'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: apiKeyCtrl,
                obscureText: true,
                decoration: InputDecoration(
                    labelText: _tr('API Key (leave blank to keep current)', 'API Key (để trống để giữ key hiện tại)'),
                  helperText: appSettings['datingAiApiKeyMasked'] != null
                      ? '${_tr('Current key', 'Key hiện tại')}: ${appSettings['datingAiApiKeyMasked']}'
                      : _tr('No API key configured yet', 'Chưa cấu hình API key'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(<String, String>{
                  'datingAiProvider': providerCtrl.text.trim(),
                  'datingAiModel': modelCtrl.text.trim(),
                  'datingAiApiKey': apiKeyCtrl.text.trim(),
                });
              },
              child: Text(l10n.save),
            ),
          ],
        );
      },
    );

    providerCtrl.dispose();
    modelCtrl.dispose();
    apiKeyCtrl.dispose();

    if (values == null) {
      return;
    }

    if ((values['datingAiProvider'] ?? '').isEmpty ||
        (values['datingAiModel'] ?? '').isEmpty) {
      _showMessage(_tr('Provider and model are required', 'Cần nhập nhà cung cấp và mô hình'));
      return;
    }

    await _updateAppSettings(
      datingAiProvider: values['datingAiProvider'],
      datingAiModel: values['datingAiModel'],
      datingAiApiKey:
          (values['datingAiApiKey'] ?? '').isNotEmpty ? values['datingAiApiKey'] : null,
    );
  }

  Future<void> _editBonusCoinSettings(Map<String, dynamic> appSettings) async {
    final l10n = AppLocalizations.of(context);
    final postBonusController = TextEditingController(
      text: '${_appSettingInt(appSettings, 'freeCommunityPostBonusCoins')}',
    );
    final videoBonusController = TextEditingController(
      text: '${_appSettingInt(appSettings, 'freeVideoBonusCoins')}',
    );
    final libraryDownloadController = TextEditingController(
      text: '${_appSettingInt(appSettings, 'libraryItemDownloadCoins')}',
    );

    final values = await showDialog<Map<String, int>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.freeContentBonusCoins),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: postBonusController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _tr('Free post media bonus', 'Thưởng bài đăng media miễn phí'),
                  helperText: _tr('Coins awarded for free posts with images/videos', 'Số xu thưởng cho bài đăng miễn phí có ảnh/video'),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: videoBonusController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _tr('Free video upload bonus', 'Thưởng tải video miễn phí'),
                  helperText: _tr('Coins awarded for free public video uploads', 'Số xu thưởng cho video công khai miễn phí'),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: libraryDownloadController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _tr('Library download cost', 'Giá tải thư viện'),
                  helperText: _tr('Coins charged per library file download', 'Số xu tính cho mỗi lượt tải file thư viện'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final postBonus = int.tryParse(postBonusController.text.trim());
                final videoBonus = int.tryParse(videoBonusController.text.trim());
                final libraryDownloadCoins =
                    int.tryParse(libraryDownloadController.text.trim());
                if (postBonus == null ||
                    postBonus < 0 ||
                    videoBonus == null ||
                    videoBonus < 0 ||
                    libraryDownloadCoins == null ||
                    libraryDownloadCoins < 0) {
                  _showMessage(_tr('Enter non-negative whole numbers for all coin settings', 'Nhập số nguyên không âm cho tất cả thiết lập xu'));
                  return;
                }

                Navigator.of(context).pop(<String, int>{
                  'freeCommunityPostBonusCoins': postBonus,
                  'freeVideoBonusCoins': videoBonus,
                  'libraryItemDownloadCoins': libraryDownloadCoins,
                });
              },
              child: Text(l10n.save),
            ),
          ],
        );
      },
    );

    postBonusController.dispose();
    videoBonusController.dispose();
    libraryDownloadController.dispose();

    if (values == null) {
      return;
    }

    await _updateAppSettings(
      freeCommunityPostBonusCoins: values['freeCommunityPostBonusCoins'],
      freeVideoBonusCoins: values['freeVideoBonusCoins'],
      libraryItemDownloadCoins: values['libraryItemDownloadCoins'],
    );
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
          _showMessage(response['message'] ?? _tr('Forum created', 'Đã tạo diễn đàn'));
          await _loadAll();
        } else {
          _showMessage(response['message'] ?? _tr('Failed to create forum', 'Tạo diễn đàn thất bại'));
        }
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showMessage('${_tr('Failed to create forum', 'Tạo diễn đàn thất bại')}: $error');
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
          _showMessage(response['message'] ?? _tr('Forum updated', 'Đã cập nhật diễn đàn'));
          await _loadAll();
        } else {
          _showMessage(response['message'] ?? _tr('Failed to update forum', 'Cập nhật diễn đàn thất bại'));
        }
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showMessage('${_tr('Failed to update forum', 'Cập nhật diễn đàn thất bại')}: $error');
      }
    });
  }

  Future<void> _deleteForum(Map<String, dynamic> forum) async {
    final confirmed = await _confirmAction(
      title: _tr('Delete forum?', 'Xóa diễn đàn?'),
      message:
          '${_tr('Delete', 'Xóa')} "${forum['title'] ?? _tr('this forum', 'diễn đàn này')}" ${_tr('permanently? Posts will remain but lose their forum assignment.', 'vĩnh viễn? Bài viết sẽ còn nhưng mất gắn kết với diễn đàn.')}',
      confirmLabel: _tr('Delete', 'Xóa'),
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
          _showMessage(response['message'] ?? _tr('Forum deleted', 'Đã xóa diễn đàn'));
          await _loadAll();
        } else {
          _showMessage(response['message'] ?? _tr('Failed to delete forum', 'Xóa diễn đàn thất bại'));
        }
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showMessage('${_tr('Failed to delete forum', 'Xóa diễn đàn thất bại')}: $error');
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
          _showMessage(response['message'] ?? _tr('Category updated', 'Đã cập nhật danh mục'));
          await _loadAll();
        } else {
          _showMessage(response['message'] ?? _tr('Failed to update category', 'Cập nhật danh mục thất bại'));
        }
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showMessage('${_tr('Failed to update category', 'Cập nhật danh mục thất bại')}: $error');
      }
    });
  }

  Future<void> _deleteCategory(Map<String, dynamic> category) async {
    final confirmed = await _confirmAction(
      title: _tr('Delete category?', 'Xóa danh mục?'),
      message:
          '${_tr('Delete', 'Xóa')} "${category['categoryName'] ?? _tr('this category', 'danh mục này')}" ${_tr('permanently? Categories with subcategories or videos cannot be deleted.', 'vĩnh viễn? Danh mục có danh mục con hoặc video không thể xóa.')}',
      confirmLabel: _tr('Delete', 'Xóa'),
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
          _showMessage(response['message'] ?? _tr('Category deleted', 'Đã xóa danh mục'));
          await _loadAll();
        } else {
          _showMessage(response['message'] ?? _tr('Failed to delete category', 'Xóa danh mục thất bại'));
        }
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showMessage('${_tr('Failed to delete category', 'Xóa danh mục thất bại')}: $error');
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
          _showMessage(response['message'] ?? _tr('Category created', 'Đã tạo danh mục'));
          await _loadAll();
        } else {
          _showMessage(response['message'] ?? _tr('Failed to create category', 'Tạo danh mục thất bại'));
        }
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showMessage('${_tr('Failed to create category', 'Tạo danh mục thất bại')}: $error');
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
          _showMessage(response['message'] ?? _tr('User created', 'Đã tạo người dùng'));
          await _loadAll();
        } else {
          _showMessage(response['message'] ?? _tr('Failed to create user', 'Tạo người dùng thất bại'));
        }
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showMessage('${_tr('Failed to create user', 'Tạo người dùng thất bại')}: $error');
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
          _showMessage(response['message'] ?? _tr('User updated', 'Đã cập nhật người dùng'));
          await _loadAll();
        } else {
          _showMessage(response['message'] ?? _tr('Failed to update user', 'Cập nhật người dùng thất bại'));
        }
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showMessage('${_tr('Failed to update user', 'Cập nhật người dùng thất bại')}: $error');
      }
    });
  }

  Future<void> _toggleUserStatus(Map<String, dynamic> user) async {
    final isActive = user['isActive'] != false;
    final confirmed = await _confirmAction(
      title: isActive
        ? _tr('Deactivate user?', 'Vô hiệu hóa người dùng?')
        : _tr('Activate user?', 'Kích hoạt người dùng?'),
      message: isActive
        ? _tr('This account will lose access until you reactivate it.', 'Tài khoản này sẽ mất quyền truy cập cho đến khi được kích hoạt lại.')
        : _tr('This account will be able to sign in again.', 'Tài khoản này sẽ có thể đăng nhập trở lại.'),
      confirmLabel: isActive
        ? _tr('Deactivate', 'Vô hiệu hóa')
        : _tr('Activate', 'Kích hoạt'),
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
          _showMessage(response['message'] ?? _tr('User updated', 'Đã cập nhật người dùng'));
          await _loadAll();
        } else {
          _showMessage(response['message'] ?? _tr('Failed to update user', 'Cập nhật người dùng thất bại'));
        }
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showMessage('${_tr('Failed to update user', 'Cập nhật người dùng thất bại')}: $error');
      }
    });
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final confirmed = await _confirmAction(
      title: _tr('Delete user?', 'Xóa người dùng?'),
      message:
          '${_tr('Delete', 'Xóa')} @${user['username'] ?? _tr('this user', 'người dùng này')} ${_tr('permanently? This action cannot be undone.', 'vĩnh viễn? Hành động này không thể hoàn tác.')}',
      confirmLabel: _tr('Delete', 'Xóa'),
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
          _showMessage(response['message'] ?? _tr('User deleted', 'Đã xóa người dùng'));
          await _loadAll();
        } else {
          _showMessage(response['message'] ?? _tr('Failed to delete user', 'Xóa người dùng thất bại'));
        }
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showMessage('${_tr('Failed to delete user', 'Xóa người dùng thất bại')}: $error');
      }
    });
  }

  Future<Map<String, dynamic>?> _showVideoEditor(
    Map<String, dynamic> video,
  ) async {
    final l10n = AppLocalizations.of(context);
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
          title: Text('${l10n.edit} ${_tr('Video', 'Video')}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: _tr('Title', 'Tiêu đề'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: l10n.description,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: InputDecoration(
                    labelText: _tr('Status', 'Trạng thái'),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(value: 'PUBLIC', child: Text(_tr('Public', 'Công khai'))),
                    const DropdownMenuItem(value: 'VIP', child: Text('VIP')),
                    DropdownMenuItem(
                      value: 'PRIVATE',
                      child: Text(_tr('Private', 'Riêng tư')),
                    ),
                    DropdownMenuItem(
                      value: 'UNLISTED',
                      child: Text(_tr('Unlisted', 'Không liệt kê')),
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
                  decoration: InputDecoration(
                    labelText: l10n.category,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: '',
                      child: Text(_tr('No category', 'Không có danh mục')),
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
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'title': titleController.text.trim(),
                'description': descriptionController.text.trim(),
                'status': selectedStatus,
                'categoryId':
                    selectedCategoryId.isEmpty ? null : selectedCategoryId,
              }),
              child: Text(l10n.saveChanges),
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
    final l10n = AppLocalizations.of(context);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(
            isEditing
                ? _tr('Edit forum', 'Chỉnh sửa diễn đàn')
                : _tr('Create forum', 'Tạo diễn đàn'),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: _tr('Forum title', 'Tiêu đề diễn đàn'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: subtitleController,
                  decoration: InputDecoration(
                    labelText: _tr('Subtitle', 'Phụ đề'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: _tr('Description', 'Mô tả'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: slugController,
                  decoration: InputDecoration(
                    labelText: _tr('Slug', 'Đường dẫn'),
                    helperText: _tr('Optional. Leave blank to derive from the title.', 'Tùy chọn. Để trống để tạo từ tiêu đề.'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: keywordsController,
                  decoration: InputDecoration(
                    labelText: _tr('Keywords', 'Từ khóa'),
                    helperText: _tr('Separate keywords with commas.', 'Phân tách từ khóa bằng dấu phẩy.'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: orderController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _tr('Sort order', 'Thứ tự sắp xếp'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: accentStartController,
                  decoration: InputDecoration(
                    labelText: _tr('Accent start', 'Màu bắt đầu'),
                    helperText: _tr('Hex color like #4F7DFF', 'Màu hex như #4F7DFF'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: accentEndController,
                  decoration: InputDecoration(
                    labelText: _tr('Accent end', 'Màu kết thúc'),
                    helperText: _tr('Hex color like #5FD4FF', 'Màu hex như #5FD4FF'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  value: isHot,
                  contentPadding: EdgeInsets.zero,
                  title: Text(_tr('Show in Hot Forums', 'Hiển thị ở Diễn đàn nổi bật')),
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
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final title = titleController.text.trim();
                final subtitle = subtitleController.text.trim();
                if (title.isEmpty || subtitle.isEmpty) {
                  setDialogState(() {
                    validationMessage = _tr(
                      'Title and subtitle are required.',
                      'Cần nhập tiêu đề và phụ đề.',
                    );
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
              child: Text(isEditing ? l10n.saveChanges : l10n.create),
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
    final l10n = AppLocalizations.of(context);
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
        title: Text('${l10n.edit} ${l10n.category.toLowerCase()}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: _tr('Category name', 'Tên danh mục'),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: l10n.description,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: orderController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _tr('Sort order', 'Thứ tự sắp xếp'),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, {
              'categoryName': nameController.text.trim(),
              'categoryDesc': descriptionController.text.trim(),
              'categoryOrder': int.tryParse(orderController.text.trim()) ?? 0,
            }),
            child: Text(l10n.saveChanges),
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
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final orderController = TextEditingController(text: '$_nextCategoryOrder');
    var selectedParentId = '';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('${l10n.create} ${l10n.category.toLowerCase()}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: _tr('Category name', 'Tên danh mục'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: l10n.description,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedParentId,
                  decoration: InputDecoration(
                    labelText: _tr('Parent category', 'Danh mục cha'),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: '',
                      child: Text(_tr('Top level', 'Cấp cao nhất')),
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
                  decoration: InputDecoration(
                    labelText: _tr('Sort order', 'Thứ tự sắp xếp'),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'categoryName': nameController.text.trim(),
                'categoryDesc': descriptionController.text.trim(),
                'parentId': selectedParentId.isEmpty ? null : selectedParentId,
                'categoryOrder': int.tryParse(orderController.text.trim()) ?? 0,
              }),
              child: Text(l10n.create),
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
    final l10n = AppLocalizations.of(context);
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
          title: Text('${l10n.edit} ${_tr('User', 'Người dùng')}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${user['email'] ?? _tr('No email', 'Không có email')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: usernameController,
                  decoration: InputDecoration(
                    labelText: _tr('Username', 'Tên đăng nhập'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: firstNameController,
                  decoration: InputDecoration(
                    labelText: _tr('First name', 'Tên'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lastNameController,
                  decoration: InputDecoration(
                    labelText: _tr('Last name', 'Họ'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: InputDecoration(
                    labelText: _tr('Role', 'Vai trò'),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(value: 'USER', child: Text(_tr('User', 'Người dùng'))),
                    DropdownMenuItem(value: 'ADMIN', child: Text(_tr('Admin', 'Quản trị'))),
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
                  title: Text(_tr('Verified account', 'Tài khoản đã xác minh')),
                  value: isVerified,
                  onChanged: (value) {
                    setDialogState(() {
                      isVerified = value;
                    });
                  },
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_tr('Account active', 'Tài khoản đang hoạt động')),
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
              child: Text(l10n.cancel),
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
              child: Text(l10n.saveChanges),
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
    final l10n = AppLocalizations.of(context);
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
          title: Text('${l10n.create} ${_tr('User', 'Người dùng')}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: usernameController,
                  decoration: InputDecoration(
                    labelText: _tr('Username', 'Tên đăng nhập'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: _tr('Email', 'Email'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: _tr('Temporary password', 'Mật khẩu tạm thời'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: firstNameController,
                  decoration: InputDecoration(
                    labelText: _tr('First name', 'Tên'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lastNameController,
                  decoration: InputDecoration(
                    labelText: _tr('Last name', 'Họ'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: InputDecoration(
                    labelText: _tr('Role', 'Vai trò'),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(value: 'USER', child: Text(_tr('User', 'Người dùng'))),
                    DropdownMenuItem(value: 'ADMIN', child: Text(_tr('Admin', 'Quản trị'))),
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
                  title: Text(_tr('Verified account', 'Tài khoản đã xác minh')),
                  value: isVerified,
                  onChanged: (value) {
                    setDialogState(() {
                      isVerified = value;
                    });
                  },
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_tr('Account active', 'Tài khoản đang hoạt động')),
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
              child: Text(l10n.cancel),
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
              child: Text(l10n.create),
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
            child: Text(AppLocalizations.of(dialogContext).cancel),
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
            child: Text(AppLocalizations.of(dialogContext).cancel),
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
    final name = '${category['categoryName'] ?? _tr('Unnamed category', 'Danh mục chưa đặt tên')}';
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

    return parts.isEmpty ? _tr('No display name set', 'Chưa đặt tên hiển thị') : parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(authServiceProvider);
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final isAdmin = authService.isAdmin;

    return DefaultTabController(
      initialIndex: _initialTabIndex,
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          title: Text(l10n.managementDashboard),
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
            tabs: [
              Tab(text: l10n.overview),
              Tab(text: l10n.videos),
              Tab(text: l10n.communityHotForums),
              Tab(text: l10n.categories),
              Tab(text: l10n.communityUsers),
              Tab(text: l10n.reportsMenu),
              Tab(text: l10n.feedbackInbox),
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
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.admin_panel_settings_outlined, size: 56),
            const SizedBox(height: 16),
            Text(
              l10n.adminAccessRequired,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.adminAccessOnly,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _error ?? l10n.adminUnableLoadData,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadAll,
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    final l10n = AppLocalizations.of(context);
    final statistics = Map<String, dynamic>.from(
      _dashboard['statistics'] as Map? ?? const {},
    );
    final moderation = Map<String, dynamic>.from(
      _dashboard['moderation'] as Map? ?? const {},
    );
    final appSettings = Map<String, dynamic>.from(
      _dashboard['appSettings'] as Map? ?? const {},
    );
    final freeCommunityPostBonusCoins =
        _appSettingInt(appSettings, 'freeCommunityPostBonusCoins');
    final freeVideoBonusCoins =
        _appSettingInt(appSettings, 'freeVideoBonusCoins');
    final libraryItemDownloadCoins =
      _appSettingInt(appSettings, 'libraryItemDownloadCoins');
    final recentFeedback = List<Map<String, dynamic>>.from(
      _dashboard['recentFeedback'] as List? ?? const [],
    );
    final metrics = <_DashboardMetric>[
      _DashboardMetric(
        label: _tr('Users', 'Người dùng'),
        value: statistics['totalUsers'] ?? 0,
        icon: Icons.people_outline,
        color: Colors.blue,
      ),
      _DashboardMetric(
        label: _tr('Videos', 'Video'),
        value: statistics['totalVideos'] ?? 0,
        icon: Icons.play_circle_outline,
        color: Colors.red,
      ),
      _DashboardMetric(
        label: _tr('Categories', 'Danh mục'),
        value: statistics['totalCategories'] ?? 0,
        icon: Icons.category_outlined,
        color: Colors.green,
      ),
      _DashboardMetric(
        label: _tr('Forums', 'Diễn đàn'),
        value: statistics['totalForums'] ?? 0,
        icon: Icons.forum_outlined,
        color: Colors.indigo,
      ),
      _DashboardMetric(
        label: _tr('Posts', 'Bài viết'),
        value: statistics['totalPosts'] ?? 0,
        icon: Icons.forum_outlined,
        color: Colors.orange,
      ),
      _DashboardMetric(
        label: _tr('Pending Reports', 'Báo cáo chờ duyệt'),
        value: moderation['pendingReports'] ?? 0,
        icon: Icons.flag_outlined,
        color: Colors.deepOrange,
      ),
      _DashboardMetric(
        label: _tr('Pending Feedback', 'Phản hồi chờ duyệt'),
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
              title: Text(l10n.screenCaptureProtection),
              subtitle: Text(l10n.screenCaptureProtectionSubtitle),
              value: appSettings['contentProtectionEnabled'] == true,
              onChanged: _isBusy('app-settings')
                  ? null
                  : _updateContentProtectionSetting,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  secondary: _isBusy('app-settings')
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.favorite_outline),
                  title: Text(l10n.datingFeature),
                  subtitle: Text(l10n.datingFeatureSubtitle),
                  value: appSettings['datingEnabled'] == true,
                  onChanged: _isBusy('app-settings') ? null : _updateDatingSetting,
                ),
                if (appSettings['datingEnabled'] == true) ...
                  [
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.my_location_outlined),
                      title: Text(l10n.searchRadius),
                      subtitle: Text(
                        '${appSettings['datingSearchRadiusKm'] ?? 50} km',
                      ),
                      trailing: FilledButton.tonal(
                        onPressed: _isBusy('app-settings')
                            ? null
                            : () => _editDatingRadiusSettings(appSettings),
                        child: Text(l10n.edit),
                      ),
                    ),
                  ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: Text(l10n.aiMatchingProvider),
              subtitle: Text(
                '${_tr('Provider', 'Nhà cung cấp')}: ${appSettings['datingAiProvider'] ?? 'openai'}\n'
                '${_tr('Model', 'Mô hình')}: ${appSettings['datingAiModel'] ?? 'gpt-4o-mini'}\n'
                'API Key: ${appSettings['datingAiApiKeyConfigured'] == true ? _tr('Configured', 'Đã cấu hình') : _tr('Not configured', 'Chưa cấu hình')}',
              ),
              trailing: FilledButton.tonal(
                onPressed: _isBusy('app-settings')
                    ? null
                    : () => _editAiMatchingSettings(appSettings),
                child: Text(l10n.edit),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.monetization_on_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.freeContentBonusCoins,
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            SizedBox(height: 4),
                            Text(
                              l10n.freeContentBonusCoinsSubtitle,
                              style: TextStyle(color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: _isBusy('app-settings')
                            ? null
                            : () => _editBonusCoinSettings(appSettings),
                        child: Text(l10n.edit),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFF),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.freeMediaPost,
                                style: TextStyle(color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '$freeCommunityPostBonusCoins coins',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFF),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.freeVideoUpload,
                                style: TextStyle(color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '$freeVideoBonusCoins coins',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _tr('Library download cost', 'Giá tải thư viện'),
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$libraryItemDownloadCoins coins',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.recentFeedback,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          if (recentFeedback.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.noFeedbackSubmittedYet),
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
        title: Text('${entry['subject'] ?? _tr('General feedback', 'Phản hồi chung')}'),
        subtitle: Text(
          '${user['username'] ?? _tr('Unknown', 'Không rõ')}\n${entry['message'] ?? ''}',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildVideosTab() {
    final l10n = AppLocalizations.of(context);
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _buildTabActionBar(
            title: l10n.videos,
            createLabel: '${l10n.create} ${_tr('Video', 'Video')}',
            createIcon: Icons.add_circle_outline,
            onCreate: _createVideo,
          ),
          const SizedBox(height: 12),
          if (_videos.isEmpty)
            _buildInlineEmptyCard(
              _tr('No videos available', 'Không có video nào'),
            )
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
                                    '${video['title'] ?? _tr('Untitled video', 'Video chưa đặt tên')}',
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
                                        isVisible ? _tr('ACTIVE', 'ĐANG HIỂN') : _tr('HIDDEN', 'ĐÃ ẨN'),
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
                        Text('${_tr('Creator', 'Người tạo')}: ${user['username'] ?? _tr('Unknown', 'Không rõ')}'),
                        const SizedBox(height: 4),
                        Text(
                          '${_tr('Views', 'Lượt xem')} ${video['views'] ?? 0} • ${_tr('Likes', 'Lượt thích')} ${video['likes'] ?? 0} • ${_tr('Shares', 'Lượt chia sẻ')} ${video['shares'] ?? 0}',
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
                              child: Text(l10n.edit),
                            ),
                            FilledButton.tonal(
                              onPressed: _isBusy(busyKey)
                                  ? null
                                  : () => _toggleVideoVisibility(video),
                              child: Text(
                                isVisible ? _tr('Deactivate', 'Ẩn') : _tr('Activate', 'Hiện'),
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
                              child: Text(l10n.delete),
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
    final l10n = AppLocalizations.of(context);
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _buildTabActionBar(
            title: l10n.communityHotForums,
            createLabel: '${l10n.create} ${l10n.communityHotForums.toLowerCase()}',
            createIcon: Icons.forum_outlined,
            onCreate: _createForum,
          ),
          const SizedBox(height: 12),
          if (_forums.isEmpty)
            _buildInlineEmptyCard(_tr('No forums available', 'Không có diễn đàn nào'))
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
                                    '${forum['title'] ?? _tr('Untitled forum', 'Diễn đàn chưa đặt tên')}',
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
                                        '${forum['postCount'] ?? 0} ${_tr('posts', 'bài viết')}',
                                        Icons.article_outlined,
                                      ),
                                      _buildInfoChip(
                                        '${forum['followerCount'] ?? 0} ${_tr('followers', 'người theo dõi')}',
                                        Icons.people_outline,
                                      ),
                                      _buildInfoChip(
                                        '${_tr('Order', 'Thứ tự')} ${forum['sortOrder'] ?? 0}',
                                        Icons.sort,
                                      ),
                                      if (forum['isHot'] == true)
                                        _buildStatusChip(_tr('HOT', 'NỔI BẬT')),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('${_tr('Slug', 'Đường dẫn')}: ${forum['slug'] ?? '-'}'),
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
                              child: Text(l10n.edit),
                            ),
                            OutlinedButton(
                              onPressed: _isBusy(busyKey)
                                  ? null
                                  : () => _deleteForum(forum),
                              style: OutlinedButton.styleFrom(
                                foregroundColor:
                                    Theme.of(context).colorScheme.error,
                              ),
                              child: Text(l10n.delete),
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
    final l10n = AppLocalizations.of(context);
    final categories = _flatCategories;

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _buildTabActionBar(
            title: l10n.categories,
            createLabel: '${l10n.create} ${l10n.category.toLowerCase()}',
            createIcon: Icons.create_new_folder_outlined,
            onCreate: _createCategory,
          ),
          const SizedBox(height: 12),
          if (categories.isEmpty)
            _buildInlineEmptyCard(_tr('No categories available', 'Không có danh mục nào'))
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
                                        '$videoCount ${_tr('videos', 'video')}',
                                        Icons.play_arrow_outlined,
                                      ),
                                      _buildInfoChip(
                                        '$childCount ${_tr('subcategories', 'danh mục con')}',
                                        Icons.account_tree_outlined,
                                      ),
                                      _buildInfoChip(
                                        '${_tr('Order', 'Thứ tự')} ${category['categoryOrder'] ?? 0}',
                                        Icons.sort,
                                      ),
                                      if (isDefault)
                                        _buildStatusChip(_tr('DEFAULT', 'MẶC ĐỊNH')),
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
                              child: Text(l10n.edit),
                            ),
                            OutlinedButton(
                              onPressed: _isBusy(busyKey)
                                  ? null
                                  : () => _deleteCategory(category),
                              style: OutlinedButton.styleFrom(
                                foregroundColor:
                                    Theme.of(context).colorScheme.error,
                              ),
                              child: Text(l10n.delete),
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
    final l10n = AppLocalizations.of(context);
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _buildTabActionBar(
            title: _tr('Users', 'Người dùng'),
            createLabel: '${l10n.create} ${_tr('User', 'Người dùng')}',
            createIcon: Icons.person_add_alt_1,
            onCreate: _createUser,
          ),
          const SizedBox(height: 12),
          if (_users.isEmpty)
            _buildInlineEmptyCard(
              _tr('No users available', 'Không có người dùng nào'),
            )
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
                                    '@${user['username'] ?? _tr('unknown', 'không-rõ')}',
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
                                        isActive ? _tr('ACTIVE', 'HOẠT ĐỘNG') : _tr('INACTIVE', 'KHÔNG HOẠT ĐỘNG'),
                                      ),
                                      if (user['isVerified'] == true)
                                        _buildStatusChip(_tr('VERIFIED', 'ĐÃ XÁC MINH')),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('${user['email'] ?? _tr('No email', 'Không có email')}'),
                        const SizedBox(height: 4),
                        Text(
                          '${user['videoCount'] ?? 0} ${_tr('videos', 'video')} • ${user['postCount'] ?? 0} ${_tr('posts', 'bài viết')}',
                        ),
                        const SizedBox(height: 16),
                        _buildResponsiveActions(
                          children: [
                            FilledButton.tonal(
                              onPressed: _isBusy(busyKey)
                                  ? null
                                  : () => _editUser(user),
                              child: Text(l10n.edit),
                            ),
                            FilledButton.tonal(
                              onPressed: _isBusy(busyKey)
                                  ? null
                                  : () => _toggleUserStatus(user),
                              child: Text(
                                isActive
                                    ? _tr('Deactivate', 'Vô hiệu hóa')
                                    : _tr('Activate', 'Kích hoạt'),
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
                              child: Text(l10n.delete),
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
    final l10n = AppLocalizations.of(context);
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: _reports.isEmpty
          ? _buildEmptyList(_tr('No reports to review', 'Không có báo cáo để duyệt'))
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
                  ? '${target['username'] ?? _tr('Unknown user', 'Người dùng không rõ')}'
                  : '${target['title'] ?? _tr('Untitled', 'Chưa đặt tên')}';

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
                        Text('${_tr('Reporter', 'Người báo cáo')}: ${reporter['username'] ?? _tr('Unknown', 'Không rõ')}'),
                        const SizedBox(height: 4),
                        Text('${_tr('Reason', 'Lý do')}: ${report['reason'] ?? _tr('Unspecified', 'Không xác định')}'),
                        if ((report['description'] ?? '').toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('${_tr('Details', 'Chi tiết')}: ${report['description']}'),
                          ),
                        if ((report['adminReply'] ?? '').toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('${_tr('Admin note', 'Ghi chú admin')}: ${report['adminReply']}'),
                          ),
                        const SizedBox(height: 16),
                        _buildResponsiveActions(
                          children: [
                            FilledButton.tonal(
                              onPressed: _isBusy(busyKey)
                                  ? null
                                  : () => _updateReport(report, 'approve'),
                              child: Text(_tr('Approve', 'Duyệt')),
                            ),
                            FilledButton.tonal(
                              onPressed: _isBusy(busyKey)
                                  ? null
                                  : () => _updateReport(report, 'deny'),
                              child: Text(_tr('Deny', 'Từ chối')),
                            ),
                            OutlinedButton(
                              onPressed: _isBusy(busyKey)
                                  ? null
                                  : () => _replyToReport(report),
                              child: Text(l10n.reply),
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
    final l10n = AppLocalizations.of(context);
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: _feedbackEntries.isEmpty
          ? _buildEmptyList(_tr('No feedback entries yet', 'Chưa có mục phản hồi nào'))
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
                                '${entry['subject'] ?? _tr('General feedback', 'Phản hồi chung')}',
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
                        Text('${_tr('From', 'Tu')}: ${user['username'] ?? _tr('Unknown', 'Không rõ')}'),
                        const SizedBox(height: 8),
                        Text('${entry['message'] ?? ''}'),
                        if ((entry['adminReply'] ?? '').toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              '${_tr('Reply', 'Trả lời')}: ${entry['adminReply']}',
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
                              child: Text(l10n.reply),
                            ),
                            OutlinedButton(
                              onPressed: _isBusy(busyKey)
                                  ? null
                                  : () => _updateFeedback(
                                        entry,
                                        status: 'DISMISSED',
                                      ),
                              child: Text(l10n.close),
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




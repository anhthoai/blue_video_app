import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';

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
  List<Map<String, dynamic>> _users = const [];
  List<Map<String, dynamic>> _categories = const [];
  List<Map<String, dynamic>> _reports = const [];
  List<Map<String, dynamic>> _feedbackEntries = const [];

  int get _initialTabIndex {
    if (widget.initialTab < 0) {
      return 0;
    }
    if (widget.initialTab > 5) {
      return 5;
    }
    return widget.initialTab;
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
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
        _apiService.getVideos(page: 1, limit: 20),
        _apiService.getUsers(page: 1, limit: 20),
        _apiService.getCategories(),
        _apiService.getAdminReports(limit: 20),
        _apiService.getAdminFeedback(limit: 20),
      ]);

      final dashboardResponse = results[0] as Map<String, dynamic>;
      final videosResponse = results[1] as Map<String, dynamic>;
      final usersResponse = results[2] as Map<String, dynamic>;
      final categoriesResponse = results[3] as List<Map<String, dynamic>>;
      final reportsResponse = results[4] as Map<String, dynamic>;
      final feedbackResponse = results[5] as Map<String, dynamic>;

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
        _showMessage('Report updated');
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
        _showMessage('Feedback updated');
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

  Future<String?> _promptForText({
    required String title,
    required String hintText,
    required String actionLabel,
  }) async {
    final controller = TextEditingController();

    return showDialog<String>(
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
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(authServiceProvider);
    final isAdmin = authService.isAdmin;

    return DefaultTabController(
      initialIndex: _initialTabIndex,
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Management Dashboard'),
          actions: [
            IconButton(
              onPressed: _loadAll,
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Videos'),
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
    final recentFeedback = List<Map<String, dynamic>>.from(
      _dashboard['recentFeedback'] as List? ?? const [],
    );

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildMetricCard(
                label: 'Users',
                value: statistics['totalUsers'] ?? 0,
                icon: Icons.people_outline,
                color: Colors.blue,
              ),
              _buildMetricCard(
                label: 'Videos',
                value: statistics['totalVideos'] ?? 0,
                icon: Icons.play_circle_outline,
                color: Colors.red,
              ),
              _buildMetricCard(
                label: 'Categories',
                value: statistics['totalCategories'] ?? 0,
                icon: Icons.category_outlined,
                color: Colors.green,
              ),
              _buildMetricCard(
                label: 'Posts',
                value: statistics['totalPosts'] ?? 0,
                icon: Icons.forum_outlined,
                color: Colors.orange,
              ),
              _buildMetricCard(
                label: 'Pending Reports',
                value: moderation['pendingReports'] ?? 0,
                icon: Icons.flag_outlined,
                color: Colors.deepOrange,
              ),
              _buildMetricCard(
                label: 'Pending Feedback',
                value: moderation['pendingFeedback'] ?? 0,
                icon: Icons.feedback_outlined,
                color: Colors.teal,
              ),
            ],
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

  Widget _buildMetricCard({
    required String label,
    required Object value,
    required IconData icon,
    required Color color,
  }) {
    return SizedBox(
      width: 165,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 16),
              Text(
                '$value',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(label),
            ],
          ),
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
      child: _videos.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 160),
                Center(child: Text('No videos available')),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: _videos.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final video = _videos[index];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.play_arrow),
                    ),
                    title: Text('${video['title'] ?? 'Untitled video'}'),
                    subtitle: Text(
                      'Views ${video['views'] ?? video['viewCount'] ?? 0} • '
                      'Likes ${video['likes'] ?? video['likeCount'] ?? 0} • '
                      'Shares ${video['shares'] ?? video['shareCount'] ?? 0}',
                    ),
                    trailing:
                        _buildStatusChip('${video['status'] ?? 'PUBLIC'}'),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildCategoriesTab() {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: _categories.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 160),
                Center(child: Text('No categories available')),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final category = _categories[index];
                final children = List<Map<String, dynamic>>.from(
                  category['children'] as List? ?? const [],
                );
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${category['categoryName'] ?? 'Unnamed category'}',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${category['videoCount'] ?? 0} videos • '
                          '${children.length} subcategories',
                        ),
                        if (children.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: children
                                .map(
                                  (child) => Chip(
                                    label: Text(
                                      '${child['categoryName'] ?? 'Child'}',
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildUsersTab() {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: _users.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 160),
                Center(child: Text('No users available')),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: _users.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final user = _users[index];
                final nameParts = [
                  '${user['firstName'] ?? ''}'.trim(),
                  '${user['lastName'] ?? ''}'.trim(),
                ].where((part) => part.isNotEmpty).join(' ');

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        ('${user['username'] ?? 'U'}')
                            .characters
                            .first
                            .toUpperCase(),
                      ),
                    ),
                    title: Text('${user['username'] ?? 'Unknown user'}'),
                    subtitle: Text(
                      nameParts.isEmpty ? 'No display name set' : nameParts,
                    ),
                    trailing: (user['isVerified'] == true)
                        ? const Icon(Icons.verified, color: Colors.blue)
                        : null,
                  ),
                );
              },
            ),
    );
  }

  Widget _buildReportsTab() {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: _reports.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 160),
                Center(child: Text('No reports to review')),
              ],
            )
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
                final targetTitle = report['type'] == 'user'
                    ? '${target['username'] ?? 'Unknown user'}'
                    : '${target['title'] ?? 'Untitled'}';

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildStatusChip('${report['type'] ?? 'report'}'),
                            const SizedBox(width: 8),
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
                        Text(
                          'Reporter: ${reporter['username'] ?? 'Unknown'}',
                        ),
                        const SizedBox(height: 4),
                        Text('Reason: ${report['reason'] ?? 'Unspecified'}'),
                        if ((report['description'] ?? '').toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Details: ${report['description']}',
                            ),
                          ),
                        if ((report['adminReply'] ?? '').toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Admin note: ${report['adminReply']}',
                            ),
                          ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.tonal(
                                onPressed: () =>
                                    _updateReport(report, 'approve'),
                                child: const Text('Approve'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.tonal(
                                onPressed: () => _updateReport(report, 'deny'),
                                child: const Text('Deny'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _replyToReport(report),
                                child: const Text('Reply'),
                              ),
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
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 160),
                Center(child: Text('No feedback entries yet')),
              ],
            )
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
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.tonal(
                                onPressed: () => _replyToFeedback(entry),
                                child: const Text('Reply'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _updateFeedback(
                                  entry,
                                  status: 'DISMISSED',
                                ),
                                child: const Text('Close'),
                              ),
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
        return Colors.green;
      case 'DISMISSED':
      case 'DENY':
        return Colors.red;
      case 'REVIEWED':
        return Colors.blue;
      case 'VIDEO':
        return Colors.deepOrange;
      case 'POST':
        return Colors.purple;
      case 'USER':
        return Colors.teal;
      default:
        return Colors.orange;
    }
  }
}

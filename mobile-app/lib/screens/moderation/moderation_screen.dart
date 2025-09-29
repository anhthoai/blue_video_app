import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/community_service.dart';
import '../../models/community_post.dart';
import '../../widgets/community/community_post_widget.dart';

class ModerationScreen extends ConsumerStatefulWidget {
  const ModerationScreen({super.key});

  @override
  ConsumerState<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends ConsumerState<ModerationScreen> {
  @override
  void initState() {
    super.initState();
    _loadReportedPosts();
  }

  Future<void> _loadReportedPosts() async {
    final communityService = ref.read(communityServiceStateProvider.notifier);
    await communityService.loadReportedPosts();
  }

  @override
  Widget build(BuildContext context) {
    final communityState = ref.watch(communityServiceStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Content Moderation'),
        backgroundColor: Colors.red[50],
        foregroundColor: Colors.red[800],
      ),
      body: communityState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : communityState.reportedPosts.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: communityState.reportedPosts.length,
                  itemBuilder: (context, index) {
                    final post = communityState.reportedPosts[index];
                    return _buildReportedPostCard(post);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: Colors.green,
          ),
          SizedBox(height: 16),
          Text(
            'No reported posts',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'All content is clean!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportedPostCard(CommunityPost post) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Report header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(Icons.report, color: Colors.red[600], size: 20),
                const SizedBox(width: 8),
                Text(
                  'Reported Content',
                  style: TextStyle(
                    color: Colors.red[800],
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Text(
                  post.formattedTime,
                  style: TextStyle(
                    color: Colors.red[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Post content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User info
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: post.userAvatar.isNotEmpty
                          ? NetworkImage(post.userAvatar)
                          : null,
                      child: post.userAvatar.isEmpty
                          ? const Icon(Icons.person, size: 16)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      post.username,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        post.status.name.toUpperCase(),
                        style: TextStyle(
                          color: Colors.red[800],
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Post title and content
                if (post.title.isNotEmpty) ...[
                  Text(
                    post.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  post.content,
                  style: const TextStyle(fontSize: 14),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 12),

                // Post stats
                Row(
                  children: [
                    _buildStatItem(Icons.favorite, post.formattedLikes),
                    const SizedBox(width: 16),
                    _buildStatItem(Icons.comment, post.formattedComments),
                    const SizedBox(width: 16),
                    _buildStatItem(Icons.share, post.formattedShares),
                    const SizedBox(width: 16),
                    _buildStatItem(Icons.visibility, post.formattedViews),
                  ],
                ),
              ],
            ),
          ),

          // Moderation actions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _moderatePost(post, 'approve'),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _moderatePost(post, 'reject'),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Reject'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _moderatePost(post, 'delete'),
                    icon: const Icon(Icons.delete, size: 16),
                    label: const Text('Delete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  void _moderatePost(CommunityPost post, String action) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${action.toUpperCase()} Post'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to $action this post?'),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                labelText: 'Reason (optional)',
                border: const OutlineInputBorder(),
                hintText: 'Enter reason for $action...',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmModeration(post, action);
            },
            child: Text(action.toUpperCase()),
          ),
        ],
      ),
    );
  }

  void _confirmModeration(CommunityPost post, String action) {
    final communityService = ref.read(communityServiceStateProvider.notifier);
    communityService.moderatePost(
      postId: post.id,
      moderatorId: 'current_moderator', // In a real app, get from auth
      action: action,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Post ${action}d successfully'),
        backgroundColor: action == 'approve'
            ? Colors.green
            : action == 'reject'
                ? Colors.orange
                : Colors.red,
      ),
    );
  }
}

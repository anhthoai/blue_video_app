import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Navigate to search screen
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // Navigate to create post screen
            },
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 10,
        itemBuilder: (context, index) {
          return _buildCommunityPost(context, index);
        },
      ),
    );
  }

  Widget _buildCommunityPost(BuildContext context, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Info
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey[300],
                  child: const Icon(Icons.person),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'User ${index + 1}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${index + 1}h ago',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {
                    _showPostOptions(context);
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Post Content
            Text(
              'This is a sample community post ${index + 1}. Users can share their thoughts, videos, and connect with others in the community.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),

            const SizedBox(height: 12),

            // Post Image (optional)
            if (index % 3 == 0)
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.image, size: 48, color: Colors.grey),
              ),

            const SizedBox(height: 12),

            // Action Buttons
            Row(
              children: [
                _buildActionButton(
                  context,
                  icon: Icons.thumb_up_outlined,
                  label: '${index + 1}',
                  onTap: () {
                    // Handle like
                  },
                ),
                const SizedBox(width: 24),
                _buildActionButton(
                  context,
                  icon: Icons.comment_outlined,
                  label: '${index + 1}',
                  onTap: () {
                    // Handle comment
                  },
                ),
                const SizedBox(width: 24),
                _buildActionButton(
                  context,
                  icon: Icons.share_outlined,
                  label: 'Share',
                  onTap: () {
                    // Handle share
                  },
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.bookmark_outline),
                  onPressed: () {
                    // Handle save
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  void _showPostOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.bookmark_outline),
                  title: const Text('Save Post'),
                  onTap: () {
                    Navigator.pop(context);
                    // Handle save
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.share_outlined),
                  title: const Text('Share Post'),
                  onTap: () {
                    Navigator.pop(context);
                    // Handle share
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.report_outlined),
                  title: const Text('Report Post'),
                  onTap: () {
                    Navigator.pop(context);
                    // Handle report
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.block_outlined),
                  title: const Text('Block User'),
                  onTap: () {
                    Navigator.pop(context);
                    // Handle block
                  },
                ),
              ],
            ),
          ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/community_service.dart';
import '../../widgets/community/community_post_widget.dart';
import '../../core/services/auth_service.dart';

class TagPostsScreen extends ConsumerStatefulWidget {
  final String tag;

  const TagPostsScreen({
    super.key,
    required this.tag,
  });

  @override
  ConsumerState<TagPostsScreen> createState() => _TagPostsScreenState();
}

class _TagPostsScreenState extends ConsumerState<TagPostsScreen> {
  @override
  void initState() {
    super.initState();
    // Load posts for this tag and available tags
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTagPosts();
      _loadTags();
    });
  }

  Future<void> _loadTagPosts() async {
    try {
      final communityService = ref.read(communityServiceStateProvider.notifier);
      await communityService.loadPostsByTag(widget.tag);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load posts: $e')),
        );
      }
    }
  }

  Future<void> _loadTags() async {
    try {
      final communityService = ref.read(communityServiceStateProvider.notifier);
      await communityService.loadTags();
    } catch (e) {
      // Tags loading failure is not critical
      print('Failed to load tags: $e');
    }
  }

  void _switchToTag(String tag) {
    if (tag != widget.tag) {
      context.pushReplacement('/main/tag/$tag');
    }
  }

  @override
  Widget build(BuildContext context) {
    final communityState = ref.watch(communityServiceStateProvider);
    final authState = ref.watch(authServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Posts tagged with #${widget.tag}'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTagPosts,
          ),
        ],
      ),
      body: Column(
        children: [
          // Tags menu
          if (communityState.categories.isNotEmpty)
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: communityState.categories.length,
                itemBuilder: (context, index) {
                  final category = communityState.categories[index];
                  final isSelected = category == widget.tag;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => _switchToTag(category),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey[700],
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // Content
          Expanded(
            child: communityState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : communityState.error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Failed to load posts',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              communityState.error!,
                              style: TextStyle(
                                color: Colors.grey[500],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadTagPosts,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : communityState.tagPosts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.tag,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No posts found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No posts are tagged with #${widget.tag}',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () => context.pop(),
                                  child: const Text('Go Back'),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadTagPosts,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: communityState.tagPosts.length,
                              itemBuilder: (context, index) {
                                final post = communityState.tagPosts[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: CommunityPostWidget(
                                    post: post,
                                    currentUserId: authState.currentUser?.id,
                                    currentUsername:
                                        authState.currentUser?.username,
                                    currentUserAvatar:
                                        authState.currentUser?.avatarUrl ?? '',
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

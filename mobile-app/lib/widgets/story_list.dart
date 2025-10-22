import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'common/presigned_image.dart';
import '../core/services/api_service.dart';

class StoryList extends ConsumerStatefulWidget {
  const StoryList({super.key});

  @override
  ConsumerState<StoryList> createState() => _StoryListState();
}

class _StoryListState extends ConsumerState<StoryList> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final response = await _apiService.getUsers(page: 1, limit: 10);
      if (response['success'] == true && response['data'] != null) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(response['data']);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading users: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _users.length + 1, // +1 for "Your Story"
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildYourStoryItem(context);
                }
                return _buildUserStoryItem(context, _users[index - 1]);
              },
            ),
    );
  }

  Widget _buildYourStoryItem(BuildContext context) {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          // Your Story Circle
          GestureDetector(
            onTap: () {
              _showAddStoryDialog(context);
            },
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.grey[400]!,
                  width: 2,
                ),
              ),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: Icon(Icons.add, color: Colors.grey[600], size: 24),
              ),
            ),
          ),

          const SizedBox(height: 4),

          // Story Label
          Text(
            'Your Story',
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildUserStoryItem(BuildContext context, Map<String, dynamic> user) {
    final username = user['username'] ?? 'User';
    final avatarUrl = user['avatarUrl'] ?? user['avatar'];
    final firstName = user['firstName'] ?? '';
    final lastName = user['lastName'] ?? '';
    final displayName = firstName.isNotEmpty && lastName.isNotEmpty
        ? '$firstName $lastName'
        : username;

    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          // User Story Circle
          GestureDetector(
            onTap: () {
              _showUserStory(context, user);
            },
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: ClipOval(
                  child: avatarUrl != null && avatarUrl.isNotEmpty
                      ? PresignedImage(
                          imageUrl: avatarUrl,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorWidget: Container(
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.person,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.grey[300],
                          child: const Icon(
                            Icons.person,
                            color: Colors.grey,
                          ),
                        ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 4),

          // Story Label
          Text(
            displayName,
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showUserStory(BuildContext context, Map<String, dynamic> user) {
    final userName = user['firstName'] ?? user['username'];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${userName}\'s Story'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: user['avatarUrl'] != null
                  ? NetworkImage(user['avatarUrl'])
                  : null,
              child: user['avatarUrl'] == null
                  ? const Icon(Icons.person, size: 40)
                  : null,
            ),
            const SizedBox(height: 16),
            const Text('Story feature coming soon!'),
            const SizedBox(height: 8),
            Text('This will show ${userName}\'s recent stories.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAddStoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add to Your Story'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.camera_alt, size: 48, color: Colors.blue),
            SizedBox(height: 16),
            Text('Story feature coming soon!'),
            SizedBox(height: 8),
            Text(
                'You\'ll be able to share photos and videos that disappear after 24 hours.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

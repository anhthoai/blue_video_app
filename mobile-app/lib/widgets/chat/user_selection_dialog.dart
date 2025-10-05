import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../models/user_search_result.dart';

class UserSelectionDialog extends StatefulWidget {
  final String title;
  final Function(String userId) onUserSelected;

  const UserSelectionDialog({
    super.key,
    required this.title,
    required this.onUserSelected,
  });

  @override
  State<UserSelectionDialog> createState() => _UserSelectionDialogState();
}

class _UserSelectionDialogState extends State<UserSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  final ApiService _apiService = ApiService();
  List<UserSearchResult> _users = [];
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers({String query = ''}) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiService.searchUsers(query: query);
      if (response['success'] == true) {
        setState(() {
          _users = (response['data'] as List)
              .map((userData) => UserSearchResult.fromJson(userData))
              .toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading users: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });

    // Debounce search
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_searchQuery == query) {
        _loadUsers(query: query);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search users...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _users.isEmpty
                      ? const Center(
                          child: Text('No users found'),
                        )
                      : ListView.builder(
                          itemCount: _users.length,
                          itemBuilder: (context, index) {
                            final user = _users[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: user.avatarUrl != null
                                    ? NetworkImage(user.avatarUrl!)
                                    : null,
                                child: user.avatarUrl == null
                                    ? Text(user.username.isNotEmpty
                                        ? user.username[0].toUpperCase()
                                        : 'U')
                                    : null,
                              ),
                              title: Text(user.username),
                              subtitle: Text(user.displayName),
                              onTap: () {
                                Navigator.pop(context);
                                widget.onUserSelected(user.id);
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

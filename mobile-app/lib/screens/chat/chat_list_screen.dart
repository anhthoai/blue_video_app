import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/chat_service.dart';
import '../../core/services/auth_service.dart';
import '../../widgets/chat/chat_room_tile.dart';
import '../../widgets/chat/user_selection_dialog.dart';
import 'chat_screen.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAndLoadChatRooms();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh chat list when returning to the screen
      _loadChatRooms();
    }
  }

  Future<void> _initializeAndLoadChatRooms() async {
    final currentUser = ref.read(currentUserProvider);
    final authService = ref.read(authServiceProvider);
    final chatService = ref.read(chatServiceStateProvider.notifier);

    if (currentUser != null) {
      // Initialize chat service with user data
      final token = await authService.getAccessToken();
      if (token != null) {
        chatService.initialize(currentUser.id, token);
        await chatService.loadChatRooms();
      }
    }
  }

  Future<void> _loadChatRooms() async {
    final chatService = ref.read(chatServiceStateProvider.notifier);
    await chatService.loadChatRooms();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatServiceStateProvider);
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Show search
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              _showOptions();
            },
          ),
        ],
      ),
      body: chatState.rooms.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadChatRooms,
              child: ListView.builder(
                itemCount: chatState.rooms.length,
                itemBuilder: (context, index) {
                  final room = chatState.rooms[index];
                  return ChatRoomTile(
                    room: room,
                    currentUserId: currentUser?.id,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(chatId: room.id),
                        ),
                      );
                      // Reload chat list when returning from chat screen
                      _loadChatRooms();
                    },
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showNewChatOptions();
        },
        child: const Icon(Icons.chat),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'No conversations yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Start a new conversation!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  void _showOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.archive),
              title: const Text('Archived Chats'),
              onTap: () {
                Navigator.pop(context);
                _showArchivedChats();
              },
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('Blocked Users'),
              onTap: () {
                Navigator.pop(context);
                _showBlockedUsers();
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Chat Settings'),
              onTap: () {
                Navigator.pop(context);
                _showChatSettings();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showNewChatOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('New Chat'),
              onTap: () {
                Navigator.pop(context);
                _startNewChat();
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_add),
              title: const Text('New Group'),
              onTap: () {
                Navigator.pop(context);
                _createNewGroup();
              },
            ),
            ListTile(
              leading: const Icon(Icons.contacts),
              title: const Text('Contacts'),
              onTap: () {
                Navigator.pop(context);
                _showContacts();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showArchivedChats() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Archived chats feature coming soon!')),
    );
  }

  void _showBlockedUsers() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Blocked users feature coming soon!')),
    );
  }

  void _showChatSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chat Settings'),
        content:
            const Text('Chat settings and preferences will be available here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _startNewChat() {
    showDialog(
      context: context,
      builder: (context) => UserSelectionDialog(
        title: 'Start New Chat',
        onUserSelected: (userId) async {
          await _createDirectChat(userId);
        },
      ),
    );
  }

  void _createNewGroup() {
    showDialog(
      context: context,
      builder: (context) => UserSelectionDialog(
        title: 'Create New Group',
        onUserSelected: (userId) async {
          await _createGroupChat(userId);
        },
      ),
    );
  }

  Future<void> _createDirectChat(String userId) async {
    try {
      final chatService = ref.read(chatServiceStateProvider.notifier);
      final result = await chatService.createChatRoom(
        type: 'PRIVATE',
        participantIds: [userId],
      );

      if (result != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chat created successfully!')),
          );
          // Navigate to the new chat
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(chatId: result.id),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating chat: $e')),
        );
      }
    }
  }

  Future<void> _createGroupChat(String userId) async {
    try {
      final chatService = ref.read(chatServiceStateProvider.notifier);
      final result = await chatService.createChatRoom(
        name: 'New Group',
        type: 'GROUP',
        participantIds: [userId],
      );

      if (result != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Group created successfully!')),
          );
          // Navigate to the new chat
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(chatId: result.id),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating group: $e')),
        );
      }
    }
  }

  void _showContacts() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contacts'),
        content: const Text(
            'Your contacts list will be available here. You can start new chats from here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startNewChat(); // Redirect to new chat
            },
            child: const Text('Start Chat'),
          ),
        ],
      ),
    );
  }
}

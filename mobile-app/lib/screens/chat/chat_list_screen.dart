import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/chat_service.dart';
import '../../models/chat_room.dart';
import '../../widgets/chat/chat_room_tile.dart';
import 'chat_screen.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    _loadChatRooms();
  }

  Future<void> _loadChatRooms() async {
    final chatService = ref.read(chatServiceStateProvider.notifier);
    await chatService.loadChatRooms();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatServiceStateProvider);

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
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(chatId: room.id),
                        ),
                      );
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
                // Show archived chats
              },
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('Blocked Users'),
              onTap: () {
                Navigator.pop(context);
                // Show blocked users
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Chat Settings'),
              onTap: () {
                Navigator.pop(context);
                // Show chat settings
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
                // Start new chat
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_add),
              title: const Text('New Group'),
              onTap: () {
                Navigator.pop(context);
                // Create new group
              },
            ),
            ListTile(
              leading: const Icon(Icons.contacts),
              title: const Text('Contacts'),
              onTap: () {
                Navigator.pop(context);
                // Show contacts
              },
            ),
          ],
        ),
      ),
    );
  }
}

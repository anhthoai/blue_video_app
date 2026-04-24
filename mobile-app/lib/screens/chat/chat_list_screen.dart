import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/chat_call_service.dart';
import '../../core/services/chat_service.dart';
import '../../core/services/auth_service.dart';
import '../../models/chat_call.dart';
import '../../models/chat_participant.dart';
import '../../models/chat_room.dart';
import '../../widgets/chat/chat_room_tile.dart';
import '../../widgets/chat/user_selection_dialog.dart';
import '../../l10n/app_localizations.dart';
import 'chat_call_screen.dart';
import 'chat_screen.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen>
    with WidgetsBindingObserver {
  ProviderSubscription<ChatCallState>? _callSubscription;
  ProviderSubscription<ChatServiceState>? _chatStateSubscription;
  String? _activeIncomingDialogCallId;
  bool _hasPrimedMessageNotifications = false;
  String? _lastIncomingNotificationMessageId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _callSubscription = ref.listenManual<ChatCallState>(
      chatCallControllerProvider,
      (previous, next) {
        final invite = next.incomingInvite;
        if (!mounted || invite == null) {
          return;
        }
        if (_activeIncomingDialogCallId == invite.callId) {
          return;
        }

        _activeIncomingDialogCallId = invite.callId;
        unawaited(_showIncomingCallDialog(invite));
      },
    );
    _chatStateSubscription = ref.listenManual<ChatServiceState>(
      chatServiceStateProvider,
      (previous, next) {
        _handleChatStateChange(previous, next);
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAndLoadChatRooms();
    });
  }

  @override
  void dispose() {
    _callSubscription?.close();
    _chatStateSubscription?.close();
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

  ChatRoom? _findRoomById(String roomId) {
    final chatState = ref.read(chatServiceStateProvider);
    for (final room in chatState.rooms) {
      if (room.id == roomId) {
        return room;
      }
    }
    return null;
  }

  ChatRoom _buildFallbackRoom(ChatCallInvite invite) {
    return ChatRoom(
      id: invite.roomId,
      name: invite.callerName,
      isGroup: false,
      participants: [
        ChatParticipant(
          id: invite.callerId,
          username: invite.callerName,
          firstName: invite.callerName,
          avatarUrl: invite.callerAvatar,
        ),
      ],
      createdAt: invite.createdAt,
      updatedAt: invite.createdAt,
    );
  }

  void _handleChatStateChange(
    ChatServiceState? previous,
    ChatServiceState next,
  ) {
    if (!mounted) {
      return;
    }

    if (!_hasPrimedMessageNotifications) {
      _hasPrimedMessageNotifications = true;
      return;
    }

    final currentUserId = ref.read(currentUserProvider)?.id;
    if (currentUserId == null) {
      return;
    }

    for (final room in next.rooms) {
      final lastMessage = room.lastMessage;
      if (lastMessage == null ||
          lastMessage.userId == currentUserId ||
          lastMessage.isSystem) {
        continue;
      }

      String? previousMessageId;
      if (previous != null) {
        for (final previousRoom in previous.rooms) {
          if (previousRoom.id == room.id) {
            previousMessageId = previousRoom.lastMessage?.id;
            break;
          }
        }
      }

      if (previousMessageId == lastMessage.id ||
          _lastIncomingNotificationMessageId == lastMessage.id) {
        continue;
      }

      _lastIncomingNotificationMessageId = lastMessage.id;
      _showIncomingMessageNotification(room, currentUserId);
      break;
    }
  }

  void _showIncomingMessageNotification(ChatRoom room, String currentUserId) {
    final displayName = room.getDisplayName(currentUserId);
    final preview = room.lastMessagePreview;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$displayName: $preview'),
          duration: const Duration(seconds: 4),
        ),
      );
  }

  Future<void> _showIncomingCallDialog(ChatCallInvite invite) async {
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogContext) {
        final isVideoCall = invite.isVideoCall;
        final avatar = invite.callerAvatar;

        return AlertDialog(
          title:
              Text(isVideoCall ? 'Incoming video call' : 'Incoming voice call'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.grey[300],
                backgroundImage: avatar != null && avatar.isNotEmpty
                    ? CachedNetworkImageProvider(avatar)
                    : null,
                child: avatar == null || avatar.isEmpty
                    ? Text(
                        invite.callerName.isNotEmpty
                            ? invite.callerName[0].toUpperCase()
                            : 'C',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      )
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                invite.callerName,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                isVideoCall
                    ? 'Accept the video call to start live audio and video.'
                    : 'Accept the voice call to start live audio.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Decline'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: Icon(isVideoCall ? Icons.videocam : Icons.phone),
              label: const Text('Accept'),
            ),
          ],
        );
      },
    );

    _activeIncomingDialogCallId = null;

    if (!mounted) {
      return;
    }

    final callController = ref.read(chatCallControllerProvider.notifier);
    if (accepted == true) {
      final didAccept = await callController.acceptIncomingCall();
      if (!didAccept || !mounted) {
        return;
      }

      var room = _findRoomById(invite.roomId);
      room ??= _buildFallbackRoom(invite);
      final currentUser = ref.read(currentUserProvider);

      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (context) => ChatCallScreen(
            room: room!,
            currentUser: currentUser,
            currentUserId: currentUser?.id,
            isVideoCall: invite.isVideoCall,
            autoStartOutgoing: false,
          ),
        ),
      );
      await callController.clearFinishedCall();
      return;
    }

    await callController.declineIncomingCall();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatServiceStateProvider);
    final currentUser = ref.watch(currentUserProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.chats),
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
        heroTag: 'chat_new_message',
        child: const Icon(Icons.chat),
      ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noConversations,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.startNewConversation,
            style: const TextStyle(
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
      builder: (context) {
        final dialogL10n = AppLocalizations.of(context);
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.archive),
                title: Text(dialogL10n.archivedChats),
                onTap: () {
                  Navigator.pop(context);
                  _showArchivedChats();
                },
              ),
              ListTile(
                leading: const Icon(Icons.block),
                title: Text(dialogL10n.blockedUsers),
                onTap: () {
                  Navigator.pop(context);
                  _showBlockedUsers();
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: Text(dialogL10n.chatSettings),
                onTap: () {
                  Navigator.pop(context);
                  _showChatSettings();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showNewChatOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final dialogL10n = AppLocalizations.of(context);
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person_add),
                title: Text(dialogL10n.newChat),
                onTap: () {
                  Navigator.pop(context);
                  _startNewChat();
                },
              ),
              ListTile(
                leading: const Icon(Icons.group_add),
                title: Text(dialogL10n.newGroupChat),
                onTap: () {
                  Navigator.pop(context);
                  _createNewGroup();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showArchivedChats() {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${l10n.archivedChats} ${l10n.comingSoon}')),
    );
  }

  void _showBlockedUsers() {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${l10n.blockedUsers} ${l10n.comingSoon}')),
    );
  }

  void _showChatSettings() {
    showDialog(
      context: context,
      builder: (context) {
        final dialogL10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(dialogL10n.chatSettings),
          content: Text('${dialogL10n.chatSettings} ${dialogL10n.comingSoon}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(dialogL10n.close),
            ),
          ],
        );
      },
    );
  }

  Future<void> _startNewChat() async {
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (context) => UserSelectionDialog(
        title: l10n.newChat,
        onUserSelected: (userId) async {
          await _createDirectChat(userId);
        },
      ),
    );
  }

  void _createNewGroup() {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${l10n.newGroupChat} ${l10n.comingSoon}')),
    );
  }

  Future<void> _createDirectChat(String userId) async {
    final l10n = AppLocalizations.of(context);

    try {
      final chatService = ref.read(chatServiceStateProvider.notifier);
      final result = await chatService.createChatRoom(
        type: 'PRIVATE',
        participantIds: [userId],
      );

      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.chat} ${l10n.savedSuccessfully}')),
        );
        // Navigate to the new chat
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(chatId: result.id),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.error}: $e')),
        );
      }
    }
  }
}

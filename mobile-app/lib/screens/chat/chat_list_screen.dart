import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/api_service.dart';
import '../../core/services/chat_call_service.dart';
import '../../core/services/chat_service.dart';
import '../../core/services/auth_service.dart';
import '../../models/chat_call.dart';
import '../../models/chat_participant.dart';
import '../../models/chat_room.dart';
import '../../models/user_search_result.dart';
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
  BuildContext? _activeIncomingDialogContext;
  bool _hasPrimedMessageNotifications = false;
  String? _lastIncomingNotificationMessageId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _callSubscription = ref.listenManual<ChatCallState>(
      chatCallControllerProvider,
      (previous, next) {
        final activeDialogCallId = _activeIncomingDialogCallId;
        if (activeDialogCallId != null) {
          final hasMatchingInvite = next.incomingInvite?.callId == activeDialogCallId;
          final shouldDismissDialog = !hasMatchingInvite &&
              (next.phase == ChatCallPhase.ended ||
                  next.phase == ChatCallPhase.missed ||
                  next.phase == ChatCallPhase.declined ||
                  next.phase == ChatCallPhase.error ||
                  next.phase == ChatCallPhase.idle);

          if (shouldDismissDialog &&
              (_activeIncomingDialogContext?.mounted ?? false)) {
            final dialogContext = _activeIncomingDialogContext!;
            _activeIncomingDialogCallId = null;
            _activeIncomingDialogContext = null;
            Navigator.of(dialogContext, rootNavigator: true).pop();
          }
        }

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

  Future<void> _openChatRoom(ChatRoom room) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(chatId: room.id),
      ),
    );

    if (mounted) {
      _loadChatRooms();
    }
  }

  Future<void> _showChatSearch() async {
    final chatState = ref.read(chatServiceStateProvider);
    final currentUserId = ref.read(currentUserProvider)?.id;

    final selectedRoom = await showSearch<ChatRoom?>(
      context: context,
      delegate: _ChatRoomSearchDelegate(
        rooms: chatState.rooms,
        currentUserId: currentUserId,
      ),
    );

    if (!mounted || selectedRoom == null) {
      return;
    }

    await _openChatRoom(selectedRoom);
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
        _activeIncomingDialogContext = dialogContext;
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
    _activeIncomingDialogContext = null;

    if (!mounted) {
      return;
    }

    if (accepted == null) {
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
            onPressed: _showChatSearch,
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
                    onTap: () => _openChatRoom(room),
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
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Refresh chats'),
                onTap: () {
                  Navigator.pop(context);
                  _loadChatRooms();
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

  Future<void> _createNewGroup() async {
    final l10n = AppLocalizations.of(context);
    final currentUserId = ref.read(currentUserProvider)?.id;
    if (currentUserId == null) {
      return;
    }

    final draft = await showDialog<_NewGroupChatDraft>(
      context: context,
      builder: (context) => _GroupChatCreationDialog(
        currentUserId: currentUserId,
        title: l10n.newGroupChat,
        cancelLabel: l10n.cancel,
        createLabel: l10n.create,
        fieldRequiredMessage: l10n.fieldRequired,
        searchUsersLabel: l10n.searchUsers,
      ),
    );

    if (!mounted || draft == null) {
      return;
    }

    try {
      final chatService = ref.read(chatServiceStateProvider.notifier);
      final result = await chatService.createChatRoom(
        name: draft.name,
        type: 'GROUP',
        participantIds: draft.participantIds,
      );

      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.newGroupChat} ${l10n.savedSuccessfully}')),
        );
        await _openChatRoom(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.error}: $e')),
        );
      }
    }
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
        await _openChatRoom(result);
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

class _ChatRoomSearchDelegate extends SearchDelegate<ChatRoom?> {
  _ChatRoomSearchDelegate({
    required this.rooms,
    required this.currentUserId,
  }) : super(searchFieldLabel: 'Search chats');

  final List<ChatRoom> rooms;
  final String? currentUserId;

  List<ChatRoom> _filterRooms() {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return rooms;
    }

    return rooms.where((room) {
      final searchBuffer = <String>[
        room.getDisplayName(currentUserId),
        room.name,
        room.lastMessagePreview,
        ...room.participants.map((participant) => participant.username),
        ...room.participants.map(
          (participant) =>
              '${participant.firstName ?? ''} ${participant.lastName ?? ''}',
        ),
      ].join(' ').toLowerCase();
      return searchBuffer.contains(normalizedQuery);
    }).toList();
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildRoomList(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildRoomList(context);
  }

  Widget _buildRoomList(BuildContext context) {
    final filteredRooms = _filterRooms();

    if (filteredRooms.isEmpty) {
      return Center(
        child: Text(query.trim().isEmpty ? 'Search chats' : 'No chats found'),
      );
    }

    return ListView.builder(
      itemCount: filteredRooms.length,
      itemBuilder: (context, index) {
        final room = filteredRooms[index];
        return ChatRoomTile(
          room: room,
          currentUserId: currentUserId,
          onTap: () => close(context, room),
        );
      },
    );
  }
}

class _NewGroupChatDraft {
  const _NewGroupChatDraft({
    required this.name,
    required this.participantIds,
  });

  final String name;
  final List<String> participantIds;
}

class _GroupChatCreationDialog extends StatefulWidget {
  const _GroupChatCreationDialog({
    required this.currentUserId,
    required this.title,
    required this.cancelLabel,
    required this.createLabel,
    required this.fieldRequiredMessage,
    required this.searchUsersLabel,
  });

  final String currentUserId;
  final String title;
  final String cancelLabel;
  final String createLabel;
  final String fieldRequiredMessage;
  final String searchUsersLabel;

  @override
  State<_GroupChatCreationDialog> createState() =>
      _GroupChatCreationDialogState();
}

class _GroupChatCreationDialogState extends State<_GroupChatCreationDialog> {
  final ApiService _apiService = ApiService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedUserIds = <String>{};

  List<UserSearchResult> _users = const [];
  Timer? _debounce;
  bool _isLoading = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers({String query = ''}) async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final response = await _apiService.searchUsers(query, page: 1, limit: 30);
      if (!mounted) {
        return;
      }

      if (response['success'] == true) {
        final users = (response['data'] as List<dynamic>? ?? const [])
            .map((userData) => UserSearchResult.fromJson(userData))
            .where((user) => user.id != widget.currentUserId)
            .toList();

        setState(() {
          _users = users;
        });
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorText = 'Error loading users';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _loadUsers(query: value.trim());
    });
  }

  void _toggleUser(String userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
      _errorText = null;
    });
  }

  void _submit() {
    final trimmedName = _nameController.text.trim();

    if (trimmedName.isEmpty) {
      setState(() {
        _errorText = 'Group name is required';
      });
      return;
    }

    if (_selectedUserIds.isEmpty) {
      setState(() {
        _errorText = 'Add at least one member';
      });
      return;
    }

    Navigator.of(context).pop(
      _NewGroupChatDraft(
        name: trimmedName,
        participantIds: _selectedUserIds.toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        height: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Group name',
                border: const OutlineInputBorder(),
                errorText: _errorText == 'Group name is required'
                    ? widget.fieldRequiredMessage
                    : null,
              ),
              onChanged: (_) {
                if (_errorText != null) {
                  setState(() {
                    _errorText = null;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: widget.searchUsersLabel,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 12),
            Text(
              'Selected: ${_selectedUserIds.length}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_errorText != null && _errorText != 'Group name is required') ...[
              const SizedBox(height: 8),
              Text(
                _errorText!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _users.isEmpty
                      ? const Center(child: Text('No users found'))
                      : ListView.builder(
                          itemCount: _users.length,
                          itemBuilder: (context, index) {
                            final user = _users[index];
                            final isSelected = _selectedUserIds.contains(user.id);

                            return CheckboxListTile(
                              value: isSelected,
                              onChanged: (_) => _toggleUser(user.id),
                              secondary: CircleAvatar(
                                backgroundImage: user.avatarUrl != null
                                    ? NetworkImage(user.avatarUrl!)
                                    : null,
                                child: user.avatarUrl == null
                                    ? Text(
                                        user.username.isNotEmpty
                                            ? user.username[0].toUpperCase()
                                            : 'U',
                                      )
                                    : null,
                              ),
                              title: Text(user.username),
                              controlAffinity:
                                  ListTileControlAffinity.trailing,
                              contentPadding: EdgeInsets.zero,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancelLabel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.createLabel),
        ),
      ],
    );
  }

}

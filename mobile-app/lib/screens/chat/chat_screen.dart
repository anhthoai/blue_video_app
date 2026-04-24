import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/chat_call_service.dart';
import '../../core/services/chat_service.dart';
import '../../core/services/auth_service.dart';
import '../../models/chat_message.dart';
import '../../models/chat_participant.dart';
import '../../models/chat_room.dart';
import 'chat_call_screen.dart';
import '../../widgets/chat/message_bubble.dart';
import '../../widgets/chat/typing_indicator.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;

  const ChatScreen({super.key, required this.chatId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final ChatServiceNotifier _chatNotifier;
  ProviderSubscription<ChatServiceState>? _chatStateSubscription;
  bool _isSendingTyping = false;
  bool? _isChatMutedOverride;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _chatNotifier = ref.read(chatServiceStateProvider.notifier);
    _chatStateSubscription = ref.listenManual<ChatServiceState>(
      chatServiceStateProvider,
      (previous, next) {
        final previousCount = previous?.messages[widget.chatId]?.length ?? 0;
        final nextCount = next.messages[widget.chatId]?.length ?? 0;

        if (nextCount > previousCount) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom(animated: previousCount > 0);
          });
        }
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAndLoadMessages();
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _chatStateSubscription?.close();
    _chatNotifier.sendTypingIndicator(widget.chatId, false);
    _chatNotifier.leaveChatRoom(widget.chatId);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeAndLoadMessages() async {
    final currentUser = ref.read(currentUserProvider);
    final authService = ref.read(authServiceProvider);

    if (currentUser == null) {
      return;
    }

    final token = await authService.getAccessToken();
    if (token == null) {
      return;
    }

    _chatNotifier.initialize(currentUser.id, token);
    _chatNotifier.joinChatRoom(widget.chatId);
    await _chatNotifier.loadMessages(widget.chatId);
    if (!mounted) {
      return;
    }

    _scrollToBottom(animated: false);
  }

  void _scrollToBottom({required bool animated}) {
    if (!mounted || !_scrollController.hasClients) {
      return;
    }

    final targetOffset = _scrollController.position.maxScrollExtent;
    if (animated) {
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      return;
    }

    _scrollController.jumpTo(targetOffset);
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) {
      return;
    }

    _messageController.clear();
    await _chatNotifier.sendMessage(widget.chatId, content);
    if (!mounted) {
      return;
    }

    _sendTypingIndicator(false);
    setState(() {
      _isSendingTyping = false;
    });
    _scrollToBottom(animated: true);
  }

  void _onTextChanged(String text) {
    if (text.isNotEmpty && !_isSendingTyping) {
      setState(() {
        _isSendingTyping = true;
      });
      _sendTypingIndicator(true);
    }

    if (text.isEmpty && _isSendingTyping) {
      _typingTimer?.cancel();
      setState(() {
        _isSendingTyping = false;
      });
      _sendTypingIndicator(false);
      return;
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || !_isSendingTyping) {
        return;
      }

      setState(() {
        _isSendingTyping = false;
      });
      _sendTypingIndicator(false);
    });
  }

  void _sendTypingIndicator(bool isTyping) {
    _chatNotifier.sendTypingIndicator(widget.chatId, isTyping);
  }

  ChatRoom? _findCurrentRoom(List<ChatRoom> rooms) {
    for (final room in rooms) {
      if (room.id == widget.chatId) {
        return room;
      }
    }
    return null;
  }

  ChatRoom? _getCurrentRoom() {
    final chatState = ref.read(chatServiceStateProvider);
    return _findCurrentRoom(chatState.rooms);
  }

  ChatParticipant? _getProfileParticipant(ChatRoom room) {
    final currentUser = ref.read(currentUserProvider);
    final otherParticipants = room.getOtherParticipants(currentUser?.id);
    if (otherParticipants.isNotEmpty) {
      return otherParticipants.first;
    }
    if (room.participants.isNotEmpty) {
      return room.participants.first;
    }
    return null;
  }

  bool _isRoomMuted(ChatRoom? room) {
    return _isChatMutedOverride ?? room?.isMuted ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatServiceStateProvider);
    final messages = [
      ...(chatState.messages[widget.chatId] ?? const <ChatMessage>[])
    ]..sort((left, right) => left.createdAt.compareTo(right.createdAt));
    final isRemoteTyping = chatState.typingUsers[widget.chatId] ?? false;
    final currentRoom = _findCurrentRoom(chatState.rooms);
    final canViewProfile = currentRoom != null &&
        !currentRoom.isGroup &&
        _getProfileParticipant(currentRoom) != null;
    final isMuted = _isRoomMuted(currentRoom);

    return Scaffold(
      appBar: AppBar(
        title: _buildAppBarTitle(),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: _startVideoCall,
          ),
          IconButton(
            icon: const Icon(Icons.phone),
            onPressed: _startVoiceCall,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  _openParticipantProfile();
                  break;
                case 'info':
                  _showChatInfo();
                  break;
                case 'mute':
                  _toggleMute();
                  break;
              }
            },
            itemBuilder: (context) => [
              if (canViewProfile)
                const PopupMenuItem(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(Icons.person_outline),
                      SizedBox(width: 8),
                      Text('View Profile'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'info',
                child: Row(
                  children: [
                    Icon(Icons.info_outline),
                    SizedBox(width: 8),
                    Text('Chat Info'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'mute',
                child: Row(
                  children: [
                    Icon(
                      isMuted
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_off_outlined,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isMuted ? 'Unmute Notifications' : 'Mute Notifications',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: messages.length + (isRemoteTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (isRemoteTyping && index == messages.length) {
                        return const TypingIndicator();
                      }

                      final message = messages[index];
                      final currentUser = ref.read(currentUserProvider);
                      return MessageBubble(
                        message: message,
                        isMe: message.senderId == currentUser?.id,
                        onReply: () {
                          // Handle reply
                        },
                        onLongPress: () {
                          _showMessageOptions(message);
                        },
                      );
                    },
                  ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildAppBarTitle() {
    final chatState = ref.watch(chatServiceStateProvider);
    final currentUser = ref.watch(currentUserProvider);

    // Find the current chat room from the state
    final currentRoom = _findCurrentRoom(chatState.rooms);

    if (currentRoom == null) {
      return const Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey,
            child: Icon(Icons.person, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Chat Room',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    }

    final displayName = currentRoom.getDisplayName(currentUser?.id);
    final displayAvatar = currentRoom.getDisplayAvatar(currentUser?.id);
    final otherParticipants = currentRoom.getOtherParticipants(currentUser?.id);

    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: Colors.grey[300],
          backgroundImage: displayAvatar.isNotEmpty
              ? CachedNetworkImageProvider(displayAvatar)
              : null,
          child: displayAvatar.isEmpty
              ? Text(
                  otherParticipants.isNotEmpty &&
                          otherParticipants.first.username.isNotEmpty
                      ? otherParticipants.first.username[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(fontSize: 14),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayName,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                currentRoom.isOnline
                    ? 'Online'
                    : '${currentRoom.participants.length} members',
                style: TextStyle(
                  fontSize: 12,
                  color: currentRoom.isOnline ? Colors.green : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
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
            'No messages yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Start a conversation!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed: () {
              _showAttachmentOptions();
            },
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              onChanged: _onTextChanged,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _sendMessage,
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo, color: Colors.blue),
              title: const Text('Photo'),
              subtitle: const Text('Send photos from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.green),
              title: const Text('Camera'),
              subtitle: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.red),
              title: const Text('Video'),
              subtitle: const Text('Send a video'),
              onTap: () {
                Navigator.pop(context);
                _pickVideo();
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.insert_drive_file, color: Colors.orange),
              title: const Text('Document'),
              subtitle: const Text('Send PDF, DOC, etc.'),
              onTap: () {
                Navigator.pop(context);
                _pickDocument();
              },
            ),
            ListTile(
              leading: const Icon(Icons.audiotrack, color: Colors.purple),
              title: const Text('Audio'),
              subtitle: const Text('Send audio file'),
              onTap: () {
                Navigator.pop(context);
                _pickAudio();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        await _uploadAndSendFile(File(image.path), 'IMAGE');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _pickVideo() async {
    try {
      final picker = ImagePicker();
      final XFile? video = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );

      if (video != null) {
        await _uploadAndSendFile(File(video.path), 'VIDEO');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking video: $e')),
        );
      }
    }
  }

  Future<void> _pickDocument() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'ppt',
          'pptx',
          'txt'
        ],
      );

      if (result != null && result.files.single.path != null) {
        await _uploadAndSendFile(File(result.files.single.path!), 'FILE');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking document: $e')),
        );
      }
    }
  }

  Future<void> _pickAudio() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
      );

      if (result != null && result.files.single.path != null) {
        await _uploadAndSendFile(File(result.files.single.path!), 'AUDIO');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking audio: $e')),
        );
      }
    }
  }

  Future<void> _uploadAndSendFile(File file, String messageType) async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Uploading file...'),
              ],
            ),
            duration: Duration(minutes: 1),
          ),
        );
      }

      final chatService = ref.read(chatServiceStateProvider.notifier);

      // Upload file
      final uploadResult = await chatService.uploadChatAttachment(file);

      if (uploadResult != null) {
        // Send message with file attachment
        await chatService.sendMessage(
          widget.chatId,
          _messageController.text.trim(),
          messageType: messageType,
          fileUrl: uploadResult['fileUrl'] as String?,
          fileName: uploadResult['fileName'] as String?,
          fileDirectory: uploadResult['fileDirectory'] as String?,
          fileSize: uploadResult['fileSize'] as int?,
          mimeType: uploadResult['mimeType'] as String?,
        );

        _messageController.clear();

        // Reload messages
        await chatService.loadMessages(widget.chatId);

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File sent successfully!')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload file')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading file: $e')),
        );
      }
    }
  }

  void _showMessageOptions(ChatMessage message) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                // Handle reply
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy'),
              onTap: () {
                Navigator.pop(context);
                // Handle copy
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                // Handle edit
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(context);
                // Handle delete
              },
            ),
          ],
        ),
      ),
    );
  }

  void _startVideoCall() {
    _openCall(isVideoCall: true);
  }

  void _startVoiceCall() {
    _openCall(isVideoCall: false);
  }

  void _showChatInfo() {
    final currentRoom = _getCurrentRoom();
    final currentUser = ref.read(currentUserProvider);

    if (currentRoom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load chat details right now.')),
      );
      return;
    }

    final participants = currentRoom.getOtherParticipants(currentUser?.id);
    final profileParticipant = _getProfileParticipant(currentRoom);
    final roomAvatar = currentRoom.getDisplayAvatar(currentUser?.id);
    final roomMuted = _isRoomMuted(currentRoom);

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: roomAvatar.isNotEmpty
                        ? CachedNetworkImageProvider(roomAvatar)
                        : null,
                    child: roomAvatar.isEmpty
                        ? Text(
                            currentRoom
                                    .getDisplayName(currentUser?.id)
                                    .isNotEmpty
                                ? currentRoom
                                    .getDisplayName(currentUser?.id)[0]
                                    .toUpperCase()
                                : 'C',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentRoom.getDisplayName(currentUser?.id),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentRoom.isGroup
                              ? '${currentRoom.participantCount} members'
                              : currentRoom.isOnline
                                  ? 'Online now'
                                  : 'Direct message',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (!currentRoom.isGroup && profileParticipant != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline),
                  title: const Text('View Profile'),
                  onTap: () {
                    Navigator.pop(context);
                    _openParticipantProfile();
                  },
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  roomMuted
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_off_outlined,
                ),
                title: Text(
                  roomMuted ? 'Unmute notifications' : 'Mute notifications',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _toggleMute();
                },
              ),
              if (participants.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  currentRoom.isGroup ? 'Members' : 'Participant',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ...participants.map(
                  (participant) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey[300],
                      backgroundImage: participant.avatarUrl != null &&
                              participant.avatarUrl!.isNotEmpty
                          ? CachedNetworkImageProvider(participant.avatarUrl!)
                          : null,
                      child: participant.avatarUrl == null ||
                              participant.avatarUrl!.isEmpty
                          ? Text(
                              participant.displayName.isNotEmpty
                                  ? participant.displayName[0].toUpperCase()
                                  : 'U',
                            )
                          : null,
                    ),
                    title: Text(participant.displayName),
                    subtitle: Text('@${participant.username}'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _toggleMute() {
    final currentRoom = _getCurrentRoom();
    final nextValue = !_isRoomMuted(currentRoom);

    setState(() {
      _isChatMutedOverride = nextValue;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          nextValue
              ? 'Notifications muted for this chat.'
              : 'Notifications unmuted for this chat.',
        ),
      ),
    );
  }

  Future<void> _openCall({required bool isVideoCall}) async {
    final currentRoom = _getCurrentRoom();
    final currentUser = ref.read(currentUserProvider);
    final callController = ref.read(chatCallControllerProvider.notifier);

    if (currentRoom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to start a call right now.')),
      );
      return;
    }

    if (currentRoom.isGroup) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Group voice and video calls are not supported yet.'),
        ),
      );
      return;
    }

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in again to place a call.')),
      );
      return;
    }

    final started = await callController.startOutgoingCall(
      room: currentRoom,
      currentUser: currentUser,
      isVideoCall: isVideoCall,
    );

    if (!started) {
      if (!mounted) {
        return;
      }
      final errorMessage = ref.read(chatCallControllerProvider).errorMessage ??
          'Unable to start the call.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
      return;
    }

    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ChatCallScreen(
          room: currentRoom,
          currentUser: currentUser,
          currentUserId: currentUser.id,
          isVideoCall: isVideoCall,
          autoStartOutgoing: false,
        ),
      ),
    );

    await callController.clearFinishedCall();
  }

  void _openParticipantProfile() {
    final currentRoom = _getCurrentRoom();

    if (currentRoom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile is not available right now.')),
      );
      return;
    }

    final participant = _getProfileParticipant(currentRoom);
    if (participant == null || participant.id.isEmpty || currentRoom.isGroup) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('This chat does not have a single profile to open.')),
      );
      return;
    }

    context.push('/main/profile/${participant.id}');
  }
}

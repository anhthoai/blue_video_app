import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/chat_call_service.dart';
import '../../core/services/chat_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/dating_service.dart';
import '../../core/services/file_url_service.dart';
import '../../l10n/app_localizations.dart';
import '../../models/chat_message.dart';
import '../../models/chat_participant.dart';
import '../../models/chat_room.dart';
import '../../models/dating_model.dart';
import 'chat_call_screen.dart';
import '../dating/dating_profile_screen.dart';
import '../dating/private_album_screen.dart';
import '../../widgets/common/presigned_image.dart';
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
  DatingProfile? _otherDatingProfile;
  DatingProfile? _myDatingProfile;
  String? _loadedProfileUserId;
  bool _isLoadingProfileCard = false;
  bool _isSendingAlbumRequest = false;
  static const double _profileImageSize = 72;

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
    await _chatNotifier.loadChatRooms();
    await _loadDatingProfilesForCard();
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

  String? _getSenderAvatar(ChatMessage message, ChatRoom? room, String? currentUserId) {
    if (message.senderId == currentUserId) {
      return ref.read(currentUserProvider)?.avatarUrl;
    }

    if (room == null) {
      return message.userAvatar;
    }

    final sender = room.participants.where((participant) => participant.id == message.senderId).toList();
    if (sender.isNotEmpty) {
      return sender.first.avatarUrl;
    }

    return message.userAvatar;
  }

  Future<void> _loadDatingProfilesForCard() async {
    final room = _getCurrentRoom();
    if (room == null || room.isGroup) return;

    final participant = _getProfileParticipant(room);
    if (participant == null || participant.id.isEmpty) return;
    if (_loadedProfileUserId == participant.id && _otherDatingProfile != null) return;

    setState(() {
      _isLoadingProfileCard = true;
      _loadedProfileUserId = participant.id;
    });

    try {
      final service = DatingService();
      final results = await Future.wait([
        service.getDatingProfile(participant.id),
        service.getMyDatingProfile(),
      ]);
      if (!mounted) return;

      setState(() {
        _otherDatingProfile = results[0];
        _myDatingProfile = results[1];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _otherDatingProfile = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProfileCard = false;
        });
      }
    }
  }

  List<String> _allProfilePhotos(DatingProfile profile) {
    final photos = <String>[];
    if (profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty) {
      photos.add(profile.avatarUrl!);
    }
    photos.addAll(profile.publicPhotos);
    return photos;
  }

  List<String> _matchedExpectations(DatingProfile? me, DatingProfile? other) {
    if (me == null || other == null) return const [];
    final meSet = me.lookingFor.toSet();
    return other.lookingFor.where((item) => meSet.contains(item)).toList();
  }

  Future<void> _handlePrivateAlbumRequest() async {
    final l10n = AppLocalizations.of(context);
    final room = _getCurrentRoom();
    if (room == null || room.isGroup) return;
    final participant = _getProfileParticipant(room);
    if (participant == null || participant.id.isEmpty) return;

    final profile = _otherDatingProfile;
    if (profile?.privateAlbumAccessStatus == 'ACCEPTED') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PrivateAlbumScreen(
            targetUserId: participant.id,
            readOnly: true,
          ),
        ),
      );
      return;
    }

    if (_isSendingAlbumRequest) return;
    setState(() => _isSendingAlbumRequest = true);
    try {
      await DatingService().requestPrivateAlbumViaChat(participant.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.chatPrivateAlbumRequestSent)),
      );
      await _loadDatingProfilesForCard();
    } catch (e) {
      if (!mounted) return;
      final text = '$e'.toLowerCase();
      if (text.contains('already') || text.contains('pending')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.chatPrivateAlbumRequestAlreadySent)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.error}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingAlbumRequest = false);
      }
    }
  }

  void _openImageGallery(List<String> images, int initialIndex, DateTime? version) {
    if (images.isEmpty) return;
    final prepared = images
        .where((item) => item.isNotEmpty)
        .map((item) => appendCacheBuster(item, version) ?? item)
        .toList();
    if (prepared.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ChatImageGalleryViewer(
          images: prepared,
          initialIndex: initialIndex.clamp(0, prepared.length - 1),
        ),
      ),
    );
  }

  Widget _buildImageRow({
    required List<String> images,
    required DateTime? version,
  }) {
    return SizedBox(
      height: _profileImageSize,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: images.length.clamp(0, 8),
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => _openImageGallery(images, index, version),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: _profileImageSize,
                height: _profileImageSize,
                child: PresignedImage(
                  imageUrl: appendCacheBuster(images[index], version),
                  fit: BoxFit.cover,
                  errorWidget: Container(color: Colors.grey.shade300),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPrivateAlbumSection(DatingProfile? profile, List<String> fallbackPhotos) {
    final l10n = AppLocalizations.of(context);
    final status = profile?.privateAlbumAccessStatus;
    final privateImages = profile?.privateAlbumPhotos ?? const <String>[];
    final cover = privateImages.isNotEmpty
        ? privateImages.first
        : (fallbackPhotos.isNotEmpty ? fallbackPhotos.first : null);

    if (status == 'ACCEPTED') {
      if (privateImages.isEmpty) {
        return Container(
          height: 92,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(l10n.chatPrivateAlbumNoPhotos),
        );
      }

      return SizedBox(
        height: _profileImageSize,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: privateImages.length.clamp(0, 8),
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () => _openImageGallery(privateImages, index, profile?.updatedAt),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: _profileImageSize,
                  height: _profileImageSize,
                  child: PresignedImage(
                    imageUrl: appendCacheBuster(privateImages[index], profile?.updatedAt),
                    fit: BoxFit.cover,
                    errorWidget: Container(color: Colors.grey.shade300),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    return SizedBox(
      height: _profileImageSize,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            cover != null
                ? PresignedImage(
                    imageUrl: appendCacheBuster(cover, profile?.updatedAt),
                    fit: BoxFit.cover,
                    errorWidget: Container(color: Colors.grey.shade300),
                  )
                : Container(color: Colors.grey.shade300),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(color: Colors.black.withValues(alpha: 0.15)),
            ),
            if (status == 'PENDING')
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    l10n.chatRequestSent,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              )
            else
              Center(
                child: ElevatedButton(
                  onPressed: _isLoadingProfileCard || _isSendingAlbumRequest
                      ? null
                      : _handlePrivateAlbumRequest,
                  child: Text(l10n.chatSendRequest),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectChatProfileCard(ChatRoom room) {
    final l10n = AppLocalizations.of(context);
    final participant = _getProfileParticipant(room);
    if (participant == null) return const SizedBox.shrink();

    final profile = _otherDatingProfile;
    final photos = profile != null ? _allProfilePhotos(profile) : const <String>[];
    final matches = _matchedExpectations(_myDatingProfile, profile);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.chatProfileSnapshot,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _buildPrivateAlbumSection(profile, photos),
          const SizedBox(height: 10),
          _buildImageRow(images: photos, version: profile?.updatedAt),
          const SizedBox(height: 10),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DatingProfileScreen(userId: participant.id),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      [
                        if (profile?.age != null) '${profile!.age} ${l10n.chatYearsShort}',
                        if (profile?.heightCm != null) '${profile!.heightCm} ${l10n.chatCentimetersShort}',
                        if (profile?.weightKg != null) '${profile!.weightKg} ${l10n.chatKilogramsShort}',
                      ].join('  •  ').isEmpty
                          ? l10n.chatPersonalProfile
                          : [
                              if (profile?.age != null) '${profile!.age} ${l10n.chatYearsShort}',
                              if (profile?.heightCm != null) '${profile!.heightCm} ${l10n.chatCentimetersShort}',
                              if (profile?.weightKg != null) '${profile!.weightKg} ${l10n.chatKilogramsShort}',
                            ].join('  •  '),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.chatMatchedExpectations,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          if (matches.isEmpty)
            Text(
              l10n.chatNoMatchedExpectations,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: matches
                  .map((item) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          DatingConstants.lookingForLabels[item] ?? item,
                          style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                        ),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final chatState = ref.watch(chatServiceStateProvider);
    final messages = [
      ...(chatState.messages[widget.chatId] ?? const <ChatMessage>[])
    ]..sort((left, right) => left.createdAt.compareTo(right.createdAt));
    final currentUser = ref.watch(currentUserProvider);
    final isRemoteTyping = chatState.typingUsers[widget.chatId] ?? false;
    final currentRoom = _findCurrentRoom(chatState.rooms);
    final profileParticipant =
        currentRoom != null && !currentRoom.isGroup ? _getProfileParticipant(currentRoom) : null;
    if (profileParticipant != null && _loadedProfileUserId != profileParticipant.id && !_isLoadingProfileCard) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadDatingProfilesForCard();
      });
    }
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
                PopupMenuItem(
                  value: 'profile',
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline),
                      const SizedBox(width: 8),
                      Text(l10n.viewProfile),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: 'info',
                child: Row(
                  children: [
                    const Icon(Icons.info_outline),
                    const SizedBox(width: 8),
                    Text(l10n.chatInfo),
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
                      isMuted
                          ? l10n.chatUnmuteNotifications
                          : l10n.chatMuteNotifications,
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
            child: (messages.isEmpty && (currentRoom == null || currentRoom.isGroup))
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: messages.length +
                        (isRemoteTyping ? 1 : 0) +
                        ((currentRoom != null && !currentRoom.isGroup) ? 1 : 0),
                    itemBuilder: (context, index) {
                      final hasProfileCard = currentRoom != null && !currentRoom.isGroup;
                      if (hasProfileCard && index == 0) {
                        return _buildDirectChatProfileCard(currentRoom);
                      }

                      final messageIndex = index - (hasProfileCard ? 1 : 0);

                      if (isRemoteTyping && messageIndex == messages.length) {
                        return const TypingIndicator();
                      }

                      final message = messages[messageIndex];
                      return MessageBubble(
                        message: message,
                        isMe: message.senderId == currentUser?.id,
                        senderAvatarUrl:
                            _getSenderAvatar(message, currentRoom, currentUser?.id),
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
    final l10n = AppLocalizations.of(context);
    final chatState = ref.watch(chatServiceStateProvider);
    final currentUser = ref.watch(currentUserProvider);

    // Find the current chat room from the state
    final currentRoom = _findCurrentRoom(chatState.rooms);

    if (currentRoom == null) {
      return Row(
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey,
            child: Icon(Icons.person, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.chatRoom,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    }

    final displayName = currentRoom.getDisplayName(currentUser?.id);
    final displayAvatar = currentRoom.getDisplayAvatar(currentUser?.id);
    final otherParticipants = currentRoom.getOtherParticipants(currentUser?.id);
  final hasDistance = _otherDatingProfile?.distanceKm != null;
  final subtitleText = currentRoom.isOnline
    ? l10n.online
    : '${currentRoom.participants.length} ${l10n.chatMembers}';
  const distanceColor = Color(0xFFFFF59D);

    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: Colors.grey[300],
          child: displayAvatar.isNotEmpty
              ? ClipOval(
                  child: PresignedImage(
                    imageUrl: displayAvatar,
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                  ),
                )
              : Text(
                  otherParticipants.isNotEmpty &&
                          otherParticipants.first.username.isNotEmpty
                      ? otherParticipants.first.username[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(fontSize: 14),
                ),
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
              Row(
                children: [
                  if (hasDistance) ...[
                    const Icon(
                      Icons.location_on_outlined,
                      size: 13,
                      color: distanceColor,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      _otherDatingProfile!.distanceKm == 0
                          ? '0m'
                          : '${_otherDatingProfile!.distanceKm}km',
                      style: const TextStyle(
                        fontSize: 12,
                        color: distanceColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      subtitleText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: currentRoom.isOnline ? Colors.greenAccent.shade100 : Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
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
            l10n.chatNoMessagesYet,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.chatStartConversation,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    final l10n = AppLocalizations.of(context);
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
                hintText: '${l10n.typeMessage}...',
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
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo, color: Colors.blue),
              title: Text(l10n.chatAttachmentPhoto),
              subtitle: Text(l10n.chatAttachmentPhotoSubtitle),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.green),
              title: Text(l10n.chatAttachmentCamera),
              subtitle: Text(l10n.chatAttachmentCameraSubtitle),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.red),
              title: Text(l10n.chatAttachmentVideo),
              subtitle: Text(l10n.chatAttachmentVideoSubtitle),
              onTap: () {
                Navigator.pop(context);
                _pickVideo();
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.insert_drive_file, color: Colors.orange),
                title: Text(l10n.chatAttachmentDocument),
                subtitle: Text(l10n.chatAttachmentDocumentSubtitle),
              onTap: () {
                Navigator.pop(context);
                _pickDocument();
              },
            ),
            ListTile(
              leading: const Icon(Icons.audiotrack, color: Colors.purple),
              title: Text(l10n.chatAttachmentAudio),
              subtitle: Text(l10n.chatAttachmentAudioSubtitle),
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
    final l10n = AppLocalizations.of(context);
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
          SnackBar(content: Text('${l10n.error}: $e')),
        );
      }
    }
  }

  Future<void> _pickVideo() async {
    final l10n = AppLocalizations.of(context);
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
          SnackBar(content: Text('${l10n.error}: $e')),
        );
      }
    }
  }

  Future<void> _pickDocument() async {
    final l10n = AppLocalizations.of(context);
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
          SnackBar(content: Text('${l10n.error}: $e')),
        );
      }
    }
  }

  Future<void> _pickAudio() async {
    final l10n = AppLocalizations.of(context);
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
          SnackBar(content: Text('${l10n.error}: $e')),
        );
      }
    }
  }

  Future<void> _uploadAndSendFile(File file, String messageType) async {
    final l10n = AppLocalizations.of(context);
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 16),
                Text(l10n.chatUploadingFile),
              ],
            ),
            duration: const Duration(minutes: 1),
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
            SnackBar(content: Text(l10n.chatFileSentSuccessfully)),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.chatFailedToUploadFile)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.errorUploadingFile}: $e')),
        );
      }
    }
  }

  void _showMessageOptions(ChatMessage message) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply),
              title: Text(l10n.reply),
              onTap: () {
                Navigator.pop(context);
                // Handle reply
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: Text(l10n.copy),
              onTap: () {
                Navigator.pop(context);
                // Handle copy
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(l10n.edit),
              onTap: () {
                Navigator.pop(context);
                // Handle edit
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: Text(l10n.delete),
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
    final l10n = AppLocalizations.of(context);
    final currentRoom = _getCurrentRoom();
    final currentUser = ref.read(currentUserProvider);

    if (currentRoom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.chatUnableToLoadDetails)),
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
                    child: roomAvatar.isNotEmpty
                        ? ClipOval(
                            child: PresignedImage(
                              imageUrl: roomAvatar,
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Text(
                            currentRoom
                                    .getDisplayName(currentUser?.id)
                                    .isNotEmpty
                                ? currentRoom
                                    .getDisplayName(currentUser?.id)[0]
                                    .toUpperCase()
                                : 'C',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
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
                              ? '${currentRoom.participantCount} ${l10n.chatMembers}'
                              : currentRoom.isOnline
                                ? l10n.chatOnlineNow
                                : l10n.chatDirectMessage,
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
                  title: Text(l10n.viewProfile),
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
                  roomMuted
                      ? l10n.chatUnmuteNotifications
                      : l10n.chatMuteNotifications,
                ),
                onTap: () {
                  Navigator.pop(context);
                  _toggleMute();
                },
              ),
              if (participants.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  currentRoom.isGroup ? l10n.chatMembers : l10n.chatParticipant,
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
                      child: participant.avatarUrl != null && participant.avatarUrl!.isNotEmpty
                          ? ClipOval(
                              child: PresignedImage(
                                imageUrl: participant.avatarUrl,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Text(
                              participant.displayName.isNotEmpty
                                  ? participant.displayName[0].toUpperCase()
                                  : 'U',
                            ),
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
    final l10n = AppLocalizations.of(context);
    final currentRoom = _getCurrentRoom();
    final nextValue = !_isRoomMuted(currentRoom);

    setState(() {
      _isChatMutedOverride = nextValue;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          nextValue
              ? l10n.chatNotificationsMuted
              : l10n.chatNotificationsUnmuted,
        ),
      ),
    );
  }

  Future<void> _openCall({required bool isVideoCall}) async {
    final l10n = AppLocalizations.of(context);
    final currentRoom = _getCurrentRoom();
    final currentUser = ref.read(currentUserProvider);
    final callController = ref.read(chatCallControllerProvider.notifier);

    if (currentRoom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.chatUnableToStartCall)),
      );
      return;
    }

    if (currentRoom.isGroup) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.chatGroupCallNotSupported)),
      );
      return;
    }

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.chatSignInToCall)),
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
          l10n.chatUnableToStartCallGeneric;
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
    final l10n = AppLocalizations.of(context);
    final currentRoom = _getCurrentRoom();

    if (currentRoom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.chatProfileUnavailable)),
      );
      return;
    }

    final participant = _getProfileParticipant(currentRoom);
    if (participant == null || participant.id.isEmpty || currentRoom.isGroup) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.chatSingleProfileUnavailable)),
      );
      return;
    }

    context.push('/main/profile/${participant.id}');
  }
}

class _ChatImageGalleryViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _ChatImageGalleryViewer({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_ChatImageGalleryViewer> createState() => _ChatImageGalleryViewerState();
}

class _ChatImageGalleryViewerState extends State<_ChatImageGalleryViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1}/${widget.images.length}'),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.images.length,
        onPageChanged: (value) {
          setState(() {
            _index = value;
          });
        },
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Center(
              child: PresignedImage(
                imageUrl: widget.images[index],
                fit: BoxFit.contain,
                errorWidget: const Icon(Icons.broken_image, color: Colors.white54, size: 40),
              ),
            ),
          );
        },
      ),
    );
  }
}

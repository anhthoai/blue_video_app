import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/chat_room.dart';
import '../common/presigned_image.dart';

class ChatRoomTile extends StatelessWidget {
  final ChatRoom room;
  final String? currentUserId;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ChatRoomTile({
    super.key,
    required this.room,
    this.currentUserId,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      leading: _buildAvatar(context),
      title: Row(
        children: [
          Expanded(
            child: Text(
              room.getDisplayName(currentUserId),
              style: TextStyle(
                fontWeight: room.hasUnreadMessages
                    ? FontWeight.w600
                    : FontWeight.normal,
                fontSize: 16,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (room.isPinned)
            const Icon(
              Icons.push_pin,
              size: 16,
              color: Colors.grey,
            ),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              _localizedLastMessagePreview(context),
              style: TextStyle(
                color:
                    room.hasUnreadMessages ? Colors.black87 : Colors.grey[600],
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            room.lastMessageTime,
            style: TextStyle(
              color: room.hasUnreadMessages ? Colors.black87 : Colors.grey[500],
              fontSize: 12,
            ),
          ),
        ],
      ),
      trailing: room.hasUnreadMessages
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                room.unreadCount > 99 ? '99+' : room.unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
    );
  }

  String _localizedLastMessagePreview(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final message = room.lastMessage;
    final metaType = message?.metadata?['type'] as String?;

    if (metaType == 'private_album_request') {
      return l10n.chatPrivateAlbumRequestText;
    }
    if (metaType == 'private_album_response') {
      return l10n.chatPrivateAlbumUnlockedText;
    }

    final preview = room.lastMessagePreview;
    final normalized = preview.trim().toLowerCase();
    if (normalized == 'may i check out your private album?') {
      return l10n.chatPrivateAlbumRequestText;
    }
    if (normalized == 'i have unlocked my privacy album to you') {
      return l10n.chatPrivateAlbumUnlockedText;
    }
    return preview;
  }

  Widget _buildAvatar(BuildContext context) {
    if (room.isGroup) {
      // Show multiple avatars for group chats
      final firstTwo = room.getFirstTwoParticipants(currentUserId);

      if (firstTwo.length >= 2) {
        return SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: firstTwo[0].avatarUrl != null &&
                          firstTwo[0].avatarUrl!.isNotEmpty
                      ? ClipOval(
                          child: PresignedImage(
                            imageUrl: firstTwo[0].avatarUrl,
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                          ),
                        )
                      : CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.grey[300],
                          child: Text(
                            firstTwo[0].username.isNotEmpty
                                ? firstTwo[0].username[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: firstTwo[1].avatarUrl != null &&
                          firstTwo[1].avatarUrl!.isNotEmpty
                      ? ClipOval(
                          child: PresignedImage(
                            imageUrl: firstTwo[1].avatarUrl,
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                          ),
                        )
                      : CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.grey[300],
                          child: Text(
                            firstTwo[1].username.isNotEmpty
                                ? firstTwo[1].username[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      }
    }

    // Single avatar for individual chats or groups with < 2 participants
    final displayAvatar = room.getDisplayAvatar(currentUserId);
    final otherParticipants = room.getOtherParticipants(currentUserId);
    final isOnline = room.isOnline;

    return Stack(
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: displayAvatar.isNotEmpty
              ? ClipOval(
                  child: PresignedImage(
                    imageUrl: displayAvatar,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorWidget: CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.grey[300],
                      child: Text(
                        otherParticipants.isNotEmpty
                            ? (otherParticipants.first.username.isNotEmpty
                                ? otherParticipants.first.username[0]
                                    .toUpperCase()
                                : 'U')
                            : 'U',
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                )
              : CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey[300],
                  child: Text(
                    otherParticipants.isNotEmpty
                        ? (otherParticipants.first.username.isNotEmpty
                            ? otherParticipants.first.username[0].toUpperCase()
                            : 'U')
                        : 'U',
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
        ),
        if (!room.isGroup)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: isOnline ? Colors.green : Colors.grey,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

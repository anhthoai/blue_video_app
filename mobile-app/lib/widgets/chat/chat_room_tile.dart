import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/chat_room.dart';

class ChatRoomTile extends StatelessWidget {
  final ChatRoom room;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ChatRoomTile({
    super.key,
    required this.room,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey[300],
            backgroundImage: room.displayAvatar.isNotEmpty
                ? CachedNetworkImageProvider(room.displayAvatar)
                : null,
            child: room.displayAvatar.isEmpty
                ? const Icon(Icons.person, size: 24)
                : null,
          ),
          if (room.isOnline)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              room.displayName,
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
              room.lastMessagePreview,
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
}

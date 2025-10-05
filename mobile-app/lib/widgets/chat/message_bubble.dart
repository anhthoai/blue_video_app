import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/chat_message.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final VoidCallback? onReply;
  final VoidCallback? onLongPress;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onReply,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => onLongPress?.call(),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
              CircleAvatar(
                key: ValueKey('avatar_${message.userId}_${message.userAvatar}'),
                radius: 16,
                backgroundColor: Colors.grey[300],
                backgroundImage:
                    message.userAvatar != null && message.userAvatar!.isNotEmpty
                        ? CachedNetworkImageProvider(message.userAvatar!)
                        : null,
                child: message.userAvatar == null || message.userAvatar!.isEmpty
                    ? Text(
                        message.username.isNotEmpty
                            ? message.username[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isMe
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[200],
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: isMe
                        ? const Radius.circular(20)
                        : const Radius.circular(4),
                    bottomRight: isMe
                        ? const Radius.circular(4)
                        : const Radius.circular(20),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.replyToMessageId != null)
                      _buildReplyPreview(context),
                    _buildMessageContent(context),
                    const SizedBox(height: 4),
                    _buildMessageFooter(context),
                  ],
                ),
              ),
            ),
            if (isMe) ...[
              const SizedBox(width: 8),
              CircleAvatar(
                key: ValueKey('avatar_${message.userId}_${message.userAvatar}'),
                radius: 16,
                backgroundColor: Colors.grey[300],
                backgroundImage:
                    message.userAvatar != null && message.userAvatar!.isNotEmpty
                        ? CachedNetworkImageProvider(message.userAvatar!)
                        : null,
                child: message.userAvatar == null || message.userAvatar!.isEmpty
                    ? Text(
                        message.username.isNotEmpty
                            ? message.username[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      )
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReplyPreview(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withOpacity(0.2) : Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isMe ? Colors.white : Colors.grey[400]!,
            width: 3,
          ),
        ),
      ),
      child: const Text(
        'Replying to: This is a sample reply message',
        style: TextStyle(
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    switch (message.messageType) {
      case MessageType.text:
        return Text(
          message.content,
          style: TextStyle(
            color: isMe ? Colors.white : Colors.black87,
            fontSize: 16,
          ),
        );
      case MessageType.image:
        return _buildImageMessage(context);
      case MessageType.video:
        return _buildVideoMessage(context);
      case MessageType.audio:
        return _buildAudioMessage(context);
      case MessageType.file:
        return _buildFileMessage(context);
      case MessageType.location:
        return _buildLocationMessage(context);
      case MessageType.sticker:
        return _buildStickerMessage(context);
      case MessageType.system:
        return _buildSystemMessage(context);
    }
  }

  Widget _buildImageMessage(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: message.attachments?.first ?? '',
        width: 200,
        height: 200,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: 200,
          height: 200,
          color: Colors.grey[300],
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          width: 200,
          height: 200,
          color: Colors.grey[300],
          child: const Icon(Icons.error),
        ),
      ),
    );
  }

  Widget _buildVideoMessage(BuildContext context) {
    return Container(
      width: 200,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          // Video thumbnail would go here
          Container(
            width: 200,
            height: 120,
            color: Colors.grey[800],
            child: const Center(
              child: Icon(Icons.play_circle_outline,
                  color: Colors.white, size: 48),
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '2:30',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioMessage(BuildContext context) {
    return Container(
      width: 200,
      height: 40,
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withOpacity(0.2) : Colors.grey[300],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.play_arrow,
              color: isMe ? Colors.white : Colors.black,
            ),
            onPressed: () {
              // Play audio
            },
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: 0.3,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                isMe ? Colors.white : Colors.grey[400]!,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Text(
              '1:23',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileMessage(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withOpacity(0.2) : Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.attach_file,
            color: isMe ? Colors.white : Colors.black,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'document.pdf',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const Text(
                  '2.4 MB',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(
            Icons.download,
            color: isMe ? Colors.white : Colors.black,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationMessage(BuildContext context) {
    return Container(
      width: 200,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          // Map preview would go here
          Container(
            width: 200,
            height: 120,
            color: Colors.grey[400],
            child: const Center(
              child: Icon(Icons.location_on, color: Colors.red, size: 32),
            ),
          ),
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Current Location',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickerMessage(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Text(
          '😀',
          style: TextStyle(fontSize: 48),
        ),
      ),
    );
  }

  Widget _buildSystemMessage(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message.content,
        style: const TextStyle(
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildMessageFooter(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message.shortTime,
          style: TextStyle(
            color: isMe ? Colors.white.withOpacity(0.7) : Colors.grey[600],
            fontSize: 12,
          ),
        ),
        if (isMe) ...[
          const SizedBox(width: 4),
          Icon(
            message.isRead ? Icons.done_all : Icons.done,
            size: 16,
            color: message.isRead ? Colors.blue : Colors.white.withOpacity(0.7),
          ),
        ],
        if (message.isEdited) ...[
          const SizedBox(width: 4),
          Text(
            'edited',
            style: TextStyle(
              color: isMe ? Colors.white.withOpacity(0.7) : Colors.grey[600],
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }
}

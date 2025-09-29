import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/services/social_service.dart';
import '../../models/comment_model.dart';
import '../../models/like_model.dart';
import 'like_button.dart';

class CommentWidget extends ConsumerStatefulWidget {
  final CommentModel comment;
  final String currentUserId;
  final VoidCallback? onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const CommentWidget({
    super.key,
    required this.comment,
    required this.currentUserId,
    this.onReply,
    this.onEdit,
    this.onDelete,
  });

  @override
  ConsumerState<CommentWidget> createState() => _CommentWidgetState();
}

class _CommentWidgetState extends ConsumerState<CommentWidget> {
  bool _showReplies = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMainComment(),
          if (widget.comment.hasReplies) ...[
            const SizedBox(height: 8),
            _buildRepliesSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildMainComment() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey[300],
                backgroundImage: widget.comment.userAvatar.isNotEmpty
                    ? CachedNetworkImageProvider(widget.comment.userAvatar)
                    : null,
                child: widget.comment.userAvatar.isEmpty
                    ? const Icon(Icons.person, size: 16)
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.comment.username,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      widget.comment.formattedTime,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'reply':
                      widget.onReply?.call();
                      break;
                    case 'edit':
                      if (widget.comment.userId == widget.currentUserId) {
                        widget.onEdit?.call();
                      }
                      break;
                    case 'delete':
                      if (widget.comment.userId == widget.currentUserId) {
                        widget.onDelete?.call();
                      }
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'reply',
                    child: Row(
                      children: [
                        Icon(Icons.reply, size: 16),
                        SizedBox(width: 8),
                        Text('Reply'),
                      ],
                    ),
                  ),
                  if (widget.comment.userId == widget.currentUserId) ...[
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 16),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.comment.content,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              LikeButton(
                targetId: widget.comment.id,
                type: LikeType.comment,
                userId: widget.currentUserId,
                initialLikeCount: widget.comment.likes,
                initialIsLiked: widget.comment.isLiked,
                size: 18,
                showCount: true,
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: widget.onReply,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.reply,
                      size: 18,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Reply',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.comment.hasReplies) ...[
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showReplies = !_showReplies;
                    });
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showReplies
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 18,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.comment.totalReplies} ${widget.comment.totalReplies == 1 ? 'reply' : 'replies'}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRepliesSection() {
    if (!_showReplies) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(left: 24),
      child: Column(
        children: widget.comment.replies.map((reply) {
          return CommentWidget(
            comment: reply,
            currentUserId: widget.currentUserId,
            onReply: () {
              // Handle reply to reply
            },
            onEdit: () {
              // Handle edit reply
            },
            onDelete: () {
              // Handle delete reply
            },
          );
        }).toList(),
      ),
    );
  }
}

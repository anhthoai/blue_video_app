import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/social_service.dart';
import '../../models/comment_model.dart';
import 'comment_widget.dart';
import '../common/presigned_image.dart';
import '../../l10n/app_localizations.dart';

class CommentsSection extends ConsumerStatefulWidget {
  final String videoId;
  final String currentUserId;
  final String currentUsername;
  final String currentUserAvatar;

  const CommentsSection({
    super.key,
    required this.videoId,
    required this.currentUserId,
    required this.currentUsername,
    required this.currentUserAvatar,
  });

  @override
  ConsumerState<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends ConsumerState<CommentsSection> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Load comments after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadComments();
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final socialService = ref.read(socialServiceStateProvider.notifier);
      await socialService.loadComments(widget.videoId, contentType: 'VIDEO');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addComment({String? parentCommentId}) async {
    if (_commentController.text.trim().isEmpty) return;

    final content = _commentController.text.trim();
    _commentController.clear();

    try {
      final socialService = ref.read(socialServiceStateProvider.notifier);
      await socialService.addComment(
        videoId: widget.videoId,
        userId: widget.currentUserId,
        username: widget.currentUsername,
        userAvatar: widget.currentUserAvatar,
        content: content,
        parentCommentId: parentCommentId,
        contentType: 'VIDEO', // This is for videos
      );

      // Scroll to top to show new comment
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add comment: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final socialState = ref.watch(socialServiceStateProvider);
    final comments = socialState.comments[widget.videoId] ?? [];

    return Container(
      height: 400,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  AppLocalizations.of(context).viewComments,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${comments.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Comments list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : comments.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: comments.length,
                        itemBuilder: (context, index) {
                          final comment = comments[index];
                          return Column(
                            children: [
                              CommentWidget(
                                comment: comment,
                                currentUserId: widget.currentUserId,
                                onReply: () {
                                  _showReplyDialog(comment);
                                },
                                onEdit: () {
                                  _showEditDialog(comment);
                                },
                                onDelete: () {
                                  _showDeleteDialog(comment);
                                },
                                onLike: () {
                                  _toggleCommentLike(comment);
                                },
                              ),
                              // Render replies with their own callbacks
                              if (comment.replies.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                ...comment.replies.map((reply) => Padding(
                                      padding: const EdgeInsets.only(
                                          left: 24, top: 8),
                                      child: CommentWidget(
                                        comment: reply,
                                        currentUserId: widget.currentUserId,
                                        onReply: () {
                                          _showReplyDialog(
                                              comment); // Reply to parent comment
                                        },
                                        onEdit: () {
                                          _showEditDialog(
                                              reply); // Edit the specific reply
                                        },
                                        onDelete: () {
                                          _showDeleteDialog(
                                              reply); // Delete the specific reply
                                        },
                                        onLike: () {
                                          _toggleCommentLike(
                                              reply); // Like the specific reply
                                        },
                                        isReply: true,
                                      ),
                                    )),
                              ],
                              const SizedBox(height: 16),
                            ],
                          );
                        },
                      ),
          ),
          // Comment input
          _buildCommentInput(),
        ],
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
            size: 48,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noCommentsYet,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.beTheFirstToComment,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          top: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: widget.currentUserAvatar.isNotEmpty
                ? ClipOval(
                    child: PresignedImage(
                      imageUrl: widget.currentUserAvatar,
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                      errorWidget: const CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.grey,
                        child: Icon(Icons.person, size: 16),
                      ),
                    ),
                  )
                : const CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.person, size: 16),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context).addComment,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _addComment,
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showReplyDialog(CommentModel parentComment) {
    final replyController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reply to ${parentComment.username}'),
        content: TextField(
          controller: replyController,
          decoration: const InputDecoration(
            hintText: 'Write a reply...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (replyController.text.trim().isNotEmpty) {
                Navigator.pop(context);

                try {
                  final socialService =
                      ref.read(socialServiceStateProvider.notifier);
                  await socialService.addComment(
                    videoId: widget.videoId,
                    userId: widget.currentUserId,
                    username: widget.currentUsername,
                    userAvatar: widget.currentUserAvatar,
                    content: replyController.text.trim(),
                    parentCommentId: parentComment.id,
                    contentType: 'VIDEO', // This is for videos
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to add reply: $e')),
                  );
                }
              }
            },
            child: const Text('Reply'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(CommentModel comment) {
    final editController = TextEditingController(text: comment.content);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Comment'),
        content: TextField(
          controller: editController,
          decoration: const InputDecoration(
            hintText: 'Edit your comment...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (editController.text.trim().isNotEmpty) {
                Navigator.pop(context);

                try {
                  final socialService =
                      ref.read(socialServiceStateProvider.notifier);
                  await socialService.editComment(
                    comment.id,
                    widget.videoId,
                    editController.text.trim(),
                  );

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Comment updated successfully')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to edit comment: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(CommentModel comment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text(
            'Are you sure you want to delete this comment? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                final socialService =
                    ref.read(socialServiceStateProvider.notifier);
                await socialService.deleteComment(comment.id, widget.videoId);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Comment deleted successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to delete comment: $e')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleCommentLike(CommentModel comment) async {
    try {
      final socialService = ref.read(socialServiceStateProvider.notifier);
      await socialService.toggleCommentLike(comment.id, widget.videoId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to toggle like: $e')),
      );
    }
  }
}

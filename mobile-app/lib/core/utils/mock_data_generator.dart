import 'dart:math';

import '../../models/community_post.dart';
import '../../models/user_model.dart';
import '../../models/video_model.dart';
import '../../models/chat_room.dart';
import '../../models/chat_message.dart';

class MockDataGenerator {
  static final Random _random = Random();

  // Generate mock users
  static List<UserModel> generateUsers(int count) {
    return List.generate(count, (index) {
      return UserModel(
        id: 'user_$index',
        username: 'User$index',
        email: 'user$index@example.com',
        avatarUrl: 'https://picsum.photos/100/100?random=$index',
        bio: 'This is user $index bio',
        followerCount: _random.nextInt(10000),
        followingCount: _random.nextInt(1000),
        videoCount: _random.nextInt(100),
        likeCount: _random.nextInt(50000),
        createdAt:
            DateTime.now().subtract(Duration(days: _random.nextInt(365))),
      );
    });
  }

  // Generate mock videos
  static List<VideoModel> generateVideos(int count) {
    return List.generate(count, (index) {
      return VideoModel(
        id: 'video_$index',
        userId: 'user_${_random.nextInt(10)}',
        title: 'Sample Video $index',
        description: 'This is a sample video description $index',
        videoUrl: 'https://example.com/video$index.mp4',
        thumbnailUrl: 'https://picsum.photos/400/300?random=$index',
        duration: _random.nextInt(600) + 30, // 30 seconds to 10 minutes
        viewCount: _random.nextInt(100000),
        likeCount: _random.nextInt(10000),
        commentCount: _random.nextInt(1000),
        shareCount: _random.nextInt(500),
        isPublic: true,
        isFeatured: index < 5,
        createdAt:
            DateTime.now().subtract(Duration(hours: _random.nextInt(168))),
        tags: _generateRandomTags(),
        category: _getRandomCategory(),
      );
    });
  }

  // Generate mock community posts
  static List<CommunityPost> generateCommunityPosts(int count) {
    final postTypes = PostType.values;
    return List.generate(count, (index) {
      final postType = postTypes[_random.nextInt(postTypes.length)];
      return CommunityPost(
        id: 'post_$index',
        userId: 'user_${_random.nextInt(10)}',
        username: 'User${_random.nextInt(10)}',
        userAvatar: 'https://picsum.photos/50/50?random=${_random.nextInt(10)}',
        title: 'Community Post $index',
        content: _generatePostContent(postType),
        type: postType,
        images: postType == PostType.media
            ? [
                'https://picsum.photos/400/300?random=$index',
                'https://picsum.photos/400/300?random=${index + 100}',
              ]
            : [],
        videos: postType == PostType.media
            ? ['https://example.com/video$index.mp4']
            : [],
        videoUrl: null,
        linkUrl:
            postType == PostType.link ? 'https://example.com/link$index' : null,
        linkTitle: postType == PostType.link ? 'Link Title $index' : null,
        linkDescription:
            postType == PostType.link ? 'Link description $index' : null,
        linkThumbnail: postType == PostType.link
            ? 'https://picsum.photos/200/150?random=$index'
            : null,
        pollData: postType == PostType.poll ? _generatePollData() : null,
        tags: _generateRandomTags(),
        category: _getRandomCategory(),
        likes: _random.nextInt(1000),
        comments: _random.nextInt(100),
        shares: _random.nextInt(50),
        views: _random.nextInt(5000),
        isLiked: _random.nextBool(),
        isBookmarked: _random.nextBool(),
        isPinned: index < 3,
        isFeatured: index < 5,
        createdAt:
            DateTime.now().subtract(Duration(hours: _random.nextInt(168))),
      );
    });
  }

  // Generate mock chat rooms
  static List<ChatRoom> generateChatRooms(int count) {
    return List.generate(count, (index) {
      final participants = generateUsers(2 + _random.nextInt(3));
      return ChatRoom(
        id: 'room_$index',
        name: index < 3 ? 'Group Chat $index' : 'Private Chat $index',
        isGroup: index < 3,
        participants: participants,
        lastMessage: ChatMessage(
          id: 'msg_$index',
          roomId: 'room_$index',
          senderId: participants.first.id,
          content: 'This is the last message $index',
          timestamp:
              DateTime.now().subtract(Duration(minutes: _random.nextInt(60))),
          messageType: MessageType.text,
          isRead: _random.nextBool(),
        ),
        unreadCount: _random.nextInt(10),
        createdAt: DateTime.now().subtract(Duration(days: _random.nextInt(30))),
      );
    });
  }

  // Generate mock chat messages
  static List<ChatMessage> generateChatMessages(String roomId, int count) {
    return List.generate(count, (index) {
      final messageTypes = MessageType.values;
      return ChatMessage(
        id: 'msg_${roomId}_$index',
        roomId: roomId,
        senderId: 'user_${_random.nextInt(10)}',
        content: _generateMessageContent(
            messageTypes[_random.nextInt(messageTypes.length)]),
        timestamp: DateTime.now().subtract(Duration(minutes: index * 5)),
        messageType: messageTypes[_random.nextInt(messageTypes.length)],
        isRead: _random.nextBool(),
      );
    });
  }

  // Helper methods
  static String _generatePostContent(PostType type) {
    switch (type) {
      case PostType.text:
        return 'This is a text post with some interesting content to read.';
      case PostType.media:
        return 'Check out this amazing media content I created!';
      case PostType.link:
        return 'Found this interesting article, thought you might like it!';
      case PostType.poll:
        return 'What do you think? Vote in the poll below!';
    }
  }

  static String _generateMessageContent(MessageType type) {
    switch (type) {
      case MessageType.text:
        return 'This is a sample text message.';
      case MessageType.image:
        return '📸 Image';
      case MessageType.video:
        return '🎥 Video';
      case MessageType.audio:
        return '🎵 Audio';
      case MessageType.file:
        return '📄 File';
      case MessageType.location:
        return '📍 Location';
      case MessageType.sticker:
        return '😀 Sticker';
      case MessageType.system:
        return 'System message';
    }
  }

  static List<String> _generateRandomTags() {
    final allTags = [
      'flutter',
      'dart',
      'mobile',
      'app',
      'video',
      'social',
      'community',
      'tech',
      'fun',
      'cool'
    ];
    final tagCount = _random.nextInt(3) + 1;
    return allTags.take(tagCount).toList();
  }

  static String _getRandomCategory() {
    final categories = [
      'general',
      'technology',
      'entertainment',
      'sports',
      'news',
      'lifestyle'
    ];
    return categories[_random.nextInt(categories.length)];
  }

  static Map<String, dynamic> _generatePollData() {
    return {
      'question': 'What is your favorite programming language?',
      'options': ['Flutter/Dart', 'React/JavaScript', 'Swift', 'Kotlin'],
      'votes': {
        'option_0': _random.nextInt(100),
        'option_1': _random.nextInt(100),
        'option_2': _random.nextInt(100),
        'option_3': _random.nextInt(100),
      },
    };
  }
}

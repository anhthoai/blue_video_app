import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

import '../../models/chat_message.dart';
import '../../models/chat_room.dart';
import '../../models/user_model.dart';

class ChatService {
  WebSocketChannel? _channel;
  StreamController<ChatMessage>? _messageController;
  StreamController<ChatRoom>? _roomController;
  String? _currentUserId;
  String? _authToken;
  bool _isConnected = false;
  Timer? _heartbeatTimer;

  // Getters
  bool get isConnected => _isConnected;
  Stream<ChatMessage>? get messageStream => _messageController?.stream;
  Stream<ChatRoom>? get roomStream => _roomController?.stream;

  // Initialize chat service
  void initialize(String userId, String authToken) {
    _currentUserId = userId;
    _authToken = authToken;
    _messageController = StreamController<ChatMessage>.broadcast();
    _roomController = StreamController<ChatRoom>.broadcast();
  }

  // Connect to WebSocket server
  Future<void> connect() async {
    if (_isConnected) return;

    try {
      // In a real app, this would be your WebSocket server URL
      const wsUrl = 'wss://api.bluevideoapp.com/chat';

      _channel = WebSocketChannel.connect(
        Uri.parse(wsUrl),
        protocols: ['chat'],
      );

      // Listen to incoming messages
      _channel!.stream.listen(
        _handleIncomingMessage,
        onError: _handleError,
        onDone: _handleDisconnection,
      );

      // Send authentication message
      await _sendAuthMessage();

      _isConnected = true;
      _startHeartbeat();
    } catch (e) {
      print('WebSocket connection failed: $e');
      _isConnected = false;
    }
  }

  // Disconnect from WebSocket server
  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    await _channel?.sink.close(status.goingAway);
    _channel = null;
    _isConnected = false;
  }

  // Send authentication message
  Future<void> _sendAuthMessage() async {
    if (_channel == null || _authToken == null) return;

    final authMessage = {
      'type': 'auth',
      'userId': _currentUserId,
      'token': _authToken,
    };

    _channel!.sink.add(jsonEncode(authMessage));
  }

  // Handle incoming messages
  void _handleIncomingMessage(dynamic data) {
    try {
      final messageData = jsonDecode(data);
      final messageType = messageData['type'];

      switch (messageType) {
        case 'message':
          final message = ChatMessage.fromJson(messageData['data']);
          _messageController?.add(message);
          break;
        case 'room_update':
          final room = ChatRoom.fromJson(messageData['data']);
          _roomController?.add(room);
          break;
        case 'typing':
          // Handle typing indicators
          break;
        case 'user_online':
          // Handle user online status
          break;
        case 'pong':
          // Handle heartbeat response
          break;
      }
    } catch (e) {
      print('Error handling incoming message: $e');
    }
  }

  // Handle WebSocket errors
  void _handleError(error) {
    print('WebSocket error: $error');
    _isConnected = false;
  }

  // Handle disconnection
  void _handleDisconnection() {
    print('WebSocket disconnected');
    _isConnected = false;
  }

  // Start heartbeat to keep connection alive
  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isConnected && _channel != null) {
        _channel!.sink.add(jsonEncode({'type': 'ping'}));
      }
    });
  }

  // Send a message
  Future<void> sendMessage({
    required String roomId,
    required String content,
    String? replyToMessageId,
    List<String>? attachments,
  }) async {
    if (!_isConnected || _channel == null) {
      throw Exception('Not connected to chat server');
    }

    final message = {
      'type': 'send_message',
      'data': {
        'roomId': roomId,
        'content': content,
        'replyToMessageId': replyToMessageId,
        'attachments': attachments,
        'timestamp': DateTime.now().toIso8601String(),
      }
    };

    _channel!.sink.add(jsonEncode(message));
  }

  // Join a chat room
  Future<void> joinRoom(String roomId) async {
    if (!_isConnected || _channel == null) return;

    final message = {
      'type': 'join_room',
      'data': {'roomId': roomId}
    };

    _channel!.sink.add(jsonEncode(message));
  }

  // Leave a chat room
  Future<void> leaveRoom(String roomId) async {
    if (!_isConnected || _channel == null) return;

    final message = {
      'type': 'leave_room',
      'data': {'roomId': roomId}
    };

    _channel!.sink.add(jsonEncode(message));
  }

  // Send typing indicator
  Future<void> sendTypingIndicator(String roomId, bool isTyping) async {
    if (!_isConnected || _channel == null) return;

    final message = {
      'type': 'typing',
      'data': {
        'roomId': roomId,
        'isTyping': isTyping,
      }
    };

    _channel!.sink.add(jsonEncode(message));
  }

  // Create a new chat room
  Future<void> createRoom({
    required String name,
    required List<String> participantIds,
    bool isGroup = false,
  }) async {
    if (!_isConnected || _channel == null) return;

    final message = {
      'type': 'create_room',
      'data': {
        'name': name,
        'participantIds': participantIds,
        'isGroup': isGroup,
      }
    };

    _channel!.sink.add(jsonEncode(message));
  }

  // Get chat rooms (mock implementation)
  Future<List<ChatRoom>> getChatRooms() async {
    // In a real app, this would fetch from your API
    await Future.delayed(const Duration(seconds: 1));

    return List.generate(5, (index) {
      return ChatRoom(
        id: 'room_$index',
        name: index == 0 ? 'John Doe' : 'Group Chat ${index + 1}',
        isGroup: index > 0,
        participants: List.generate(
          index == 0 ? 2 : 3 + index,
          (i) => UserModel(
            id: 'user_$i',
            username: 'user_$i',
            email: 'user$i@example.com',
            avatarUrl: 'https://picsum.photos/50/50?random=$i',
            createdAt: DateTime.now().subtract(Duration(days: i)),
          ),
        ),
        lastMessage: ChatMessage(
          id: 'msg_$index',
          roomId: 'room_$index',
          senderId: 'user_${index % 3}',
          content: 'This is a sample message ${index + 1}',
          timestamp: DateTime.now().subtract(Duration(minutes: index * 10)),
          messageType: MessageType.text,
        ),
        unreadCount: index,
        isOnline: index % 2 == 0,
        createdAt: DateTime.now().subtract(Duration(days: index)),
      );
    });
  }

  // Get messages for a room (mock implementation)
  Future<List<ChatMessage>> getMessages(String roomId, {int limit = 50}) async {
    await Future.delayed(const Duration(seconds: 1));

    return List.generate(limit, (index) {
      return ChatMessage(
        id: 'msg_${roomId}_$index',
        roomId: roomId,
        senderId: 'user_${index % 3}',
        content: 'Sample message $index in room $roomId',
        timestamp: DateTime.now().subtract(Duration(minutes: index)),
        messageType: MessageType.text,
        isRead: index < 10,
        replyToMessageId: index > 5 ? 'msg_${roomId}_${index - 1}' : null,
      );
    });
  }

  // Dispose resources
  void dispose() {
    disconnect();
    _messageController?.close();
    _roomController?.close();
  }
}

// Provider
final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService();
});

// Chat service state provider
final chatServiceStateProvider =
    StateNotifierProvider<ChatServiceNotifier, ChatServiceState>((ref) {
  return ChatServiceNotifier();
});

// Chat service state
class ChatServiceState {
  final bool isConnected;
  final bool isConnecting;
  final String? error;
  final List<ChatRoom> rooms;
  final Map<String, List<ChatMessage>> messages;

  const ChatServiceState({
    this.isConnected = false,
    this.isConnecting = false,
    this.error,
    this.rooms = const [],
    this.messages = const {},
  });

  ChatServiceState copyWith({
    bool? isConnected,
    bool? isConnecting,
    String? error,
    List<ChatRoom>? rooms,
    Map<String, List<ChatMessage>>? messages,
  }) {
    return ChatServiceState(
      isConnected: isConnected ?? this.isConnected,
      isConnecting: isConnecting ?? this.isConnecting,
      error: error ?? this.error,
      rooms: rooms ?? this.rooms,
      messages: messages ?? this.messages,
    );
  }
}

// Chat service notifier
class ChatServiceNotifier extends StateNotifier<ChatServiceState> {
  ChatServiceNotifier() : super(const ChatServiceState());

  Future<void> initialize(String userId, String authToken) async {
    state = state.copyWith(isConnecting: true, error: null);

    try {
      // Initialize chat service
      // In a real app, you would initialize the WebSocket connection here
      await Future.delayed(const Duration(seconds: 1));

      state = state.copyWith(
        isConnecting: false,
        isConnected: true,
      );
    } catch (e) {
      state = state.copyWith(
        isConnecting: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadChatRooms() async {
    try {
      // In a real app, you would fetch from your API
      await Future.delayed(const Duration(seconds: 1));

      final rooms = List.generate(5, (index) {
        return ChatRoom(
          id: 'room_$index',
          name: index == 0 ? 'John Doe' : 'Group Chat ${index + 1}',
          isGroup: index > 0,
          participants: List.generate(
            index == 0 ? 2 : 3 + index,
            (i) => UserModel(
              id: 'user_$i',
              username: 'user_$i',
              email: 'user$i@example.com',
              avatarUrl: 'https://picsum.photos/50/50?random=$i',
              createdAt: DateTime.now().subtract(Duration(days: i)),
            ),
          ),
          lastMessage: ChatMessage(
            id: 'msg_$index',
            roomId: 'room_$index',
            senderId: 'user_${index % 3}',
            content: 'This is a sample message ${index + 1}',
            timestamp: DateTime.now().subtract(Duration(minutes: index * 10)),
            messageType: MessageType.text,
          ),
          unreadCount: index,
          isOnline: index % 2 == 0,
          createdAt: DateTime.now().subtract(Duration(days: index)),
        );
      });

      state = state.copyWith(rooms: rooms);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> loadMessages(String roomId) async {
    try {
      await Future.delayed(const Duration(seconds: 1));

      final messages = List.generate(20, (index) {
        return ChatMessage(
          id: 'msg_${roomId}_$index',
          roomId: roomId,
          senderId: 'user_${index % 3}',
          content: 'Sample message $index in room $roomId',
          timestamp: DateTime.now().subtract(Duration(minutes: index)),
          messageType: MessageType.text,
          isRead: index < 10,
        );
      });

      final updatedMessages =
          Map<String, List<ChatMessage>>.from(state.messages);
      updatedMessages[roomId] = messages;

      state = state.copyWith(messages: updatedMessages);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> sendMessage({
    required String roomId,
    required String content,
  }) async {
    try {
      // In a real app, you would send via WebSocket
      await Future.delayed(const Duration(milliseconds: 500));

      final message = ChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        roomId: roomId,
        senderId: 'current_user',
        content: content,
        timestamp: DateTime.now(),
        messageType: MessageType.text,
        isRead: false,
      );

      final updatedMessages =
          Map<String, List<ChatMessage>>.from(state.messages);
      if (updatedMessages[roomId] != null) {
        updatedMessages[roomId] = [message, ...updatedMessages[roomId]!];
      } else {
        updatedMessages[roomId] = [message];
      }

      state = state.copyWith(messages: updatedMessages);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

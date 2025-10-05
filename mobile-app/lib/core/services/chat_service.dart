import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../../models/chat_message.dart';
import '../../models/chat_room.dart';
import 'api_service.dart';

class ChatService {
  IO.Socket? _socket;
  StreamController<ChatMessage>? _messageController;
  StreamController<ChatRoom>? _roomController;
  String? _currentUserId;
  String? _authToken;
  bool _isConnected = false;
  Timer? _heartbeatTimer;
  final ApiService _apiService = ApiService();

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

  // Connect to Socket.IO server
  Future<void> connect() async {
    if (_isConnected) return;

    try {
      _socket = IO.io(
        _apiService.socketUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .setAuth({'token': _authToken})
            .enableAutoConnect()
            .build(),
      );

      _socket!.onConnect((_) {
        _isConnected = true;
        print('✅ Connected to chat server');
        _socket!.emit('join-user-room', _currentUserId);
      });

      _socket!.onDisconnect((_) {
        _isConnected = false;
        print('❌ Disconnected from chat server');
      });

      _socket!.onConnectError((error) {
        _isConnected = false;
        print('❌ Connection error: $error');
      });

      // Listen to incoming messages
      _socket!.on('new-message', (data) {
        _handleIncomingMessage(data);
      });

      _socket!.on('user-typing', (data) {
        // Handle typing indicators
        print('User typing: $data');
      });
    } catch (e) {
      print('❌ Failed to connect to chat server: $e');
      _isConnected = false;
    }
  }

  // Disconnect from Socket.IO server
  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    _socket?.disconnect();
    _socket = null;
    _isConnected = false;
  }

  // Load chat rooms from API
  Future<List<ChatRoom>> loadChatRooms({int page = 1, int limit = 20}) async {
    try {
      final response = await _apiService.getChatRooms(page: page, limit: limit);

      if (response['success'] == true && response['data'] != null) {
        final roomsData = response['data'] as List;
        return roomsData
            .map((roomData) => ChatRoom.fromJson(roomData))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error loading chat rooms: $e');
      return [];
    }
  }

  // Create a new chat room
  Future<ChatRoom?> createChatRoom({
    String? name,
    required String type,
    required List<String> participantIds,
  }) async {
    try {
      final response = await _apiService.createChatRoom(
        name: name,
        type: type,
        participantIds: participantIds,
      );

      if (response['success'] == true && response['data'] != null) {
        return ChatRoom.fromJson(response['data']);
      }
      return null;
    } catch (e) {
      print('Error creating chat room: $e');
      return null;
    }
  }

  // Load messages for a chat room
  Future<List<ChatMessage>> loadMessages({
    required String roomId,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final response = await _apiService.getChatMessages(
        roomId: roomId,
        page: page,
        limit: limit,
      );

      if (response['success'] == true && response['data'] != null) {
        final messagesData = response['data'] as List;
        return messagesData
            .map((messageData) => ChatMessage.fromJson(messageData))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error loading messages: $e');
      return [];
    }
  }

  // Send a message
  Future<ChatMessage?> sendMessage({
    required String roomId,
    required String content,
    String? messageType,
    String? fileUrl,
  }) async {
    try {
      final response = await _apiService.sendMessage(
        roomId: roomId,
        content: content,
        messageType: messageType,
        fileUrl: fileUrl,
      );

      if (response['success'] == true && response['data'] != null) {
        return ChatMessage.fromJson(response['data']);
      }
      return null;
    } catch (e) {
      print('Error sending message: $e');
      return null;
    }
  }

  // Join a chat room
  void joinChatRoom(String roomId) {
    _socket?.emit('join-chat-room', roomId);
  }

  // Leave a chat room
  void leaveChatRoom(String roomId) {
    _socket?.emit('leave-chat-room', roomId);
  }

  // Send typing indicator
  void sendTypingIndicator(String roomId, bool isTyping) {
    if (isTyping) {
      _socket?.emit('typing-start', {
        'roomId': roomId,
        'userId': _currentUserId,
        'username': 'Current User', // TODO: Get actual username
      });
    } else {
      _socket?.emit('typing-stop', {
        'roomId': roomId,
        'userId': _currentUserId,
      });
    }
  }

  // Handle incoming messages
  void _handleIncomingMessage(dynamic data) {
    try {
      final message = ChatMessage.fromJson(data);
      _messageController?.add(message);
    } catch (e) {
      print('Error handling incoming message: $e');
    }
  }

  // Cleanup
  void dispose() {
    _heartbeatTimer?.cancel();
    _messageController?.close();
    _roomController?.close();
    _socket?.disconnect();
  }
}

// Chat Service State
class ChatServiceState {
  final List<ChatRoom> rooms;
  final Map<String, List<ChatMessage>> messages;
  final bool isLoading;
  final String? error;
  final Map<String, bool> typingUsers;

  const ChatServiceState({
    this.rooms = const [],
    this.messages = const {},
    this.isLoading = false,
    this.error,
    this.typingUsers = const {},
  });

  ChatServiceState copyWith({
    List<ChatRoom>? rooms,
    Map<String, List<ChatMessage>>? messages,
    bool? isLoading,
    String? error,
    Map<String, bool>? typingUsers,
  }) {
    return ChatServiceState(
      rooms: rooms ?? this.rooms,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      typingUsers: typingUsers ?? this.typingUsers,
    );
  }
}

// Chat Service Notifier
class ChatServiceNotifier extends StateNotifier<ChatServiceState> {
  final ChatService _chatService;

  ChatServiceNotifier(this._chatService) : super(const ChatServiceState()) {
    _setupMessageListener();
  }

  void initialize(String userId, String authToken) {
    _chatService.initialize(userId, authToken);
    _chatService.connect();
  }

  void _setupMessageListener() {
    _chatService.messageStream?.listen((message) {
      final currentMessages =
          Map<String, List<ChatMessage>>.from(state.messages);
      final roomMessages = currentMessages[message.roomId] ?? [];

      // Check if message already exists to avoid duplicates
      if (!roomMessages.any((m) => m.id == message.id)) {
        roomMessages.add(message);
        currentMessages[message.roomId] = roomMessages;

        state = state.copyWith(messages: currentMessages);
      }
    });
  }

  Future<void> loadChatRooms() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final rooms = await _chatService.loadChatRooms();
      state = state.copyWith(rooms: rooms, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMessages(String roomId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final messages = await _chatService.loadMessages(roomId: roomId);
      final updatedMessages =
          Map<String, List<ChatMessage>>.from(state.messages);
      updatedMessages[roomId] = messages;

      state = state.copyWith(messages: updatedMessages, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> sendMessage(String roomId, String content) async {
    try {
      final message = await _chatService.sendMessage(
        roomId: roomId,
        content: content,
      );

      if (message != null) {
        final currentMessages =
            Map<String, List<ChatMessage>>.from(state.messages);
        final roomMessages = currentMessages[roomId] ?? [];
        roomMessages.add(message);
        currentMessages[roomId] = roomMessages;

        state = state.copyWith(messages: currentMessages);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<ChatRoom?> createChatRoom({
    String? name,
    required String type,
    required List<String> participantIds,
  }) async {
    try {
      final room = await _chatService.createChatRoom(
        name: name,
        type: type,
        participantIds: participantIds,
      );

      if (room != null) {
        final updatedRooms = [...state.rooms, room];
        state = state.copyWith(rooms: updatedRooms);
      }

      return room;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  void joinChatRoom(String roomId) {
    _chatService.joinChatRoom(roomId);
  }

  void leaveChatRoom(String roomId) {
    _chatService.leaveChatRoom(roomId);
  }

  void sendTypingIndicator(String roomId, bool isTyping) {
    _chatService.sendTypingIndicator(roomId, isTyping);
  }

  @override
  void dispose() {
    _chatService.dispose();
    super.dispose();
  }
}

// Providers
final chatServiceProvider = Provider<ChatService>((ref) => ChatService());

final chatServiceStateProvider =
    StateNotifierProvider<ChatServiceNotifier, ChatServiceState>((ref) {
  final chatService = ref.watch(chatServiceProvider);
  return ChatServiceNotifier(chatService);
});

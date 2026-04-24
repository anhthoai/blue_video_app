import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

import '../../models/chat_call.dart';
import '../../models/chat_message.dart';
import '../../models/chat_room.dart';
import 'api_service.dart';

class ChatTypingEvent {
  final String roomId;
  final String? userId;
  final String? username;
  final bool isTyping;

  const ChatTypingEvent({
    required this.roomId,
    required this.isTyping,
    this.userId,
    this.username,
  });
}

class ChatService {
  socket_io.Socket? _socket;
  final StreamController<ChatMessage> _messageController =
      StreamController<ChatMessage>.broadcast();
  final StreamController<ChatRoom> _roomController =
      StreamController<ChatRoom>.broadcast();
  final StreamController<ChatTypingEvent> _typingController =
      StreamController<ChatTypingEvent>.broadcast();
  final StreamController<ChatSocketEvent> _callEventController =
      StreamController<ChatSocketEvent>.broadcast();
  final Set<String> _joinedRoomIds = <String>{};
  String? _currentUserId;
  String? _authToken;
  bool _isConnected = false;
  bool _isConnecting = false;
  Timer? _heartbeatTimer;
  final ApiService _apiService = ApiService();

  bool get isConnected => _isConnected;
  Stream<ChatMessage> get messageStream => _messageController.stream;
  Stream<ChatRoom> get roomStream => _roomController.stream;
  Stream<ChatTypingEvent> get typingStream => _typingController.stream;
  Stream<ChatSocketEvent> get callEventStream => _callEventController.stream;

  void initialize(String userId, String authToken) {
    _currentUserId = userId;
    _authToken = authToken;
  }

  Future<void> _waitForConnection(socket_io.Socket socket) async {
    if (socket.connected) {
      _isConnected = true;
      _isConnecting = false;
      return;
    }

    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (DateTime.now().isBefore(deadline)) {
      if (socket.connected) {
        _isConnected = true;
        _isConnecting = false;
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    _isConnecting = false;
  }

  Future<void> connect() async {
    if (_authToken == null || _isConnecting) {
      return;
    }

    final existingSocket = _socket;
    if (existingSocket != null) {
      if (existingSocket.connected) {
        _isConnected = true;
        return;
      }

      _isConnecting = true;
      debugPrint('Reconnecting to chat server');
      existingSocket.connect();
      await _waitForConnection(existingSocket);
      return;
    }

    try {
      _isConnecting = true;
      final socket = socket_io.io(
        _apiService.socketUrl,
        socket_io.OptionBuilder()
            .setTransports(['websocket'])
            .setAuth({'token': _authToken})
            .enableAutoConnect()
            .build(),
      );
      _socket = socket;

      socket.onConnect((_) {
        _isConnected = true;
        _isConnecting = false;
        debugPrint('Connected to chat server');
        if (_currentUserId != null) {
          socket.emit('join-user-room', _currentUserId);
        }
        for (final roomId in _joinedRoomIds) {
          socket.emit('join-chat-room', roomId);
        }
      });

      socket.onDisconnect((_) {
        _isConnected = false;
        _isConnecting = false;
        debugPrint('Disconnected from chat server');
      });

      socket.onConnectError((error) {
        _isConnected = false;
        _isConnecting = false;
        debugPrint('Chat connection error: $error');
      });

      socket.on('new-message', _handleIncomingMessage);
      socket.on('chat-room-updated', _handleIncomingRoomUpdate);
      socket.on('user-typing', _handleTypingUpdate);

      for (final eventName in const [
        'incoming-call',
        'outgoing-call',
        'call-accepted',
        'call-declined',
        'call-missed',
        'call-ended',
        'call-error',
        'webrtc-offer',
        'webrtc-answer',
        'webrtc-ice-candidate',
      ]) {
        socket.on(eventName, (data) {
          _emitCallEvent(eventName, data);
        });
      }

      await _waitForConnection(socket);
    } catch (e) {
      debugPrint('Failed to connect to chat server: $e');
      _isConnected = false;
      _isConnecting = false;
    }
  }

  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    _socket?.disconnect();
    _socket = null;
    _isConnected = false;
    _isConnecting = false;
  }

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
      debugPrint('Error loading chat rooms: $e');
      return [];
    }
  }

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
      debugPrint('Error creating chat room: $e');
      return null;
    }
  }

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
      debugPrint('Error loading messages: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> uploadChatAttachment(File file) async {
    try {
      final response = await _apiService.uploadChatAttachment(file);

      if (response['success'] == true && response['data'] != null) {
        return response['data'];
      }
      return null;
    } catch (e) {
      debugPrint('Error uploading chat attachment: $e');
      return null;
    }
  }

  Future<ChatMessage?> sendMessage({
    required String roomId,
    required String content,
    String? messageType,
    String? fileUrl,
    String? fileName,
    String? fileDirectory,
    int? fileSize,
    String? mimeType,
  }) async {
    try {
      final response = await _apiService.sendMessage(
        roomId: roomId,
        content: content,
        messageType: messageType,
        fileUrl: fileUrl,
        fileName: fileName,
        fileDirectory: fileDirectory,
        fileSize: fileSize,
        mimeType: mimeType,
      );

      if (response['success'] == true && response['data'] != null) {
        return ChatMessage.fromJson(response['data']);
      }
      return null;
    } catch (e) {
      debugPrint('Error sending message: $e');
      return null;
    }
  }

  Future<ChatMessage?> sendSystemMessage(String roomId, String content) {
    return sendMessage(
      roomId: roomId,
      content: content,
      messageType: 'SYSTEM',
    );
  }

  void joinChatRoom(String roomId) {
    _joinedRoomIds.add(roomId);
    if (_socket?.connected == true) {
      _socket?.emit('join-chat-room', roomId);
      return;
    }

    unawaited(connect());
  }

  void leaveChatRoom(String roomId) {
    _joinedRoomIds.remove(roomId);
    if (_socket?.connected == true) {
      _socket?.emit('leave-chat-room', roomId);
    }
  }

  void sendTypingIndicator(String roomId, bool isTyping) {
    if (_socket?.connected != true) {
      unawaited(connect());
      return;
    }

    if (isTyping) {
      _socket?.emit('typing-start', {
        'roomId': roomId,
        'userId': _currentUserId,
        'username': 'Current User',
      });
    } else {
      _socket?.emit('typing-stop', {
        'roomId': roomId,
        'userId': _currentUserId,
      });
    }
  }

  void sendCallInvite({
    required String callId,
    required String roomId,
    required List<String> participantIds,
    required String callerName,
    required bool isVideoCall,
    String? callerAvatar,
  }) {
    _socket?.emit('call-invite', {
      'callId': callId,
      'roomId': roomId,
      'participantIds': participantIds,
      'callerName': callerName,
      'callerAvatar': callerAvatar,
      'isVideoCall': isVideoCall,
    });
  }

  void acceptCall({required String callId}) {
    _socket?.emit('call-accept', {
      'callId': callId,
    });
  }

  void declineCall({required String callId}) {
    _socket?.emit('call-decline', {
      'callId': callId,
    });
  }

  void notifyMissedCall({required String callId}) {
    _socket?.emit('call-no-answer', {
      'callId': callId,
    });
  }

  void endCall({
    required String callId,
    int? durationSeconds,
  }) {
    _socket?.emit('call-end', {
      'callId': callId,
      'durationSeconds': durationSeconds,
    });
  }

  void sendWebRtcOffer({
    required String callId,
    required String toUserId,
    required Map<String, dynamic> offer,
  }) {
    _socket?.emit('webrtc-offer', {
      'callId': callId,
      'toUserId': toUserId,
      'offer': offer,
    });
  }

  void sendWebRtcAnswer({
    required String callId,
    required String toUserId,
    required Map<String, dynamic> answer,
  }) {
    _socket?.emit('webrtc-answer', {
      'callId': callId,
      'toUserId': toUserId,
      'answer': answer,
    });
  }

  void sendIceCandidate({
    required String callId,
    required String toUserId,
    required Map<String, dynamic> candidate,
  }) {
    _socket?.emit('webrtc-ice-candidate', {
      'callId': callId,
      'toUserId': toUserId,
      'candidate': candidate,
    });
  }

  Map<String, dynamic> _normalizeSocketPayload(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{};
  }

  void _emitCallEvent(String type, dynamic data) {
    _callEventController.add(
      ChatSocketEvent(
        type: type,
        payload: _normalizeSocketPayload(data),
      ),
    );
  }

  void _handleIncomingMessage(dynamic data) {
    try {
      final message = ChatMessage.fromJson(_normalizeSocketPayload(data));
      _messageController.add(message);
    } catch (e) {
      debugPrint('Error handling incoming message: $e');
    }
  }

  void _handleIncomingRoomUpdate(dynamic data) {
    try {
      final room = ChatRoom.fromJson(_normalizeSocketPayload(data));
      _roomController.add(room);
    } catch (e) {
      debugPrint('Error handling incoming room update: $e');
    }
  }

  void _handleTypingUpdate(dynamic data) {
    try {
      final payload = _normalizeSocketPayload(data);
      final roomId = payload['roomId'] as String?;
      if (roomId == null || roomId.isEmpty) {
        return;
      }

      _typingController.add(
        ChatTypingEvent(
          roomId: roomId,
          userId: payload['userId'] as String?,
          username: payload['username'] as String?,
          isTyping: payload['isTyping'] as bool? ?? false,
        ),
      );
    } catch (e) {
      debugPrint('Error handling typing update: $e');
    }
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _messageController.close();
    _roomController.close();
    _typingController.close();
    _callEventController.close();
    _isConnecting = false;
    _socket?.disconnect();
  }
}

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

class ChatServiceNotifier extends StateNotifier<ChatServiceState> {
  final ChatService _chatService;

  ChatServiceNotifier(this._chatService) : super(const ChatServiceState()) {
    _setupMessageListener();
    _setupRoomListener();
    _setupTypingListener();
  }

  void initialize(String userId, String authToken) {
    _chatService.initialize(userId, authToken);
    unawaited(_chatService.connect());
  }

  void _setupMessageListener() {
    _chatService.messageStream.listen((message) {
      final currentMessages =
          Map<String, List<ChatMessage>>.from(state.messages);
      final roomMessages = [
        ...(currentMessages[message.roomId] ?? const <ChatMessage>[])
      ];

      if (!roomMessages
          .any((existingMessage) => existingMessage.id == message.id)) {
        roomMessages.add(message);
        currentMessages[message.roomId] = roomMessages;

        state = state.copyWith(
          messages: currentMessages,
          rooms: _applyLastMessageToRooms(state.rooms, message),
        );
      }
    });
  }

  void _setupRoomListener() {
    _chatService.roomStream.listen((room) {
      state = state.copyWith(rooms: _mergeRoomIntoList(state.rooms, room));
    });
  }

  void _setupTypingListener() {
    _chatService.typingStream.listen((event) {
      final updatedTypingUsers = Map<String, bool>.from(state.typingUsers);
      if (event.isTyping) {
        updatedTypingUsers[event.roomId] = true;
      } else {
        updatedTypingUsers.remove(event.roomId);
      }

      state = state.copyWith(typingUsers: updatedTypingUsers);
    });
  }

  List<ChatRoom> _mergeRoomIntoList(List<ChatRoom> rooms, ChatRoom room) {
    final updatedRooms = [...rooms];
    final existingIndex = updatedRooms.indexWhere(
      (existingRoom) => existingRoom.id == room.id,
    );

    if (existingIndex >= 0) {
      updatedRooms[existingIndex] = room;
    } else {
      updatedRooms.add(room);
    }

    updatedRooms.sort((left, right) {
      final leftUpdatedAt = left.updatedAt ?? left.createdAt;
      final rightUpdatedAt = right.updatedAt ?? right.createdAt;
      return rightUpdatedAt.compareTo(leftUpdatedAt);
    });

    return updatedRooms;
  }

  List<ChatRoom> _applyLastMessageToRooms(
      List<ChatRoom> rooms, ChatMessage message) {
    final updatedRooms = rooms.map((room) {
      if (room.id != message.roomId) {
        return room;
      }

      return room.copyWith(
        lastMessage: message,
        updatedAt: message.createdAt,
      );
    }).toList();

    updatedRooms.sort((left, right) {
      final leftUpdatedAt = left.updatedAt ?? left.createdAt;
      final rightUpdatedAt = right.updatedAt ?? right.createdAt;
      return rightUpdatedAt.compareTo(leftUpdatedAt);
    });

    return updatedRooms;
  }

  Future<void> loadChatRooms() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _chatService.connect();
      final rooms = await _chatService.loadChatRooms();
      state = state.copyWith(rooms: rooms, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMessages(String roomId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _chatService.connect();
      final messages = await _chatService.loadMessages(roomId: roomId);
      final updatedMessages =
          Map<String, List<ChatMessage>>.from(state.messages);
      updatedMessages[roomId] = [...messages]
        ..sort((left, right) => left.createdAt.compareTo(right.createdAt));

      state = state.copyWith(messages: updatedMessages, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<Map<String, dynamic>?> uploadChatAttachment(File file) async {
    try {
      return await _chatService.uploadChatAttachment(file);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<void> sendMessage(
    String roomId,
    String content, {
    String? messageType,
    String? fileUrl,
    String? fileName,
    String? fileDirectory,
    int? fileSize,
    String? mimeType,
  }) async {
    try {
      await _chatService.connect();
      final message = await _chatService.sendMessage(
        roomId: roomId,
        content: content,
        messageType: messageType,
        fileUrl: fileUrl,
        fileName: fileName,
        fileDirectory: fileDirectory,
        fileSize: fileSize,
        mimeType: mimeType,
      );

      if (message != null) {
        final currentMessages =
            Map<String, List<ChatMessage>>.from(state.messages);
        final roomMessages = [
          ...(currentMessages[roomId] ?? const <ChatMessage>[])
        ];
        roomMessages.add(message);
        currentMessages[roomId] = roomMessages;

        state = state.copyWith(
          messages: currentMessages,
          rooms: _applyLastMessageToRooms(state.rooms, message),
        );
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
        state = state.copyWith(rooms: _mergeRoomIntoList(state.rooms, room));
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

final chatServiceProvider = Provider<ChatService>((ref) => ChatService());

final chatServiceStateProvider =
    StateNotifierProvider<ChatServiceNotifier, ChatServiceState>((ref) {
  final chatService = ref.watch(chatServiceProvider);
  return ChatServiceNotifier(chatService);
});

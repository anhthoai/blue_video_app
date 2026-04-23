import 'package:flutter_webrtc/flutter_webrtc.dart';

const Object _chatCallUnset = Object();

enum ChatCallPhase {
  idle,
  incoming,
  outgoing,
  connecting,
  connected,
  ended,
  missed,
  declined,
  error,
}

class ChatSocketEvent {
  final String type;
  final Map<String, dynamic> payload;

  const ChatSocketEvent({
    required this.type,
    required this.payload,
  });
}

class ChatCallInvite {
  final String callId;
  final String roomId;
  final String callerId;
  final String callerName;
  final String? callerAvatar;
  final bool isVideoCall;
  final List<String> participantIds;
  final DateTime createdAt;

  const ChatCallInvite({
    required this.callId,
    required this.roomId,
    required this.callerId,
    required this.callerName,
    required this.isVideoCall,
    required this.participantIds,
    required this.createdAt,
    this.callerAvatar,
  });

  factory ChatCallInvite.fromPayload(Map<String, dynamic> payload) {
    return ChatCallInvite(
      callId: payload['callId'] as String? ?? '',
      roomId: payload['roomId'] as String? ?? '',
      callerId: payload['callerId'] as String? ?? '',
      callerName: payload['callerName'] as String? ?? 'Unknown caller',
      callerAvatar: payload['callerAvatar'] as String?,
      isVideoCall: payload['isVideoCall'] as bool? ?? false,
      participantIds: (payload['participantIds'] as List<dynamic>? ?? const [])
          .map((participantId) => participantId.toString())
          .toList(),
      createdAt: payload['createdAt'] != null
          ? DateTime.tryParse(payload['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class ChatCallState {
  final ChatCallPhase phase;
  final ChatCallInvite? incomingInvite;
  final String? activeCallId;
  final String? roomId;
  final String? remoteUserId;
  final String remoteDisplayName;
  final String? remoteAvatarUrl;
  final bool isVideoCall;
  final RTCVideoRenderer? localRenderer;
  final RTCVideoRenderer? remoteRenderer;
  final Duration duration;
  final bool permissionsGranted;
  final bool isMuted;
  final bool isSpeakerOn;
  final bool isCameraEnabled;
  final bool isFrontCamera;
  final String statusText;
  final String? errorMessage;
  final bool isOutgoing;
  final bool hasRemoteVideo;

  const ChatCallState({
    this.phase = ChatCallPhase.idle,
    this.incomingInvite,
    this.activeCallId,
    this.roomId,
    this.remoteUserId,
    this.remoteDisplayName = '',
    this.remoteAvatarUrl,
    this.isVideoCall = false,
    this.localRenderer,
    this.remoteRenderer,
    this.duration = Duration.zero,
    this.permissionsGranted = false,
    this.isMuted = false,
    this.isSpeakerOn = true,
    this.isCameraEnabled = false,
    this.isFrontCamera = true,
    this.statusText = '',
    this.errorMessage,
    this.isOutgoing = false,
    this.hasRemoteVideo = false,
  });

  bool get hasOngoingCall {
    return activeCallId != null &&
        (phase == ChatCallPhase.outgoing ||
            phase == ChatCallPhase.connecting ||
            phase == ChatCallPhase.connected);
  }

  ChatCallState copyWith({
    ChatCallPhase? phase,
    Object? incomingInvite = _chatCallUnset,
    Object? activeCallId = _chatCallUnset,
    Object? roomId = _chatCallUnset,
    Object? remoteUserId = _chatCallUnset,
    String? remoteDisplayName,
    Object? remoteAvatarUrl = _chatCallUnset,
    bool? isVideoCall,
    Object? localRenderer = _chatCallUnset,
    Object? remoteRenderer = _chatCallUnset,
    Duration? duration,
    bool? permissionsGranted,
    bool? isMuted,
    bool? isSpeakerOn,
    bool? isCameraEnabled,
    bool? isFrontCamera,
    String? statusText,
    Object? errorMessage = _chatCallUnset,
    bool? isOutgoing,
    bool? hasRemoteVideo,
  }) {
    return ChatCallState(
      phase: phase ?? this.phase,
      incomingInvite: incomingInvite == _chatCallUnset
          ? this.incomingInvite
          : incomingInvite as ChatCallInvite?,
      activeCallId: activeCallId == _chatCallUnset
          ? this.activeCallId
          : activeCallId as String?,
      roomId: roomId == _chatCallUnset ? this.roomId : roomId as String?,
      remoteUserId: remoteUserId == _chatCallUnset
          ? this.remoteUserId
          : remoteUserId as String?,
      remoteDisplayName: remoteDisplayName ?? this.remoteDisplayName,
      remoteAvatarUrl: remoteAvatarUrl == _chatCallUnset
          ? this.remoteAvatarUrl
          : remoteAvatarUrl as String?,
      isVideoCall: isVideoCall ?? this.isVideoCall,
      localRenderer: localRenderer == _chatCallUnset
          ? this.localRenderer
          : localRenderer as RTCVideoRenderer?,
      remoteRenderer: remoteRenderer == _chatCallUnset
          ? this.remoteRenderer
          : remoteRenderer as RTCVideoRenderer?,
      duration: duration ?? this.duration,
      permissionsGranted: permissionsGranted ?? this.permissionsGranted,
      isMuted: isMuted ?? this.isMuted,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      isCameraEnabled: isCameraEnabled ?? this.isCameraEnabled,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
      statusText: statusText ?? this.statusText,
      errorMessage: errorMessage == _chatCallUnset
          ? this.errorMessage
          : errorMessage as String?,
      isOutgoing: isOutgoing ?? this.isOutgoing,
      hasRemoteVideo: hasRemoteVideo ?? this.hasRemoteVideo,
    );
  }
}

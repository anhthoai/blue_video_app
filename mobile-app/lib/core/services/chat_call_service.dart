import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../../models/chat_call.dart';
import '../../models/chat_room.dart';
import '../../models/user_model.dart';
import 'chat_service.dart';

class ChatCallController extends StateNotifier<ChatCallState> {
  ChatCallController(this._chatService) : super(const ChatCallState()) {
    _callEventSubscription = _chatService.callEventStream.listen((event) {
      unawaited(_handleSocketEvent(event));
    });
    unawaited(_initializeRenderers());
  }

  final ChatService _chatService;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  final Uuid _uuid = const Uuid();

  StreamSubscription<ChatSocketEvent>? _callEventSubscription;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  Timer? _callTimer;
  Timer? _inviteTimeout;
  bool _renderersInitialized = false;

  Future<void> _initializeRenderers() async {
    if (_renderersInitialized) {
      return;
    }

    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    _renderersInitialized = true;

    state = state.copyWith(
      localRenderer: _localRenderer,
      remoteRenderer: _remoteRenderer,
    );
  }

  Future<void> _ensureRenderersReady() async {
    if (!_renderersInitialized) {
      await _initializeRenderers();
    }
  }

  String _buildUserDisplayName(UserModel user) {
    final displayName = [user.firstName, user.lastName]
        .where((value) => value != null && value.trim().isNotEmpty)
        .join(' ')
        .trim();

    return displayName.isNotEmpty ? displayName : user.username;
  }

  Future<bool> startOutgoingCall({
    required ChatRoom room,
    required UserModel currentUser,
    required bool isVideoCall,
  }) async {
    if (state.hasOngoingCall || state.incomingInvite != null) {
      return false;
    }

    final participants = room.getOtherParticipants(currentUser.id);
    if (participants.isEmpty) {
      state = state.copyWith(
        phase: ChatCallPhase.error,
        statusText: 'Unable to find the other participant for this call.',
        errorMessage: 'Unable to find the other participant for this call.',
      );
      return false;
    }

    await _chatService.connect();
    if (!_chatService.isConnected) {
      state = state.copyWith(
        phase: ChatCallPhase.error,
        statusText: 'Unable to connect to the chat server.',
        errorMessage: 'Unable to connect to the chat server.',
      );
      return false;
    }

    final remoteParticipant = participants.first;

    state = state.copyWith(
      phase: ChatCallPhase.connecting,
      roomId: room.id,
      remoteUserId: remoteParticipant.id,
      remoteDisplayName: remoteParticipant.displayName,
      remoteAvatarUrl: remoteParticipant.avatarUrl,
      isVideoCall: isVideoCall,
      statusText: 'Preparing call...',
      errorMessage: null,
      duration: Duration.zero,
      isOutgoing: true,
      hasRemoteVideo: false,
      permissionsGranted: false,
    );

    final prepared = await _prepareRtcSession(isVideoCall: isVideoCall);
    if (!prepared) {
      return false;
    }

    final callId = _uuid.v4();
    state = state.copyWith(
      activeCallId: callId,
      phase: ChatCallPhase.outgoing,
      statusText: 'Ringing...',
      isOutgoing: true,
      errorMessage: null,
    );

    _inviteTimeout?.cancel();
    _inviteTimeout = Timer(const Duration(seconds: 30), () async {
      if (state.activeCallId == callId &&
          state.phase == ChatCallPhase.outgoing) {
        _chatService.notifyMissedCall(callId: callId);
        await _setTerminalState(
          ChatCallPhase.missed,
          'No answer',
        );
      }
    });

    _chatService.sendCallInvite(
      callId: callId,
      roomId: room.id,
      participantIds: [remoteParticipant.id],
      callerName: _buildUserDisplayName(currentUser),
      callerAvatar: currentUser.avatarUrl,
      isVideoCall: isVideoCall,
    );

    return true;
  }

  Future<bool> acceptIncomingCall() async {
    final invite = state.incomingInvite;
    if (invite == null) {
      return false;
    }

    state = state.copyWith(
      activeCallId: invite.callId,
      roomId: invite.roomId,
      remoteUserId: invite.callerId,
      remoteDisplayName: invite.callerName,
      remoteAvatarUrl: invite.callerAvatar,
      isVideoCall: invite.isVideoCall,
      phase: ChatCallPhase.connecting,
      statusText: 'Connecting...',
      errorMessage: null,
      incomingInvite: null,
      duration: Duration.zero,
      isOutgoing: false,
      hasRemoteVideo: false,
    );

    final prepared = await _prepareRtcSession(isVideoCall: invite.isVideoCall);
    if (!prepared) {
      _chatService.declineCall(callId: invite.callId);
      return false;
    }

    _chatService.acceptCall(callId: invite.callId);
    return true;
  }

  Future<void> declineIncomingCall() async {
    final invite = state.incomingInvite;
    if (invite != null) {
      _chatService.declineCall(callId: invite.callId);
    }

    await _disposeRtcSession();
    state = state.copyWith(
      phase: ChatCallPhase.idle,
      incomingInvite: null,
      activeCallId: null,
      roomId: null,
      remoteUserId: null,
      remoteDisplayName: '',
      remoteAvatarUrl: null,
      isVideoCall: false,
      duration: Duration.zero,
      permissionsGranted: false,
      isMuted: false,
      isSpeakerOn: true,
      isCameraEnabled: false,
      isFrontCamera: true,
      statusText: '',
      errorMessage: null,
      isOutgoing: false,
      hasRemoteVideo: false,
    );
  }

  Future<void> endCurrentCall() async {
    final callId = state.activeCallId;
    if (callId == null) {
      return;
    }

    _chatService.endCall(
      callId: callId,
      durationSeconds: state.duration.inSeconds,
    );
    await _setTerminalState(ChatCallPhase.ended, 'Call ended');
  }

  Future<void> toggleMute() async {
    final audioTracks =
        _localStream?.getAudioTracks() ?? const <MediaStreamTrack>[];
    if (audioTracks.isEmpty) {
      return;
    }

    final nextMutedValue = !state.isMuted;
    for (final track in audioTracks) {
      track.enabled = !nextMutedValue;
    }

    state = state.copyWith(isMuted: nextMutedValue);
  }

  Future<void> toggleSpeaker() async {
    final nextSpeakerValue = !state.isSpeakerOn;
    await Helper.setSpeakerphoneOn(nextSpeakerValue);
    state = state.copyWith(isSpeakerOn: nextSpeakerValue);
  }

  Future<void> toggleCameraEnabled() async {
    final videoTracks =
        _localStream?.getVideoTracks() ?? const <MediaStreamTrack>[];
    if (videoTracks.isEmpty) {
      return;
    }

    final nextCameraValue = !state.isCameraEnabled;
    for (final track in videoTracks) {
      track.enabled = nextCameraValue;
    }

    state = state.copyWith(isCameraEnabled: nextCameraValue);
  }

  Future<void> switchCamera() async {
    final videoTracks =
        _localStream?.getVideoTracks() ?? const <MediaStreamTrack>[];
    if (videoTracks.isEmpty) {
      return;
    }

    await Helper.switchCamera(videoTracks.first);
    state = state.copyWith(isFrontCamera: !state.isFrontCamera);
  }

  Future<void> clearFinishedCall() async {
    if (state.phase == ChatCallPhase.incoming || state.hasOngoingCall) {
      return;
    }

    await _disposeRtcSession();
    state = state.copyWith(
      phase: ChatCallPhase.idle,
      incomingInvite: null,
      activeCallId: null,
      roomId: null,
      remoteUserId: null,
      remoteDisplayName: '',
      remoteAvatarUrl: null,
      isVideoCall: false,
      duration: Duration.zero,
      permissionsGranted: false,
      isMuted: false,
      isSpeakerOn: true,
      isCameraEnabled: false,
      isFrontCamera: true,
      statusText: '',
      errorMessage: null,
      isOutgoing: false,
      hasRemoteVideo: false,
    );
  }

  Future<bool> _prepareRtcSession({required bool isVideoCall}) async {
    await _ensureRenderersReady();
    await _disposeRtcSession();

    final permissionsGranted = await _requestPermissions(isVideoCall);
    if (!permissionsGranted) {
      return false;
    }

    final mediaConstraints = <String, dynamic>{
      'audio': true,
      'video': isVideoCall
          ? {
              'facingMode': 'user',
            }
          : false,
    };

    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    _localRenderer.srcObject = _localStream;

    _peerConnection = await createPeerConnection({
      'iceServers': [
        {
          'urls': [
            'stun:stun.l.google.com:19302',
            'stun:stun1.l.google.com:19302'
          ],
        },
      ],
      'sdpSemantics': 'unified-plan',
    });

    for (final track
        in _localStream?.getTracks() ?? const <MediaStreamTrack>[]) {
      await _peerConnection!.addTrack(track, _localStream!);
    }

    _peerConnection!.onIceCandidate = (candidate) {
      final callId = state.activeCallId;
      final remoteUserId = state.remoteUserId;
      if (callId == null ||
          remoteUserId == null ||
          candidate.candidate == null) {
        return;
      }

      _chatService.sendIceCandidate(
        callId: callId,
        toUserId: remoteUserId,
        candidate: {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      );
    };

    _peerConnection!.onTrack = (event) {
      if (event.streams.isEmpty) {
        return;
      }

      _remoteStream = event.streams.first;
      _remoteRenderer.srcObject = _remoteStream;
      state = state.copyWith(
        hasRemoteVideo: _remoteStream?.getVideoTracks().isNotEmpty == true ||
            event.track.kind == 'video',
      );
      _markConnected();
    };

    _peerConnection!.onConnectionState = (connectionState) {
      if (state.activeCallId == null) {
        return;
      }

      if (connectionState ==
          RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _markConnected();
        return;
      }

      if (connectionState ==
              RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          connectionState ==
              RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          connectionState ==
              RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        unawaited(_setTerminalState(ChatCallPhase.ended, 'Call ended'));
      }
    };

    await Helper.setSpeakerphoneOn(true);
    state = state.copyWith(
      localRenderer: _localRenderer,
      remoteRenderer: _remoteRenderer,
      permissionsGranted: true,
      isMuted: false,
      isSpeakerOn: true,
      isCameraEnabled: isVideoCall,
      isFrontCamera: true,
      errorMessage: null,
      statusText:
          state.statusText.isNotEmpty ? state.statusText : 'Connecting...',
    );

    return true;
  }

  Future<bool> _requestPermissions(bool isVideoCall) async {
    final permissions = <Permission>[
      Permission.microphone,
      if (isVideoCall) Permission.camera,
    ];
    final statuses = await permissions.request();
    final granted =
        statuses.values.every((status) => status.isGranted || status.isLimited);

    if (granted) {
      return true;
    }

    final message = isVideoCall
        ? 'Camera and microphone access is required for video calls.'
        : 'Microphone access is required for voice calls.';
    state = state.copyWith(
      phase: ChatCallPhase.error,
      activeCallId: null,
      permissionsGranted: false,
      statusText: message,
      errorMessage: message,
      incomingInvite: null,
      isOutgoing: false,
    );
    return false;
  }

  Future<void> _handleSocketEvent(ChatSocketEvent event) async {
    final payload = event.payload;

    switch (event.type) {
      case 'incoming-call':
        final invite = ChatCallInvite.fromPayload(payload);
        if (invite.callId.isEmpty) {
          return;
        }
        if (state.hasOngoingCall || state.incomingInvite != null) {
          _chatService.declineCall(callId: invite.callId);
          return;
        }
        state = state.copyWith(
          phase: ChatCallPhase.incoming,
          incomingInvite: invite,
          roomId: invite.roomId,
          remoteUserId: invite.callerId,
          remoteDisplayName: invite.callerName,
          remoteAvatarUrl: invite.callerAvatar,
          isVideoCall: invite.isVideoCall,
          statusText: invite.isVideoCall
              ? 'Incoming video call...'
              : 'Incoming voice call...',
          errorMessage: null,
          isOutgoing: false,
        );
        return;
      case 'call-accepted':
        if (payload['callId'] != state.activeCallId ||
            state.phase != ChatCallPhase.outgoing) {
          return;
        }
        _inviteTimeout?.cancel();
        state = state.copyWith(
          phase: ChatCallPhase.connecting,
          statusText: 'Connecting...',
          remoteUserId: payload['userId'] as String? ?? state.remoteUserId,
        );
        await _createAndSendOffer();
        return;
      case 'webrtc-offer':
        if (payload['callId'] != state.activeCallId ||
            _peerConnection == null) {
          return;
        }
        state = state.copyWith(statusText: 'Connecting...');
        final offer = Map<String, dynamic>.from(
            payload['offer'] as Map<dynamic, dynamic>);
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(
            offer['sdp'] as String?,
            offer['type'] as String?,
          ),
        );
        final answer = await _peerConnection!.createAnswer({
          'offerToReceiveAudio': true,
          'offerToReceiveVideo': state.isVideoCall,
        });
        await _peerConnection!.setLocalDescription(answer);
        if (state.activeCallId != null && state.remoteUserId != null) {
          _chatService.sendWebRtcAnswer(
            callId: state.activeCallId!,
            toUserId: state.remoteUserId!,
            answer: {
              'sdp': answer.sdp,
              'type': answer.type,
            },
          );
        }
        return;
      case 'webrtc-answer':
        if (payload['callId'] != state.activeCallId ||
            _peerConnection == null) {
          return;
        }
        final answer = Map<String, dynamic>.from(
            payload['answer'] as Map<dynamic, dynamic>);
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(
            answer['sdp'] as String?,
            answer['type'] as String?,
          ),
        );
        return;
      case 'webrtc-ice-candidate':
        if (payload['callId'] != state.activeCallId ||
            _peerConnection == null) {
          return;
        }
        final candidatePayload = Map<String, dynamic>.from(
            payload['candidate'] as Map<dynamic, dynamic>);
        await _peerConnection!.addCandidate(
          RTCIceCandidate(
            candidatePayload['candidate'] as String?,
            candidatePayload['sdpMid'] as String?,
            candidatePayload['sdpMLineIndex'] as int?,
          ),
        );
        return;
      case 'call-declined':
        if (payload['callId'] != state.activeCallId) {
          return;
        }
        await _setTerminalState(ChatCallPhase.declined, 'Call declined');
        return;
      case 'call-missed':
        if (payload['callId'] == state.activeCallId) {
          await _setTerminalState(ChatCallPhase.missed, 'No answer');
          return;
        }
        if (state.incomingInvite?.callId == payload['callId']) {
          state = state.copyWith(
            phase: ChatCallPhase.missed,
            incomingInvite: null,
            statusText: 'Missed call',
            errorMessage: null,
          );
        }
        return;
      case 'call-ended':
        if (payload['callId'] != state.activeCallId) {
          return;
        }
        await _setTerminalState(ChatCallPhase.ended, 'Call ended');
        return;
      case 'call-error':
        final message =
            payload['message'] as String? ?? 'Unable to start the call.';
        state = state.copyWith(
          phase: ChatCallPhase.error,
          statusText: message,
          errorMessage: message,
          activeCallId: null,
          isOutgoing: false,
          incomingInvite: null,
        );
        return;
    }
  }

  Future<void> _createAndSendOffer() async {
    if (_peerConnection == null ||
        state.activeCallId == null ||
        state.remoteUserId == null) {
      return;
    }

    final offer = await _peerConnection!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': state.isVideoCall,
    });
    await _peerConnection!.setLocalDescription(offer);
    _chatService.sendWebRtcOffer(
      callId: state.activeCallId!,
      toUserId: state.remoteUserId!,
      offer: {
        'sdp': offer.sdp,
        'type': offer.type,
      },
    );
  }

  void _markConnected() {
    if (state.phase == ChatCallPhase.connected) {
      return;
    }

    _inviteTimeout?.cancel();
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      state =
          state.copyWith(duration: state.duration + const Duration(seconds: 1));
    });

    state = state.copyWith(
      phase: ChatCallPhase.connected,
      statusText: 'Connected',
      errorMessage: null,
    );
  }

  Future<void> _setTerminalState(ChatCallPhase phase, String statusText) async {
    await _disposeRtcSession();
    state = state.copyWith(
      phase: phase,
      incomingInvite: null,
      activeCallId: null,
      permissionsGranted: false,
      isMuted: false,
      isSpeakerOn: true,
      isCameraEnabled: false,
      isFrontCamera: true,
      statusText: statusText,
      isOutgoing: false,
      hasRemoteVideo: false,
    );
  }

  Future<void> _disposeRtcSession() async {
    _callTimer?.cancel();
    _callTimer = null;
    _inviteTimeout?.cancel();
    _inviteTimeout = null;

    if (_peerConnection != null) {
      await _peerConnection!.close();
      _peerConnection = null;
    }

    for (final track
        in _localStream?.getTracks() ?? const <MediaStreamTrack>[]) {
      track.stop();
    }
    for (final track
        in _remoteStream?.getTracks() ?? const <MediaStreamTrack>[]) {
      track.stop();
    }

    _localStream = null;
    _remoteStream = null;
    _localRenderer.srcObject = null;
    _remoteRenderer.srcObject = null;
  }

  @override
  void dispose() {
    _callEventSubscription?.cancel();
    unawaited(_disposeRtcSession());
    if (_renderersInitialized) {
      unawaited(_localRenderer.dispose());
      unawaited(_remoteRenderer.dispose());
    }
    super.dispose();
  }
}

final chatCallControllerProvider =
    StateNotifierProvider<ChatCallController, ChatCallState>((ref) {
  final chatService = ref.watch(chatServiceProvider);
  return ChatCallController(chatService);
});

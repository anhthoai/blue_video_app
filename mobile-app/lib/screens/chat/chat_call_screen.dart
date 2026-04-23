import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/services/chat_call_service.dart';
import '../../models/chat_call.dart';
import '../../models/chat_room.dart';
import '../../models/user_model.dart';

class ChatCallScreen extends ConsumerStatefulWidget {
  final ChatRoom room;
  final UserModel? currentUser;
  final String? currentUserId;
  final bool isVideoCall;
  final bool autoStartOutgoing;

  const ChatCallScreen({
    super.key,
    required this.room,
    required this.currentUser,
    required this.currentUserId,
    required this.isVideoCall,
    required this.autoStartOutgoing,
  });

  @override
  ConsumerState<ChatCallScreen> createState() => _ChatCallScreenState();
}

class _ChatCallScreenState extends ConsumerState<ChatCallScreen> {
  ProviderSubscription<ChatCallState>? _callSubscription;
  bool _isClosingLocally = false;

  @override
  void initState() {
    super.initState();

    _callSubscription = ref.listenManual<ChatCallState>(
      chatCallControllerProvider,
      (previous, next) {
        if (!mounted || _isClosingLocally) {
          return;
        }

        if ((next.phase == ChatCallPhase.ended ||
                next.phase == ChatCallPhase.missed ||
                next.phase == ChatCallPhase.declined) &&
            previous?.phase != next.phase) {
          Navigator.of(context).maybePop();
        }
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!widget.autoStartOutgoing || widget.currentUser == null) {
        return;
      }

      final started =
          await ref.read(chatCallControllerProvider.notifier).startOutgoingCall(
                room: widget.room,
                currentUser: widget.currentUser!,
                isVideoCall: widget.isVideoCall,
              );
      if (!started && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ref.read(chatCallControllerProvider).errorMessage ??
                  'Unable to start the call.',
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _callSubscription?.close();
    unawaited(
        ref.read(chatCallControllerProvider.notifier).clearFinishedCall());
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      final hours = duration.inHours.toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  Future<void> _handleClose() async {
    if (_isClosingLocally) {
      return;
    }

    _isClosingLocally = true;
    final controller = ref.read(chatCallControllerProvider.notifier);
    final callState = ref.read(chatCallControllerProvider);

    if (callState.hasOngoingCall) {
      await controller.endCurrentCall();
    } else {
      await controller.clearFinishedCall();
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(chatCallControllerProvider);
    final theme = Theme.of(context);
    final remoteName = callState.remoteDisplayName.isNotEmpty
        ? callState.remoteDisplayName
        : widget.room.getDisplayName(widget.currentUserId);
    final remoteAvatar = callState.remoteAvatarUrl ??
        widget.room.getDisplayAvatar(widget.currentUserId);
    final statusLine = callState.phase == ChatCallPhase.connected
        ? _formatDuration(callState.duration)
        : (callState.statusText.isNotEmpty
            ? callState.statusText
            : widget.isVideoCall
                ? 'Preparing video call...'
                : 'Preparing voice call...');
    final canUseControls =
        callState.permissionsGranted && callState.phase != ChatCallPhase.error;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          unawaited(_handleClose());
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF06111F),
        body: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: widget.isVideoCall
                        ? const [Color(0xFF14324E), Color(0xFF06111F)]
                        : const [Color(0xFF0E2237), Color(0xFF06111F)],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _TopIconButton(
                          icon: Icons.close,
                          onTap: _handleClose,
                        ),
                        const Spacer(),
                        Text(
                          widget.isVideoCall ? 'Video call' : 'Voice call',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(width: 44),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: widget.isVideoCall
                          ? _buildVideoLayout(
                              theme,
                              callState,
                              remoteName,
                              remoteAvatar,
                              statusLine,
                            )
                          : _buildVoiceLayout(
                              theme,
                              remoteName,
                              remoteAvatar,
                              statusLine,
                            ),
                    ),
                    if (callState.phase == ChatCallPhase.error)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Column(
                            children: [
                              Text(
                                callState.errorMessage ??
                                    'Unable to start the call.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: openAppSettings,
                                    icon: const Icon(Icons.settings_outlined),
                                    label: const Text('Open settings'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(
                                          color: Colors.white38),
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _handleClose,
                                    icon: const Icon(Icons.call_end),
                                    label: const Text('Close'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(
                                          color: Colors.white38),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 18,
                      runSpacing: 16,
                      children: [
                        _CallActionButton(
                          icon: callState.isMuted ? Icons.mic_off : Icons.mic,
                          label: callState.isMuted ? 'Unmute' : 'Mute',
                          backgroundColor: callState.isMuted
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.12),
                          foregroundColor: callState.isMuted
                              ? const Color(0xFF06111F)
                              : Colors.white,
                          onTap: canUseControls
                              ? () => ref
                                  .read(chatCallControllerProvider.notifier)
                                  .toggleMute()
                              : null,
                        ),
                        _CallActionButton(
                          icon: callState.isSpeakerOn
                              ? Icons.volume_up
                              : Icons.hearing,
                          label: callState.isSpeakerOn ? 'Speaker' : 'Earpiece',
                          backgroundColor: callState.isSpeakerOn
                              ? Colors.white.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.12),
                          foregroundColor: Colors.white,
                          onTap: canUseControls
                              ? () => ref
                                  .read(chatCallControllerProvider.notifier)
                                  .toggleSpeaker()
                              : null,
                        ),
                        if (widget.isVideoCall)
                          _CallActionButton(
                            icon: callState.isCameraEnabled
                                ? Icons.videocam
                                : Icons.videocam_off,
                            label: callState.isCameraEnabled
                                ? 'Camera'
                                : 'Camera off',
                            backgroundColor: callState.isCameraEnabled
                                ? Colors.white.withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.12),
                            foregroundColor: Colors.white,
                            onTap: canUseControls
                                ? () => ref
                                    .read(chatCallControllerProvider.notifier)
                                    .toggleCameraEnabled()
                                : null,
                          ),
                        if (widget.isVideoCall)
                          _CallActionButton(
                            icon: Icons.flip_camera_android,
                            label: callState.isFrontCamera
                                ? 'Front cam'
                                : 'Rear cam',
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.12),
                            foregroundColor: Colors.white,
                            onTap: canUseControls && callState.isCameraEnabled
                                ? () => ref
                                    .read(chatCallControllerProvider.notifier)
                                    .switchCamera()
                                : null,
                          ),
                        _CallActionButton(
                          icon: Icons.call_end,
                          label: 'End',
                          backgroundColor: const Color(0xFFE53935),
                          foregroundColor: Colors.white,
                          onTap: _handleClose,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceLayout(
    ThemeData theme,
    String remoteName,
    String remoteAvatar,
    String statusLine,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ParticipantAvatar(
            displayName: remoteName,
            avatarUrl: remoteAvatar,
            radius: 62,
          ),
          const SizedBox(height: 28),
          Text(
            remoteName,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            statusLine,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            widget.room.isGroup
                ? '${widget.room.participantCount} members in this call'
                : 'Live audio through WebRTC',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoLayout(
    ThemeData theme,
    ChatCallState callState,
    String remoteName,
    String remoteAvatar,
    String statusLine,
  ) {
    final showRemoteVideo =
        callState.hasRemoteVideo && callState.remoteRenderer != null;
    final showLocalVideo = callState.localRenderer != null &&
        callState.permissionsGranted &&
        callState.isCameraEnabled;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF21476C), Color(0xFF0C1C2E)],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            Positioned.fill(
              child: showRemoteVideo
                  ? RTCVideoView(
                      callState.remoteRenderer!,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    )
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        image: remoteAvatar.isNotEmpty
                            ? DecorationImage(
                                image: CachedNetworkImageProvider(remoteAvatar),
                                fit: BoxFit.cover,
                              )
                            : null,
                        gradient: remoteAvatar.isEmpty
                            ? const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF21476C), Color(0xFF0C1C2E)],
                              )
                            : null,
                      ),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.3),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _ParticipantAvatar(
                                displayName: remoteName,
                                avatarUrl: remoteAvatar,
                                radius: 52,
                              ),
                              const SizedBox(height: 20),
                              Text(
                                remoteName,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusLine,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 18,
              bottom: 18,
              child: Container(
                width: 116,
                height: 156,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                clipBehavior: Clip.antiAlias,
                child: showLocalVideo
                    ? RTCVideoView(
                        callState.localRenderer!,
                        mirror: callState.isFrontCamera,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            callState.isCameraEnabled
                                ? Icons.videocam
                                : Icons.videocam_off,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'You',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParticipantAvatar extends StatelessWidget {
  final String displayName;
  final String avatarUrl;
  final double radius;

  const _ParticipantAvatar({
    required this.displayName,
    required this.avatarUrl,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white.withValues(alpha: 0.14),
      backgroundImage:
          avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl) : null,
      child: avatarUrl.isEmpty
          ? Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : 'C',
              style: TextStyle(
                color: Colors.white,
                fontSize: radius * 0.55,
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
    );
  }
}

class _CallActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback? onTap;

  const _CallActionButton({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: backgroundColor,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 64,
              height: 64,
              child: Icon(icon, color: foregroundColor),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 72,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white70,
                ),
          ),
        ),
      ],
    );
  }
}

class _TopIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TopIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

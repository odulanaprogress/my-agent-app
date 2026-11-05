import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:agent_app/features/calls/models/call_model.dart';
import 'package:agent_app/features/calls/services/call_service.dart';
import 'package:agent_app/features/calls/services/webrtc_service.dart';
import 'package:agent_app/core/services/call_ringtone_service.dart';

class VideoCallScreen extends StatefulWidget {
  final String callId;
  final bool isIncoming;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPhoto;

  const VideoCallScreen({
    super.key,
    required this.callId,
    required this.isIncoming,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPhoto,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _callSub;
  CallStatus _status = CallStatus.calling;

  WebRTCService? _webrtcService;
  bool _hasRemoteVideo = false;

  Timer? _durationTimer;
  Timer? _ringTimeoutTimer;
  int _callDurationSeconds = 0;
  bool _isMuted = false;
  bool _isVideoOff = false;

  @override
  void initState() {
    super.initState();

    _status = widget.isIncoming ? CallStatus.ringing : CallStatus.calling;

    if (widget.isIncoming) {
      CallRingtoneService.playIncomingRing();
    } else {
      CallRingtoneService.playRingback();
    }

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initWebRTC();
    _listenToCallUpdates();

    if (!widget.isIncoming) {
      _ringTimeoutTimer = Timer(const Duration(seconds: 45), () {
        if (mounted && (_status == CallStatus.calling || _status == CallStatus.ringing)) {
          CallRingtoneService.stop();
          CallService.endCall(widget.callId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No answer'),
                backgroundColor: Color(0xFF1E293B),
              ),
            );
            Navigator.of(context).pop();
          }
        }
      });
    }
  }

  Future<void> _initWebRTC() async {
    _webrtcService = WebRTCService(
      callId: widget.callId,
      isCaller: !widget.isIncoming,
      isVideo: true,
      onRemoteStream: (stream) {
        if (mounted) {
          setState(() {
            _hasRemoteVideo = stream.getVideoTracks().isNotEmpty;
          });
        }
      },
      onConnected: () {
        debugPrint('[VideoCallScreen] WebRTC connection established!');
      },
    );

    await _webrtcService!.initializeRenderers();
    if (mounted) setState(() {});

    // For caller, immediately acquire camera and offer
    if (!widget.isIncoming) {
      await _webrtcService!.start();
      if (mounted) setState(() {});
    }
  }

  void _listenToCallUpdates() {
    _callSub = FirebaseFirestore.instance
        .collection('calls')
        .doc(widget.callId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) {
        CallRingtoneService.stop();
        _endAndClose();
        return;
      }

      final call = CallModel.fromFirestore(snapshot);
      if (mounted) {
        setState(() {
          _status = call.status;
        });

        if (call.status == CallStatus.ringing && !widget.isIncoming) {
          CallRingtoneService.playRingback();
        } else if (call.status == CallStatus.connected) {
          CallRingtoneService.stop();
          _ringTimeoutTimer?.cancel();
          if (_durationTimer == null) {
            _startDurationTimer();
          }
        } else if (call.status == CallStatus.ended ||
            call.status == CallStatus.declined) {
          CallRingtoneService.stop();
          _endAndClose();
        }
      }
    });
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _callDurationSeconds++);
    });
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _acceptCall() async {
    CallRingtoneService.stop();
    await CallService.acceptCall(widget.callId);
    await _webrtcService?.start();
    if (mounted) {
      setState(() {
        _status = CallStatus.connected;
      });
      _startDurationTimer();
    }
  }

  Future<void> _declineCall() async {
    CallRingtoneService.stop();
    await CallService.declineCall(widget.callId);
    _endAndClose();
  }

  Future<void> _endCall() async {
    await CallService.endCall(widget.callId);
    _endAndClose();
  }

  void _endAndClose() {
    CallRingtoneService.stop();
    _durationTimer?.cancel();
    _callSub?.cancel();
    _webrtcService?.dispose();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video call ended'),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFF1E293B),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    CallRingtoneService.stop();
    _pulseController.dispose();
    _durationTimer?.cancel();
    _ringTimeoutTimer?.cancel();
    _callSub?.cancel();
    _webrtcService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _status == CallStatus.connected;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // ── Remote Video Stream (Full Screen) ──
          Positioned.fill(
            child: (isConnected && _webrtcService?.remoteRenderer != null && _hasRemoteVideo)
                ? RTCVideoView(
                    _webrtcService!.remoteRenderer!,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  )
                : Container(
                    color: const Color(0xFF0F172A),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ScaleTransition(
                            scale: _pulseAnimation,
                            child: CircleAvatar(
                              radius: 54,
                              backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
                              backgroundImage: widget.otherUserPhoto != null && widget.otherUserPhoto!.isNotEmpty
                                  ? NetworkImage(widget.otherUserPhoto!)
                                  : null,
                              child: widget.otherUserPhoto == null || widget.otherUserPhoto!.isEmpty
                                  ? Text(
                                      widget.otherUserName.isNotEmpty ? widget.otherUserName[0].toUpperCase() : 'U',
                                      style: const TextStyle(fontSize: 42, color: Colors.white, fontWeight: FontWeight.bold),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            widget.otherUserName,
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isConnected
                                ? _formatDuration(_callDurationSeconds)
                                : (widget.isIncoming ? 'Incoming Video Call...' : (_status == CallStatus.ringing ? 'Ringing...' : 'Calling...')),
                            style: TextStyle(color: isConnected ? Colors.greenAccent : Colors.grey.shade400, fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),

          // ── Local Camera Feed (Corner Picture-in-Picture) ──
          if (_webrtcService?.localRenderer != null && !_isVideoOff)
            Positioned(
              top: 50,
              right: 18,
              width: 110,
              height: 155,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4)),
                    ],
                  ),
                  child: RTCVideoView(
                    _webrtcService!.localRenderer!,
                    mirror: true,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),
            ),

          // ── Top Bar with Status and Encryption Badge ──
          Positioned(
            top: 48,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.videocam_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    isConnected ? _formatDuration(_callDurationSeconds) : 'HD Video Call',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom Call Controls ──
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: widget.isIncoming && !isConnected
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _actionButton(
                        icon: Icons.call_end_rounded,
                        color: Colors.redAccent,
                        label: 'Decline',
                        onTap: _declineCall,
                      ),
                      _actionButton(
                        icon: Icons.videocam_rounded,
                        color: const Color(0xFF10B981),
                        label: 'Accept',
                        onTap: _acceptCall,
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Mute Button
                      _actionButton(
                        icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                        color: _isMuted ? Colors.redAccent : Colors.white24,
                        label: _isMuted ? 'Muted' : 'Mute',
                        onTap: () {
                          setState(() => _isMuted = !_isMuted);
                          _webrtcService?.toggleMute(_isMuted);
                        },
                      ),
                      // Video Toggle Button
                      _actionButton(
                        icon: _isVideoOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                        color: _isVideoOff ? Colors.redAccent : Colors.white24,
                        label: _isVideoOff ? 'Camera Off' : 'Camera On',
                        onTap: () {
                          setState(() => _isVideoOff = !_isVideoOff);
                          _webrtcService?.toggleVideo(_isVideoOff);
                        },
                      ),
                      // Switch Camera Button
                      _actionButton(
                        icon: Icons.switch_camera_rounded,
                        color: Colors.white24,
                        label: 'Flip',
                        onTap: () {
                          _webrtcService?.switchCamera();
                        },
                      ),
                      // End Call Button
                      _actionButton(
                        icon: Icons.call_end_rounded,
                        color: Colors.redAccent,
                        label: 'End',
                        onTap: _endCall,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

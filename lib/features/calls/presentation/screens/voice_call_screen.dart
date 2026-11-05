import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:agent_app/features/calls/models/call_model.dart';
import 'package:agent_app/features/calls/services/call_service.dart';
import 'package:agent_app/core/services/call_ringtone_service.dart';
import 'package:agent_app/features/calls/services/webrtc_service.dart';

class VoiceCallScreen extends StatefulWidget {
  final String callId;
  final bool isIncoming;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPhoto;

  const VoiceCallScreen({
    super.key,
    required this.callId,
    required this.isIncoming,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPhoto,
  });

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _callSub;
  CallStatus _status = CallStatus.calling;
  WebRTCService? _webrtcService;

  Timer? _durationTimer;
  Timer? _ringTimeoutTimer;
  int _callDurationSeconds = 0;
  bool _isMuted = false;
  bool _isSpeaker = false;

  @override
  void initState() {
    super.initState();

    _status = widget.isIncoming ? CallStatus.ringing : CallStatus.calling;

    if (widget.isIncoming) {
      CallRingtoneService.playIncomingRing();
    } else if (_status == CallStatus.ringing) {
      CallRingtoneService.playRingback();
    }

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Caller initializes WebRTC immediately to start audio session
    if (!widget.isIncoming) {
      _startWebRTC(isCaller: true);
    }

    _listenToCallUpdates();

    // Outbound call timeout: Wait up to 45 seconds for receiver to answer
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
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDurationSeconds++;
        });
      }
    });
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _startWebRTC({required bool isCaller}) async {
    if (_webrtcService != null) return;
    _webrtcService = WebRTCService(
      callId: widget.callId,
      isCaller: isCaller,
      isVideo: false,
      onConnected: () {
        debugPrint('[VoiceCallScreen] WebRTC audio connected!');
      },
    );
    await _webrtcService!.start();
  }

  Future<void> _endCall() async {
    await CallService.endCall(widget.callId);
    _endAndClose();
  }

  Future<void> _acceptCall() async {
    CallRingtoneService.stop();
    await CallService.acceptCall(widget.callId);
    await _startWebRTC(isCaller: false);
    if (mounted) {
      setState(() {
        _status = CallStatus.connected;
      });
      _startDurationTimer();
    }
  }

  void _endAndClose() {
    CallRingtoneService.stop();
    _durationTimer?.cancel();
    _callSub?.cancel();
    _webrtcService?.dispose();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voice call ended'),
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

  String _getCallStatusLabel() {
    if (_status == CallStatus.connected) {
      return _formatDuration(_callDurationSeconds);
    }
    if (widget.isIncoming) {
      return 'Incoming Call...';
    }
    if (_status == CallStatus.calling) {
      return 'Calling...';
    }
    if (_status == CallStatus.ringing) {
      return 'Ringing...';
    }
    return 'Connecting...';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Stack(
          children: [
            // Hidden audio pipeline element so WebRTC audio attaches to DOM in Flutter Web
            if (_webrtcService?.remoteRenderer != null)
              Offstage(
                offstage: true,
                child: SizedBox(
                  width: 1,
                  height: 1,
                  child: RTCVideoView(_webrtcService!.remoteRenderer!),
                ),
              ),
            Column(
              children: [
                // Top Status Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_rounded, size: 14, color: Color(0xFF10B981)),
                        SizedBox(width: 6),
                        Text(
                          'End-to-End Encrypted Call',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(flex: 1),

            // Animated Caller Avatar
            Center(
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Container(
                    width: 140 * _pulseAnimation.value,
                    height: 140 * _pulseAnimation.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF6366F1).withValues(
                        alpha: _status == CallStatus.connected ? 0.15 : 0.25,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF1E293B),
                          border: Border.all(
                            color: const Color(0xFF6366F1),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: widget.otherUserPhoto != null &&
                                  widget.otherUserPhoto!.isNotEmpty
                              ? Image.network(
                                  widget.otherUserPhoto!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => _avatarFallback(),
                                )
                              : _avatarFallback(),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 28),

            // Name
            Text(
              widget.otherUserName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 10),

            // Call Status Subtitle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: _status == CallStatus.connected
                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _getCallStatusLabel(),
                style: TextStyle(
                  color: _status == CallStatus.connected
                      ? const Color(0xFF10B981)
                      : const Color(0xFF818CF8),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            const Spacer(flex: 2),

            // Call Actions
            Padding(
              padding: const EdgeInsets.only(bottom: 40, left: 24, right: 24),
              child: _buildActionButtons(),
            ),
          ],
        ),
      ],
    ),
  ),
);
  }

  Widget _avatarFallback() {
    return Container(
      color: const Color(0xFF1E293B),
      child: Center(
        child: Text(
          widget.otherUserName.isNotEmpty ? widget.otherUserName[0].toUpperCase() : 'U',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 44,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    if (widget.isIncoming && _status != CallStatus.connected) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Decline Call
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _endCall,
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent,
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 34),
                ),
              ),
              const SizedBox(height: 10),
              const Text('Decline', style: TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),

          // Accept Call
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _acceptCall,
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF10B981),
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.call_rounded, color: Colors.white, size: 34),
                ),
              ),
              const SizedBox(height: 10),
              const Text('Accept', style: TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Mute Toggle
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () {
                setState(() => _isMuted = !_isMuted);
                _webrtcService?.toggleMute(_isMuted);
              },
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: _isMuted ? Colors.white : Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  color: _isMuted ? const Color(0xFF0F172A) : Colors.white,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isMuted ? 'Muted' : 'Mute',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),

        // End Call
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _endCall,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withValues(alpha: 0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 36),
              ),
            ),
            const SizedBox(height: 8),
            const Text('End', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),

        // Speaker Toggle
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () {
                setState(() => _isSpeaker = !_isSpeaker);
              },
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: _isSpeaker ? Colors.white : Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isSpeaker ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                  color: _isSpeaker ? const Color(0xFF0F172A) : Colors.white,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isSpeaker ? 'Speaker on' : 'Speaker',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}

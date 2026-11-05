import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCService {
  final String callId;
  final bool isCaller;
  final bool isVideo;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  RTCVideoRenderer? localRenderer;
  RTCVideoRenderer? remoteRenderer;

  StreamSubscription? _callDocSub;
  StreamSubscription? _remoteCandidatesSub;

  bool _hasRemoteDescription = false;
  final List<RTCIceCandidate> _pendingRemoteCandidates = [];

  final Function(MediaStream remoteStream)? onRemoteStream;
  final VoidCallback? onConnected;
  final VoidCallback? onDisconnected;

  static const Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {'urls': 'stun:stun3.l.google.com:19302'},
      {'urls': 'stun:stun4.l.google.com:19302'},
    ]
  };

  WebRTCService({
    required this.callId,
    required this.isCaller,
    this.isVideo = false,
    this.onRemoteStream,
    this.onConnected,
    this.onDisconnected,
  });

  /// Initialize renderers for video AND audio.
  /// On Web, RTCVideoRenderer attaches the MediaStream to the browser DOM so audio plays out of speakers.
  Future<void> initializeRenderers() async {
    localRenderer = RTCVideoRenderer();
    remoteRenderer = RTCVideoRenderer();
    await localRenderer!.initialize();
    await remoteRenderer!.initialize();
  }

  Future<void> start() async {
    try {
      if (localRenderer == null || remoteRenderer == null) {
        await initializeRenderers();
      }

      final mediaConstraints = <String, dynamic>{
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': isVideo
            ? {
                'facingMode': 'user',
                'width': {'ideal': 640},
                'height': {'ideal': 480},
              }
            : false,
      };

      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);

      if (localRenderer != null) {
        localRenderer!.srcObject = _localStream;
      }

      _peerConnection = await createPeerConnection(_iceServers);

      // Add local tracks to peer connection
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      // Handle remote tracks
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
          if (remoteRenderer != null) {
            remoteRenderer!.srcObject = _remoteStream;
          }
          // Enable all remote audio tracks
          for (final t in _remoteStream!.getAudioTracks()) {
            t.enabled = true;
          }
          onRemoteStream?.call(_remoteStream!);
        }
      };

      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        debugPrint('[WebRTC] Connection state: $state');
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          onConnected?.call();
        } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
          onDisconnected?.call();
        }
      };

      // Send local ICE candidates to Firestore
      final myCandidatesCollection = isCaller ? 'callerCandidates' : 'receiverCandidates';
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) async {
        try {
          await FirebaseFirestore.instance
              .collection('calls')
              .doc(callId)
              .collection(myCandidatesCollection)
              .add({
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          });
        } catch (_) {}
      };

      if (isCaller) {
        // Create Offer
        final offer = await _peerConnection!.createOffer({
          'offerToReceiveAudio': 1,
          'offerToReceiveVideo': isVideo ? 1 : 0,
        });
        await _peerConnection!.setLocalDescription(offer);

        await FirebaseFirestore.instance.collection('calls').doc(callId).set({
          'offer': {'type': offer.type, 'sdp': offer.sdp},
          'hasOffer': true,
        }, SetOptions(merge: true));

        // Listen for Answer
        _callDocSub = FirebaseFirestore.instance
            .collection('calls')
            .doc(callId)
            .snapshots()
            .listen((snap) async {
          final data = snap.data();
          if (data != null && data['answer'] != null && !_hasRemoteDescription) {
            _hasRemoteDescription = true;
            final answer = RTCSessionDescription(
              data['answer']['sdp'],
              data['answer']['type'],
            );
            await _peerConnection?.setRemoteDescription(answer);
            await _drainPendingCandidates();
          }
        });
      } else {
        // Receiver: Wait for Offer, then create Answer
        _callDocSub = FirebaseFirestore.instance
            .collection('calls')
            .doc(callId)
            .snapshots()
            .listen((snap) async {
          final data = snap.data();
          if (data != null && data['offer'] != null && !_hasRemoteDescription) {
            _hasRemoteDescription = true;
            final offer = RTCSessionDescription(
              data['offer']['sdp'],
              data['offer']['type'],
            );
            await _peerConnection?.setRemoteDescription(offer);
            await _drainPendingCandidates();

            final answer = await _peerConnection!.createAnswer({
              'offerToReceiveAudio': 1,
              'offerToReceiveVideo': isVideo ? 1 : 0,
            });
            await _peerConnection!.setLocalDescription(answer);

            await FirebaseFirestore.instance.collection('calls').doc(callId).set({
              'answer': {'type': answer.type, 'sdp': answer.sdp},
              'hasAnswer': true,
            }, SetOptions(merge: true));
          }
        });
      }

      // Listen for remote ICE candidates
      final remoteCandidatesCollection = isCaller ? 'receiverCandidates' : 'callerCandidates';
      _remoteCandidatesSub = FirebaseFirestore.instance
          .collection('calls')
          .doc(callId)
          .collection(remoteCandidatesCollection)
          .snapshots()
          .listen((snap) async {
        for (final change in snap.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data();
            if (data != null && data['candidate'] != null) {
              final candidate = RTCIceCandidate(
                data['candidate'],
                data['sdpMid'],
                data['sdpMLineIndex'],
              );
              if (_hasRemoteDescription && _peerConnection != null) {
                await _peerConnection?.addCandidate(candidate);
              } else {
                _pendingRemoteCandidates.add(candidate);
              }
            }
          }
        }
      });
    } catch (e) {
      debugPrint('[WebRTC] Start error: $e');
    }
  }

  Future<void> _drainPendingCandidates() async {
    for (final candidate in _pendingRemoteCandidates) {
      try {
        await _peerConnection?.addCandidate(candidate);
      } catch (_) {}
    }
    _pendingRemoteCandidates.clear();
  }

  void toggleMute(bool muted) {
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !muted;
    });
  }

  void toggleVideo(bool videoOff) {
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = !videoOff;
    });
  }

  void switchCamera() {
    if (isVideo && _localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().firstOrNull;
      if (videoTrack != null) {
        Helper.switchCamera(videoTrack);
      }
    }
  }

  Future<void> dispose() async {
    try {
      await _callDocSub?.cancel();
      await _remoteCandidatesSub?.cancel();

      _localStream?.getTracks().forEach((t) => t.stop());
      await _localStream?.dispose();
      _localStream = null;

      _remoteStream?.getTracks().forEach((t) => t.stop());
      await _remoteStream?.dispose();
      _remoteStream = null;

      await _peerConnection?.close();
      await _peerConnection?.dispose();
      _peerConnection = null;

      localRenderer?.srcObject = null;
      await localRenderer?.dispose();
      localRenderer = null;

      remoteRenderer?.srcObject = null;
      await remoteRenderer?.dispose();
      remoteRenderer = null;
    } catch (_) {}
  }
}

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

  static const Map<String, dynamic> _peerConnectionConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {'urls': 'stun:stun3.l.google.com:19302'},
      {'urls': 'stun:stun4.l.google.com:19302'},
      {'urls': 'stun:stun.cloudflare.com:3478'},
      {'urls': 'stun:stun.services.mozilla.com'},
    ],
    'sdpSemantics': 'unified-plan',
  };

  static const Map<String, dynamic> _peerConnectionConstraints = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ],
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
  /// On Web, RTCVideoRenderer mounts the MediaStream in the browser DOM so audio plays out of speakers.
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

      try {
        _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      } catch (e) {
        debugPrint('[WebRTC] getUserMedia failed with constraints, retrying with basic audio: $e');
        _localStream = await navigator.mediaDevices.getUserMedia({
          'audio': true,
          'video': isVideo,
        });
      }

      // Ensure local audio tracks are active
      for (final track in _localStream!.getAudioTracks()) {
        track.enabled = true;
      }

      if (isVideo && localRenderer != null) {
        localRenderer!.srcObject = _localStream;
      }

      _peerConnection = await createPeerConnection(
        _peerConnectionConfig,
        _peerConnectionConstraints,
      );

      // Add local tracks to peer connection
      for (final track in _localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }

      // Handle remote tracks
      _peerConnection!.onTrack = (RTCTrackEvent event) async {
        debugPrint('[WebRTC] onTrack: kind=${event.track.kind}, id=${event.track.id}, streams=${event.streams.length}');
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
        } else {
          _remoteStream ??= await createLocalMediaStream('remote_stream_${DateTime.now().millisecondsSinceEpoch}');
          _remoteStream!.addTrack(event.track);
        }

        if (remoteRenderer != null) {
          remoteRenderer!.srcObject = _remoteStream;
          remoteRenderer!.muted = false;
          await remoteRenderer!.setVolume(1.0);
        }

        for (final t in _remoteStream!.getAudioTracks()) {
          t.enabled = true;
        }

        onRemoteStream?.call(_remoteStream!);
      };

      // Fallback for browsers that trigger onAddStream
      _peerConnection!.onAddStream = (MediaStream stream) async {
        debugPrint('[WebRTC] onAddStream: id=${stream.id}');
        _remoteStream = stream;
        if (remoteRenderer != null) {
          remoteRenderer!.srcObject = _remoteStream;
          remoteRenderer!.muted = false;
          await remoteRenderer!.setVolume(1.0);
        }
        for (final t in _remoteStream!.getAudioTracks()) {
          t.enabled = true;
        }
        onRemoteStream?.call(_remoteStream!);
      };

      _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
        debugPrint('[WebRTC] ICE Connection state: $state');
        if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
            state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
          setSpeakerphoneOn(true);
          remoteRenderer?.muted = false;
          remoteRenderer?.setVolume(1.0);
          onConnected?.call();
        } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
            state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
            state == RTCIceConnectionState.RTCIceConnectionStateClosed) {
          onDisconnected?.call();
        }
      };

      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        debugPrint('[WebRTC] Connection state: $state');
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          setSpeakerphoneOn(true);
          remoteRenderer?.muted = false;
          remoteRenderer?.setVolume(1.0);
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
        if (candidate.candidate == null || candidate.candidate!.trim().isEmpty) return;
        try {
          await FirebaseFirestore.instance
              .collection('calls')
              .doc(callId)
              .collection(myCandidatesCollection)
              .add({
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (_) {}
      };

      final offerAnswerConstraints = <String, dynamic>{
        'mandatory': {
          'OfferToReceiveAudio': true,
          'OfferToReceiveVideo': isVideo,
        },
        'optional': [],
      };

      if (isCaller) {
        // Create Offer
        final offer = await _peerConnection!.createOffer(offerAnswerConstraints);
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

            final answer = await _peerConnection!.createAnswer(offerAnswerConstraints);
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
              final candStr = data['candidate'] as String?;
              if (candStr == null || candStr.trim().isEmpty) continue;

              final candidate = RTCIceCandidate(
                candStr,
                data['sdpMid'] as String?,
                (data['sdpMLineIndex'] as num?)?.toInt(),
              );

              if (_hasRemoteDescription && _peerConnection != null) {
                try {
                  await _peerConnection?.addCandidate(candidate);
                } catch (e) {
                  debugPrint('[WebRTC] Error adding ICE candidate: $e');
                }
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
    for (final candidate in List.from(_pendingRemoteCandidates)) {
      try {
        await _peerConnection?.addCandidate(candidate);
      } catch (e) {
        debugPrint('[WebRTC] Error draining pending candidate: $e');
      }
    }
    _pendingRemoteCandidates.clear();
  }

  void setSpeakerphoneOn(bool enabled) {
    try {
      Helper.setSpeakerphoneOn(enabled);
    } catch (_) {}
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

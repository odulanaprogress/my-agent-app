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
  final Set<String> _processedCandidateStrings = {};
  final Completer<void> _iceGatheringCompleter = Completer<void>();

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
      {'urls': 'stun:stun.nextcloud.com:443'},
      {'urls': 'stun:stun.nextcloud.com:3478'},
      {'urls': 'stun:stun.sipgate.net:3478'},
      {'urls': 'stun:stun.12voip.com:3478'},
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

      _peerConnection!.onIceGatheringState = (RTCIceGatheringState state) {
        debugPrint('[WebRTC] ICE Gathering state: $state');
        if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) {
          if (!_iceGatheringCompleter.isCompleted) {
            _iceGatheringCompleter.complete();
          }
        }
      };

      // Send local ICE candidates to Firestore (both directly to call document array and subcollection fallback)
      final myCandidatesField = isCaller ? 'callerCandidates' : 'receiverCandidates';
      final myCandidatesCollection = isCaller ? 'callerCandidates' : 'receiverCandidates';
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) async {
        if (candidate.candidate == null || candidate.candidate!.trim().isEmpty) return;
        final candData = {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        };

        // 1. Primary: Store on the main call document via arrayUnion (guaranteed permissions, atomic real-time update)
        try {
          await FirebaseFirestore.instance.collection('calls').doc(callId).update({
            myCandidatesField: FieldValue.arrayUnion([candData]),
          });
        } catch (e) {
          debugPrint('[WebRTC] Error appending candidate to call doc array: $e');
        }

        // 2. Secondary fallback: subcollection
        try {
          await FirebaseFirestore.instance
              .collection('calls')
              .doc(callId)
              .collection(myCandidatesCollection)
              .add({
            ...candData,
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

        // Allow up to 800ms for initial host/srflx candidates to gather directly into localDescription SDP
        await Future.any([
          Future.delayed(const Duration(milliseconds: 800)),
          _iceGatheringCompleter.future,
        ]);

        final finalOffer = await _peerConnection!.getLocalDescription() ?? offer;

        await FirebaseFirestore.instance.collection('calls').doc(callId).set({
          'offer': {'type': finalOffer.type, 'sdp': finalOffer.sdp},
          'hasOffer': true,
        }, SetOptions(merge: true));

        // Listen for Answer and Remote Candidates on main call doc
        _callDocSub = FirebaseFirestore.instance
            .collection('calls')
            .doc(callId)
            .snapshots()
            .listen((snap) async {
          final data = snap.data();
          if (data == null) return;

          if (data['answer'] != null && !_hasRemoteDescription) {
            _hasRemoteDescription = true;
            final answer = RTCSessionDescription(
              data['answer']['sdp'],
              data['answer']['type'],
            );
            await _peerConnection?.setRemoteDescription(answer);
            await _drainPendingCandidates();
          }

          // Process remote ICE candidates array from receiver
          _processRemoteCandidatesList(data['receiverCandidates']);
        });
      } else {
        // Receiver: Wait for Offer, then create Answer
        _callDocSub = FirebaseFirestore.instance
            .collection('calls')
            .doc(callId)
            .snapshots()
            .listen((snap) async {
          final data = snap.data();
          if (data == null) return;

          if (data['offer'] != null && !_hasRemoteDescription) {
            _hasRemoteDescription = true;
            final offer = RTCSessionDescription(
              data['offer']['sdp'],
              data['offer']['type'],
            );
            await _peerConnection?.setRemoteDescription(offer);
            await _drainPendingCandidates();

            final answer = await _peerConnection!.createAnswer(offerAnswerConstraints);
            await _peerConnection!.setLocalDescription(answer);

            // Allow up to 800ms for initial host/srflx candidates to gather directly into localDescription SDP
            await Future.any([
              Future.delayed(const Duration(milliseconds: 800)),
              _iceGatheringCompleter.future,
            ]);

            final finalAnswer = await _peerConnection!.getLocalDescription() ?? answer;

            await FirebaseFirestore.instance.collection('calls').doc(callId).set({
              'answer': {'type': finalAnswer.type, 'sdp': finalAnswer.sdp},
              'hasAnswer': true,
            }, SetOptions(merge: true));
          }

          // Process remote ICE candidates array from caller
          _processRemoteCandidatesList(data['callerCandidates']);
        });
      }

      // Secondary listener for remote ICE candidates via subcollection
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
              if (_processedCandidateStrings.contains(candStr)) continue;
              _processedCandidateStrings.add(candStr);

              final candidate = RTCIceCandidate(
                candStr,
                data['sdpMid'] as String?,
                (data['sdpMLineIndex'] as num?)?.toInt(),
              );

              if (_hasRemoteDescription && _peerConnection != null) {
                try {
                  await _peerConnection?.addCandidate(candidate);
                  debugPrint('[WebRTC] Added remote subcollection ICE candidate: $candStr');
                } catch (e) {
                  debugPrint('[WebRTC] Error adding ICE candidate: $e');
                }
              } else {
                _pendingRemoteCandidates.add(candidate);
                debugPrint('[WebRTC] Queued remote subcollection ICE candidate: $candStr');
              }
            }
          }
        }
      });
    } catch (e) {
      debugPrint('[WebRTC] Start error: $e');
    }
  }

  void _processRemoteCandidatesList(dynamic candidatesList) {
    if (candidatesList is! List) return;
    for (final item in candidatesList) {
      if (item is Map && item['candidate'] != null) {
        final candStr = item['candidate'] as String?;
        if (candStr == null || candStr.trim().isEmpty) continue;
        if (_processedCandidateStrings.contains(candStr)) continue;
        _processedCandidateStrings.add(candStr);

        final candidate = RTCIceCandidate(
          candStr,
          item['sdpMid'] as String?,
          (item['sdpMLineIndex'] as num?)?.toInt(),
        );

        if (_hasRemoteDescription && _peerConnection != null) {
          try {
            _peerConnection?.addCandidate(candidate);
            debugPrint('[WebRTC] Added remote ICE candidate from call doc array: $candStr');
          } catch (e) {
            debugPrint('[WebRTC] Error adding ICE candidate: $e');
          }
        } else {
          _pendingRemoteCandidates.add(candidate);
          debugPrint('[WebRTC] Queued remote ICE candidate before remoteDescription: $candStr');
        }
      }
    }
  }

  Future<void> _drainPendingCandidates() async {
    for (final candidate in List.from(_pendingRemoteCandidates)) {
      try {
        await _peerConnection?.addCandidate(candidate);
        debugPrint('[WebRTC] Drained pending candidate: ${candidate.candidate}');
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

      _pendingRemoteCandidates.clear();
      _processedCandidateStrings.clear();

      localRenderer?.srcObject = null;
      await localRenderer?.dispose();
      localRenderer = null;

      remoteRenderer?.srcObject = null;
      await remoteRenderer?.dispose();
      remoteRenderer = null;
    } catch (_) {}
  }
}

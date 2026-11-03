import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:agent_app/features/calls/models/call_model.dart';
import 'package:agent_app/features/calls/presentation/screens/voice_call_screen.dart';
import 'package:agent_app/core/services/onesignal_api_service.dart';
import 'package:agent_app/app/routes/app_router.dart';

class CallService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static StreamSubscription? _incomingCallSub;
  static String? _activeIncomingCallId;

  /// Starts listening for real-time incoming VoIP calls for the logged-in user
  static void listenForIncomingCalls() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    _incomingCallSub?.cancel();
    _incomingCallSub = _firestore
        .collection('calls')
        .where('receiverId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: CallStatus.calling.name)
        .snapshots()
        .listen((snapshot) {
      for (final doc in snapshot.docs) {
        final call = CallModel.fromFirestore(doc);
        final ageInSeconds = DateTime.now().difference(call.createdAt).inSeconds;

        // Only pop up if created within last 45 seconds and not already active
        if (ageInSeconds < 45 && _activeIncomingCallId != call.id) {
          _activeIncomingCallId = call.id;

          final nav = rootNavigatorKey.currentState;
          if (nav != null) {
            nav.push(
              MaterialPageRoute(
                builder: (_) => VoiceCallScreen(
                  callId: call.id,
                  isIncoming: true,
                  otherUserId: call.callerId,
                  otherUserName: call.callerName,
                  otherUserPhoto: call.callerPhoto,
                ),
              ),
            ).then((_) {
              _activeIncomingCallId = null;
            });
          }
        }
      }
    });
  }

  /// Stops listening for incoming calls (e.g. on logout)
  static void stopListening() {
    _incomingCallSub?.cancel();
    _incomingCallSub = null;
    _activeIncomingCallId = null;
  }

  /// Starts an in-app VoIP call to another user
  static Future<void> startVoiceCall(
    BuildContext context, {
    required String receiverId,
    required String receiverName,
    String? receiverPhoto,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to make in-app calls')),
      );
      return;
    }

    if (currentUser.uid == receiverId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot call yourself')),
      );
      return;
    }

    try {
      final callDoc = _firestore.collection('calls').doc();
      final callId = callDoc.id;

      final call = CallModel(
        id: callId,
        callerId: currentUser.uid,
        callerName: currentUser.displayName ?? 'Agent User',
        callerPhoto: currentUser.photoURL,
        receiverId: receiverId,
        receiverName: receiverName,
        receiverPhoto: receiverPhoto,
        status: CallStatus.calling,
        createdAt: DateTime.now(),
      );

      await callDoc.set(call.toMap());

      // Notify the receiver with both in-app notification and OneSignal push
      await OneSignalApiService.sendNotification(
        receiverUids: [receiverId],
        heading: '📞 Incoming Voice Call',
        content: '${call.callerName} is calling you on Agent App.',
        data: {
          'type': 'call',
          'callId': callId,
          'callerId': currentUser.uid,
          'callerName': call.callerName,
        },
      );

      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VoiceCallScreen(
              callId: callId,
              isIncoming: false,
              otherUserId: receiverId,
              otherUserName: receiverName,
              otherUserPhoto: receiverPhoto,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start call: $e')),
        );
      }
    }
  }

  /// Mark the call as connected
  static Future<void> markCallConnected(String callId) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': CallStatus.connected.name,
        'connectedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Accept an incoming call
  static Future<void> acceptCall(String callId) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': CallStatus.connected.name,
        'connectedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// End a call
  static Future<void> endCall(String callId) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': CallStatus.ended.name,
        'endedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Decline a call
  static Future<void> declineCall(String callId) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': CallStatus.declined.name,
        'endedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}

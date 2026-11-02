import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:agent_app/features/calls/models/call_model.dart';
import 'package:agent_app/features/calls/presentation/screens/voice_call_screen.dart';
import 'package:agent_app/features/notifications/repositories/notification_repository.dart';

class CallService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

      // Notify the receiver in notifications collection
      NotificationRepository().createNotification(
        userId: receiverId,
        title: '📞 Incoming Voice Call',
        body: '${call.callerName} is calling you on Agent App.',
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

  /// Decline an incoming call
  static Future<void> declineCall(String callId) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': CallStatus.declined.name,
        'endedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}

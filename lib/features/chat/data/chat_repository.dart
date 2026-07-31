import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/services/onesignal_api_service.dart';

class ChatRepository {
  final FirebaseFirestore _firestore;

  ChatRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const _conversations = 'conversations';

  CollectionReference<Map<String, dynamic>> get conversations =>
      _firestore.collection(_conversations);

  Stream<List<String>> watchConversationIdsForUser(String uid) {
    // Conversations where uid is in participants.
    // Sorted in-memory to avoid requiring a composite index in Firestore.
    return conversations
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
      final docs = snapshot.docs.toList();
      docs.sort((a, b) {
        final aTime = a.data()['lastMessageTime'] as Timestamp?;
        final bTime = b.data()['lastMessageTime'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1; // b is newer
        if (bTime == null) return -1; // a is newer
        return bTime.compareTo(aTime); // descending
      });
      return docs.where((d) {
        final data = d.data();
        final deletedBy = data['deletedBy'] as List<dynamic>? ?? [];
        return !deletedBy.contains(uid);
      }).map((d) => d.id).toList();
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMessages({
    required String conversationId,
    int limit = 30,
  }) {
    return conversations
        .doc(conversationId)
        .collection('messages')
        .orderBy('sentAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  Future<DocumentReference<Map<String, dynamic>>> ensureConversation({
    required String propertyId,
    required String tenantUid,
    required String landlordUid,
  }) async {
    // Try to find existing conversation for this property + same participants.
    // Note: MVP uses a deterministic conversationId based on participants + propertyId.
    // This avoids complex multi-field queries.
    final conversationId = _conversationId(propertyId, tenantUid, landlordUid);

    final docRef = conversations.doc(conversationId);

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) {
        tx.set(docRef, {
          'conversationId': conversationId,
          'propertyId': propertyId,
          'participants': [tenantUid, landlordUid],
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'deletedBy': [],
          'blockedBy': [],
          'isClosed': false,
        });
      }
    });

    return docRef;
  }

  String _conversationId(
    String propertyId,
    String tenantUid,
    String landlordUid,
  ) {
    // stable order
    final a = tenantUid;
    final b = landlordUid;
    return 'p_${propertyId}_u_${a}__$b';
  }

  Future<void> sendTextMessage({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required String message,
    String? replyToId,
    String? replyToText,
    String? replyToSender,
  }) async {
    final convDoc = await conversations.doc(conversationId).get();
    if (convDoc.exists) {
      final data = convDoc.data()!;
      if (data['isClosed'] == true) throw Exception('This ticket is closed.');
      if ((data['blockedBy'] as List<dynamic>? ?? []).isNotEmpty) throw Exception('Action not allowed. User is blocked.');
    }

    final msgRef = conversations
        .doc(conversationId)
        .collection('messages')
        .doc();

    final msgData = {
      'senderId': senderId,
      'receiverId': receiverId,
      'message': message,
      'messageType': 'text',
      'isRead': false,
      'sentAt': FieldValue.serverTimestamp(),
      if (replyToId != null) 'replyToId': replyToId,
      if (replyToText != null) 'replyToText': replyToText,
      if (replyToSender != null) 'replyToSender': replyToSender,
    };

    await _firestore.runTransaction((tx) async {
      tx.set(msgRef, msgData);

      tx.update(conversations.doc(conversationId), {
        'lastMessage': message,
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
    });

    // Send push notification
    try {
      final senderDoc = await _firestore.collection('users').doc(senderId).get();
      final senderName = senderDoc.data()?['name'] ?? senderDoc.data()?['fullName'] ?? 'Someone';
      await OneSignalApiService.sendChatMessageNotification(
        senderName: senderName,
        messageText: message,
        receiverUid: receiverId,
        conversationId: conversationId,
      );
    } catch (e) {
      print('Push notification error: $e');
    }
  }

  Future<void> sendAttachmentMessage({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required String fileUrl,
    required String fileType, // image | video | pdf
    required String fileName,
  }) async {
    final convDoc = await conversations.doc(conversationId).get();
    if (convDoc.exists) {
      final data = convDoc.data()!;
      if (data['isClosed'] == true) throw Exception('This ticket is closed.');
      if ((data['blockedBy'] as List<dynamic>? ?? []).isNotEmpty) throw Exception('Action not allowed. User is blocked.');
    }

    final msgRef = conversations
        .doc(conversationId)
        .collection('messages')
        .doc();

    await _firestore.runTransaction((tx) async {
      tx.set(msgRef, {
        'senderId': senderId,
        'receiverId': receiverId,
        'message': '[Attachment: $fileType]',
        'messageType': fileType,
        'fileUrl': fileUrl,
        'fileName': fileName,
        'isRead': false,
        'sentAt': FieldValue.serverTimestamp(),
      });

      tx.update(conversations.doc(conversationId), {
        'lastMessage': '[Attachment: $fileType]',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
    });

    // Send push notification
    try {
      final senderDoc = await _firestore.collection('users').doc(senderId).get();
      final senderName = senderDoc.data()?['name'] ?? senderDoc.data()?['fullName'] ?? 'Someone';
      await OneSignalApiService.sendChatMessageNotification(
        senderName: senderName,
        messageText: '[Attachment: $fileType]',
        receiverUid: receiverId,
        conversationId: conversationId,
      );
    } catch (e) {
      print('Push notification error: $e');
    }
  }

  Future<void> sendVoiceMessage({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required String fileUrl,
    required String durationStr,
    String? replyToId,
    String? replyToText,
    String? replyToSender,
  }) async {
    final convDoc = await conversations.doc(conversationId).get();
    if (convDoc.exists) {
      final data = convDoc.data()!;
      if (data['isClosed'] == true) throw Exception('This ticket is closed.');
      if ((data['blockedBy'] as List<dynamic>? ?? []).isNotEmpty) throw Exception('Action not allowed. User is blocked.');
    }

    final msgRef = conversations
        .doc(conversationId)
        .collection('messages')
        .doc();

    final msgData = {
      'senderId': senderId,
      'receiverId': receiverId,
      'message': 'Voice Message $durationStr',
      'messageType': 'audio',
      'fileUrl': fileUrl,
      'isRead': false,
      'sentAt': FieldValue.serverTimestamp(),
      if (replyToId != null) 'replyToId': replyToId,
      if (replyToText != null) 'replyToText': replyToText,
      if (replyToSender != null) 'replyToSender': replyToSender,
    };

    await _firestore.runTransaction((tx) async {
      tx.set(msgRef, msgData);

      tx.update(conversations.doc(conversationId), {
        'lastMessage': 'Voice Message $durationStr',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
    });

    // Send push notification
    try {
      final senderDoc = await _firestore.collection('users').doc(senderId).get();
      final senderName = senderDoc.data()?['name'] ?? senderDoc.data()?['fullName'] ?? 'Someone';
      await OneSignalApiService.sendChatMessageNotification(
        senderName: senderName,
        messageText: 'Sent a voice message',
        receiverUid: receiverId,
        conversationId: conversationId,
      );
    } catch (e) {
      print('Push notification error: $e');
    }
  }

  Future<void> deleteChat(String conversationId, String uid) async {
    final docRef = conversations.doc(conversationId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) return;
      
      List<dynamic> deletedBy = List.from(snap.data()?['deletedBy'] ?? []);
      if (!deletedBy.contains(uid)) {
        deletedBy.add(uid);
      }
      
      List<dynamic> participants = List.from(snap.data()?['participants'] ?? []);
      
      // If both participants have deleted it, actually delete the doc
      if (deletedBy.length >= participants.length && participants.isNotEmpty) {
        tx.delete(docRef);
      } else {
        tx.update(docRef, {'deletedBy': deletedBy});
      }
    });
  }

  Future<void> toggleBlockUser(String conversationId, String uid, bool block) async {
    final docRef = conversations.doc(conversationId);
    if (block) {
      await docRef.update({
        'blockedBy': FieldValue.arrayUnion([uid])
      });
    } else {
      await docRef.update({
        'blockedBy': FieldValue.arrayRemove([uid])
      });
    }
  }

  Future<void> closeTicket(String conversationId, String history) async {
    final docRef = conversations.doc(conversationId);
    await docRef.update({'isClosed': true});
    
    // Save history to a new collection
    await _firestore.collection('ticket_histories').add({
      'conversationId': conversationId,
      'history': history,
      'closedAt': FieldValue.serverTimestamp(),
    });
  }
}

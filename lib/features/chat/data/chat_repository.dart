import 'package:cloud_firestore/cloud_firestore.dart';

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
      return docs.map((d) => d.id).toList();
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
  }) async {
    final msgRef = conversations
        .doc(conversationId)
        .collection('messages')
        .doc();

    await _firestore.runTransaction((tx) async {
      tx.set(msgRef, {
        'senderId': senderId,
        'receiverId': receiverId,
        'message': message,
        'messageType': 'text',
        'isRead': false,
        'sentAt': FieldValue.serverTimestamp(),
      });

      tx.update(conversations.doc(conversationId), {
        'lastMessage': message,
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> sendAttachmentMessage({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required String fileUrl,
    required String fileType, // image | video | pdf
    required String fileName,
  }) async {
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
  }
}

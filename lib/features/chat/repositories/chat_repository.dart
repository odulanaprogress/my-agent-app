import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/message_model.dart';
import '../../../core/services/onesignal_api_service.dart';
import '../../notifications/repositories/notification_repository.dart';

class ChatRepository {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;


  String generateConversationId(String user1, String user2) {
    final ids = [user1, user2]..sort();
    return ids.join('_');
  }

  Future<void> sendMessage({
    required String receiverId,
    required String message,
  }) async {
    final currentUser = auth.currentUser;
    if (currentUser == null) return;

    // Check if the receiver has blocked the sender
    final receiverDoc = await firestore.collection('users').doc(receiverId).get();
    final receiverData = receiverDoc.data();
    if (receiverData != null && receiverData['blocked_users'] != null) {
      final blockedUsers = List<String>.from(receiverData['blocked_users']);
      if (blockedUsers.contains(currentUser.uid)) {
        throw Exception('You cannot send a message to this user.');
      }
    }

    final conversationId = generateConversationId(currentUser.uid, receiverId);

    final messageDoc = firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc();

    final messageModel = MessageModel(
      id: messageDoc.id,
      senderId: currentUser.uid,
      receiverId: receiverId,
      message: message,
      createdAt: Timestamp.now(),
    );

    await messageDoc.set(messageModel.toMap());

    await firestore.collection('conversations').doc(conversationId).set({
      'participants': [currentUser.uid, receiverId],
      'lastMessage': message,
      'updatedAt': Timestamp.now(),
    });

    final senderDoc = await firestore.collection('users').doc(currentUser.uid).get();
    final senderName = senderDoc.data()?['fullName'] ?? 'User';

    await OneSignalApiService.sendChatMessageNotification(
      senderName: senderName,
      messageText: message,
      receiverUid: receiverId,
      conversationId: conversationId,
    );

    // Create in-app notification
    await NotificationRepository().createNotification(
      userId: receiverId,
      title: 'New Message from $senderName',
      body: message,
    );
  }

  Stream<List<MessageModel>> getMessages(String receiverId) {
    final currentUser = auth.currentUser;
    final conversationId = generateConversationId(currentUser!.uid, receiverId);

    return firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => MessageModel.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  Future<void> blockUser(String userIdToBlock) async {
    final currentUser = auth.currentUser;
    if (currentUser == null) return;

    await firestore.collection('users').doc(currentUser.uid).set({
      'blocked_users': FieldValue.arrayUnion([userIdToBlock]),
    }, SetOptions(merge: true));
  }

  Future<void> deleteChat(String receiverId) async {
    final currentUser = auth.currentUser;
    if (currentUser == null) return;

    final conversationId = generateConversationId(currentUser.uid, receiverId);

    // To properly "delete" for one user, we could just remove the messages locally or delete the whole chat from DB.
    // For simplicity, we will delete the conversation document which hides it. 
    // Alternatively, a more robust way is keeping track of deleted status per participant, but this works for basic delete.
    await firestore.collection('conversations').doc(conversationId).delete();
  }
}

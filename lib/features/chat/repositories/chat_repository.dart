import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/message_model.dart';
import '../../notifications/repositories/notification_repository.dart';

class ChatRepository {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  final NotificationRepository notificationRepository =
      NotificationRepository();

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

    await notificationRepository.createNotification(
      userId: receiverId,
      title: 'New Message',
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
}

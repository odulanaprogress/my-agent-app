import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/notification_model.dart';

class NotificationRepository {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  Future<void> createNotification({
    required String userId,
    required String title,
    required String body,
  }) async {
    final notificationDoc = firestore.collection('notifications').doc();

    final notification = NotificationModel(
      id: notificationDoc.id,
      userId: userId,
      title: title,
      body: body,
      isRead: false,
      createdAt: Timestamp.now(),
    );

    await notificationDoc.set(notification.toMap());
  }

  Stream<List<NotificationModel>> getNotifications() {
    final currentUser = auth.currentUser;

    if (currentUser == null) {
      return Stream.value([]);
    }

    return firestore
        .collection('notifications')
        .where('userId', isEqualTo: currentUser.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  Future<void> markAsRead(String notificationId) async {
    await firestore.collection('notifications').doc(notificationId).update({
      'isRead': true,
    });
  }
}

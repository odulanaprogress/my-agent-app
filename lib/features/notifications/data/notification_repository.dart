import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationRepository {
  final FirebaseFirestore _firestore;

  NotificationRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> userNotifications({
    required String uid,
  }) {
    return _firestore
        .collection('notifications')
        .doc(uid)
        .collection('userNotifications');
  }

  Stream<List<NotificationItem>> watchUserNotifications({
    required String uid,
    int limit = 20,
  }) {
    return userNotifications(uid: uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) {
            final data = d.data();
            return NotificationItem.fromMap(data, d.id);
          }).toList(),
        );
  }

  Future<void> markAsRead({
    required String uid,
    required String notificationId,
  }) async {
    await userNotifications(
      uid: uid,
    ).doc(notificationId).update({'isRead': true});
  }

  Future<void> addNotification({
    required String uid,
    required String title,
    required String message,
    required String type,
    required String targetId,
  }) async {
    await userNotifications(uid: uid).add({
      'title': title,
      'message': message,
      'type': type,
      'isRead': false,
      'targetId': targetId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final String targetId;
  final DateTime createdAt;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.targetId,
    required this.createdAt,
  });

  static DateTime _parseDate(dynamic value) {
    if (value == null) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  factory NotificationItem.fromMap(Map<String, dynamic> map, String id) {
    return NotificationItem(
      id: id,
      title: map['title']?.toString() ?? '',
      message: map['message']?.toString() ?? '',
      type: map['type']?.toString() ?? '',
      isRead: (map['isRead'] == true) || (map['isRead'] == 1),
      targetId: map['targetId']?.toString() ?? '',
      createdAt: _parseDate(map['createdAt']),
    );
  }
}

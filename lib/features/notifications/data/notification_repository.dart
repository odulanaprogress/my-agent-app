import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationRepository {
  final FirebaseFirestore _firestore;

  NotificationRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _notificationsCollection =>
      _firestore.collection('notifications');

  Stream<List<NotificationItem>> watchUserNotifications({
    required String uid,
    int limit = 20,
  }) {
    return _notificationsCollection
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((d) {
        final data = d.data();
        return NotificationItem.fromMap(data, d.id);
      }).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (list.length > limit) {
        return list.sublist(0, limit);
      }
      return list;
    });
  }

  Future<void> markAsRead({
    required String uid,
    required String notificationId,
  }) async {
    try {
      await _notificationsCollection.doc(notificationId).update({'isRead': true});
    } catch (_) {
      try {
        await _firestore
            .collection('notifications')
            .doc(uid)
            .collection('userNotifications')
            .doc(notificationId)
            .update({'isRead': true});
      } catch (_) {}
    }
  }

  Future<void> addNotification({
    required String uid,
    required String title,
    required String message,
    required String type,
    required String targetId,
  }) async {
    await _notificationsCollection.add({
      'userId': uid,
      'title': title,
      'message': message,
      'body': message,
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
      return DateTime.now();
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return DateTime.now();
  }

  factory NotificationItem.fromMap(Map<String, dynamic> map, String id) {
    return NotificationItem(
      id: id,
      title: map['title']?.toString() ?? '',
      message: (map['message'] ?? map['body'])?.toString() ?? '',
      type: map['type']?.toString() ?? 'info',
      isRead: (map['isRead'] == true) || (map['isRead'] == 1),
      targetId: map['targetId']?.toString() ?? '',
      createdAt: _parseDate(map['createdAt']),
    );
  }
}

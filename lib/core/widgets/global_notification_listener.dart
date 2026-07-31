import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/notifications/models/notification_model.dart';

final notificationsStreamProvider = StreamProvider<List<NotificationModel>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value([]);
  
  return FirebaseFirestore.instance
      .collection('notifications')
      .where('userId', isEqualTo: user.uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => NotificationModel.fromMap(doc.data(), doc.id)).toList());
});

class GlobalNotificationListener extends ConsumerStatefulWidget {
  final Widget child;

  const GlobalNotificationListener({super.key, required this.child});

  @override
  ConsumerState<GlobalNotificationListener> createState() => _GlobalNotificationListenerState();
}

class _GlobalNotificationListenerState extends ConsumerState<GlobalNotificationListener> {
  DateTime? _lastSeenNotificationTime;

  @override
  void initState() {
    super.initState();
    _lastSeenNotificationTime = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<NotificationModel>>>(notificationsStreamProvider, (previous, next) {
      if (next.hasValue) {
        final notifications = next.value!;
        if (notifications.isNotEmpty) {
          final latestNotification = notifications.first;
          final latestTime = latestNotification.createdAt.toDate();
          
          if (_lastSeenNotificationTime != null && latestTime.isAfter(_lastSeenNotificationTime!)) {
            _lastSeenNotificationTime = latestTime;
            
            // Show snackbar using the root messenger
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.notifications_active_rounded, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(latestNotification.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(latestNotification.body, style: const TextStyle(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFF6366F1),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      }
    });

    return widget.child;
  }
}

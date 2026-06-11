import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../notifications/data/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

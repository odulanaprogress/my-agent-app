import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/super_admin_repository.dart';

final superAdminRepositoryProvider = Provider<SuperAdminRepository>((ref) {
  return SuperAdminRepository();
});

final platformSettingsProvider = StreamProvider.autoDispose<Map<String, dynamic>>((ref) {
  final repo = ref.watch(superAdminRepositoryProvider);
  return repo.watchPlatformSettings();
});

final auditLogsProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final repo = ref.watch(superAdminRepositoryProvider);
  return repo.watchAuditLogs(limit: 50);
});

final adminUsersProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final repo = ref.watch(superAdminRepositoryProvider);
  return repo.watchAdminUsers();
});

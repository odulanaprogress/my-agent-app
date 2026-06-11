import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/super_admin_repository.dart';

final superAdminRepositoryProvider = Provider<SuperAdminRepository>((ref) {
  return SuperAdminRepository();
});

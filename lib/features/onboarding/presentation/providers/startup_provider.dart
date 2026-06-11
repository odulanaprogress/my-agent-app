import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/app_startup_service.dart';

final startupServiceProvider = Provider<AppStartupService>((ref) {
  return AppStartupService();
});

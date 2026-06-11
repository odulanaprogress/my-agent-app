import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/legal_repository.dart';

final legalRepositoryProvider = Provider<LegalRepository>((ref) {
  return LegalRepository();
});

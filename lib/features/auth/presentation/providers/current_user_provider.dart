import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/user_model.dart';

final currentUserProvider = StateProvider<UserModel?>((ref) => null);

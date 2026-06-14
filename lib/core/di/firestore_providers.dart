import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/firestore_service.dart';

final firestoreServiceProvider = Provider<FirestoreService>(
  (ref) => FirestoreService(),
);

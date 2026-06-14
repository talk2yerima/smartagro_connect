import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/image_upload_service.dart';

final imageUploadServiceProvider = Provider<ImageUploadService>((ref) {
  return ImageUploadService();
});

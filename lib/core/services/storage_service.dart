import 'dart:io';

import 'cloudinary_service.dart';

/// Kept for backward-compatibility.
/// This project now uploads via Cloudinary (no firebase_storage dependency).
class StorageService {
  final CloudinaryService _cloudinaryService = CloudinaryService();

  Future<String> uploadPropertyImage(File imageFile) async {
    final url = await _cloudinaryService.uploadImage(imageFile);
    if (url == null) {
      throw Exception('Image upload failed');
    }
    return url;
  }
}

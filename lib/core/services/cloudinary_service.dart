import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../app/config/env_config.dart';

class CloudinaryService {
  static final String cloudName = EnvConfig.cloudinaryCloudName;

  // CREATE THIS IN CLOUDINARY SETTINGS
  static final String uploadPreset = EnvConfig.cloudinaryUploadPreset;

  Future<String?> uploadImage(File imageFile) async {
    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      );

      final request = http.MultipartRequest('POST', uri);

      request.fields['upload_preset'] = uploadPreset;

      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();

        final decodedData = jsonDecode(responseData);

        return decodedData['secure_url'];
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<String?> uploadVideo(File videoFile) async {
    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/video/upload',
      );

      final request = http.MultipartRequest('POST', uri);

      request.fields['upload_preset'] = uploadPreset;

      request.files.add(
        await http.MultipartFile.fromPath('file', videoFile.path),
      );

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final decodedData = jsonDecode(responseData);
        return decodedData['secure_url'];
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
}

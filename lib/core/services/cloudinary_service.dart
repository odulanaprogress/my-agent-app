import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

import '../../app/config/env_config.dart';
import '../network/api_client.dart';

class CloudinaryService {
  static final String cloudName = EnvConfig.cloudinaryCloudName;

  // Used for LOW-STAKES public content only (property photos). Anyone with
  // this cloud name + preset (both public, baked into the app) can upload
  // to it, and it delivers publicly — never use this for KYC/identity
  // documents. See uploadVerificationDocument below for those.
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

  /// Uploads a SENSITIVE document (government ID, selfie, proof of
  /// ownership, utility bill) for identity verification.
  ///
  /// Unlike [uploadImage], this requires the user to be authenticated: it
  /// first asks the backend (which verifies their Firebase ID token) for a
  /// short-lived signed upload authorization scoped to that user's own
  /// `kyc/{uid}` folder, with `type: authenticated` delivery — meaning the
  /// resulting file is not publicly viewable by URL alone, only via a
  /// separately signed, time-limited delivery link (see
  /// `getSignedDeliveryUrl` on the backend, used when e.g. an admin reviews
  /// the submission).
  ///
  /// Returns the Cloudinary `public_id` (not a public URL) — callers should
  /// store this and request a fresh signed delivery URL whenever the
  /// document actually needs to be displayed, rather than storing/reusing
  /// a URL.
  Future<String?> uploadVerificationDocument(File file) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Must be signed in to upload verification documents.');
    }

    // 1. Get a signed, time-boxed upload authorization from the backend.
    final sigResponse = await ApiClient.post('/uploads/cloudinary-signature', {});
    if (sigResponse['success'] != true) {
      throw Exception(sigResponse['error']?.toString() ?? 'Unable to authorize upload.');
    }

    // 2. Upload directly to Cloudinary using exactly the signed params —
    // any mismatch (extra/missing field, wrong value) causes Cloudinary to
    // reject the signature.
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/${sigResponse['cloudName']}/image/upload',
    );

    final request = http.MultipartRequest('POST', uri)
      ..fields['api_key'] = sigResponse['apiKey'].toString()
      ..fields['timestamp'] = sigResponse['timestamp'].toString()
      ..fields['signature'] = sigResponse['signature'].toString()
      ..fields['folder'] = sigResponse['folder'].toString()
      ..fields['type'] = sigResponse['type'].toString()
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final response = await request.send();
    final responseData = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception('Verification document upload failed: $responseData');
    }

    final decoded = jsonDecode(responseData);
    return decoded['public_id']?.toString();
  }
}


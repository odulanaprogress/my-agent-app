import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  // =====================
  // PAYSTACK
  // =====================

  static String get paystackPublicKey =>
      dotenv.env['PAYSTACK_PUBLIC_KEY'] ??
      const String.fromEnvironment('PAYSTACK_PUBLIC_KEY');

  // =====================
  // OPENAI
  // =====================

  static String get openAIApiKey =>
      dotenv.env['OPENAI_API_KEY'] ??
      const String.fromEnvironment('OPENAI_API_KEY');

  // =====================
  // CLOUDINARY
  // =====================

  static String get cloudinaryCloudName =>
      dotenv.env['CLOUDINARY_CLOUD_NAME'] ??
      const String.fromEnvironment('CLOUDINARY_CLOUD_NAME');

  static String get cloudinaryUploadPreset =>
      dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ??
      const String.fromEnvironment('CLOUDINARY_UPLOAD_PRESET');
}

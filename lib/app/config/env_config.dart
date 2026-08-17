import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  // =====================
  // PAYSTACK (public key only — safe for client)
  // =====================

  static String get paystackPublicKey =>
      dotenv.env['PAYSTACK_PUBLIC_KEY'] ??
      const String.fromEnvironment('PAYSTACK_PUBLIC_KEY');

  // =====================
  // CLOUDINARY (public key + unsigned preset — safe for client)
  // =====================

  static String get cloudinaryCloudName =>
      dotenv.env['CLOUDINARY_CLOUD_NAME'] ??
      const String.fromEnvironment('CLOUDINARY_CLOUD_NAME');

  static String get cloudinaryUploadPreset =>
      dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ??
      const String.fromEnvironment('CLOUDINARY_UPLOAD_PRESET');

  // =====================
  // FLUTTERWAVE (public key only — safe for client)
  // =====================

  static String get flutterwavePublicKey =>
      dotenv.env['FLUTTERWAVE_PUBLIC_KEY'] ??
      const String.fromEnvironment('FLUTTERWAVE_PUBLIC_KEY');

  // NOTE: FLUTTERWAVE_SECRET_KEY, FLUTTERWAVE_ENCRYPTION_KEY, and
  // OPENAI_API_KEY are intentionally NOT exposed here.
  // They live exclusively in Cloudflare Workers environment secrets.
  // Any feature needing them must call the Workers API with a Firebase token.
}


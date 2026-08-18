// All values here are PUBLIC keys only — safe for client use.
// They are baked in at build time via --dart-define flags.
// SECRET keys (Flutterwave secret, OneSignal REST key, Cloudinary API secret)
// are NEVER placed here — they live exclusively in Cloudflare Worker secrets
// and the Express backend environment.

class EnvConfig {
  // =====================
  // PAYSTACK (public key only — safe for client)
  // =====================
  static const String paystackPublicKey =
      String.fromEnvironment('PAYSTACK_PUBLIC_KEY', defaultValue: '');

  // =====================
  // CLOUDINARY (cloud name + unsigned upload preset — safe for client)
  // =====================
  static const String cloudinaryCloudName =
      String.fromEnvironment('CLOUDINARY_CLOUD_NAME', defaultValue: 'dfbzi8cmh');

  static const String cloudinaryUploadPreset =
      String.fromEnvironment('CLOUDINARY_UPLOAD_PRESET', defaultValue: 'agent_unsigned');

  // =====================
  // FLUTTERWAVE (PUBLIC key only — safe for client)
  // =====================
  static const String flutterwavePublicKey =
      String.fromEnvironment('FLUTTERWAVE_PUBLIC_KEY', defaultValue: '');

  // NOTE: FLUTTERWAVE_SECRET_KEY, FLUTTERWAVE_ENCRYPTION_KEY,
  // ONESIGNAL_REST_API_KEY, and CLOUDINARY_API_SECRET are intentionally
  // NOT here. They live exclusively in Cloudflare Worker secrets and
  // the Express backend .env (server-side only).
}

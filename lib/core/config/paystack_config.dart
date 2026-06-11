import 'package:agent_app/app/config/env_config.dart';

class PaystackConfig {
  // Paystack public key injected via `--dart-define=PAYSTACK_PUBLIC_KEY=...`
  // IMPORTANT: Do not put secret keys in the Flutter app.
  static final String publicKey = EnvConfig.paystackPublicKey;
}

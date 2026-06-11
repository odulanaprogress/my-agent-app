import 'package:agent_app/app/config/env_config.dart';

class AIConfig {
  /// OpenAI API key injected at runtime using `--dart-define=OPENAI_API_KEY=...`
  ///
  /// NOTE: Still not ideal to ship raw keys in the mobile app—production
  /// deployments should proxy requests via a backend.
  static final String apiKey = EnvConfig.openAIApiKey;
}

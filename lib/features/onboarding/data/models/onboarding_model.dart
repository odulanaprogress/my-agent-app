class OnboardingModel {
  final String title;
  final String description;

  /// Image file name located under `assets/images/onboarding/`.
  final String image;

  const OnboardingModel({
    required this.title,
    required this.description,
    required this.image,
  });

  /// Convenience getter for the full asset path.
  String get assetPath => 'assets/images/onboarding/$image';
}

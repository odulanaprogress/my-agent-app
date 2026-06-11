enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final String? errorMessage;
  final bool onboardingCompleted;
  final bool privacyAccepted;
  final String? selectedRole;

  const AuthState({
    this.status = AuthStatus.initial,
    this.errorMessage,
    this.onboardingCompleted = false,
    this.privacyAccepted = false,
    this.selectedRole,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? errorMessage,
    bool? onboardingCompleted,
    bool? privacyAccepted,
    String? selectedRole,
  }) {
    return AuthState(
      status: status ?? this.status,
      errorMessage: errorMessage,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      privacyAccepted: privacyAccepted ?? this.privacyAccepted,
      selectedRole: selectedRole ?? this.selectedRole,
    );
  }
}

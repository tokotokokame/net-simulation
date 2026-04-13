// lib/auth/auth_state.dart

sealed class UserAuthState {
  const UserAuthState();
}

class UnauthenticatedState extends UserAuthState {
  const UnauthenticatedState();
}

class AuthenticatedState extends UserAuthState {
  final String userId;
  final String email;
  final bool isPro;

  const AuthenticatedState({
    required this.userId,
    required this.email,
    required this.isPro,
  });

  AuthenticatedState copyWith({
    String? userId,
    String? email,
    bool? isPro,
  }) {
    return AuthenticatedState(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      isPro: isPro ?? this.isPro,
    );
  }

  @override
  String toString() =>
      'AuthenticatedState(userId: $userId, email: $email, isPro: $isPro)';
}

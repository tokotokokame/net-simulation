// lib/auth/user_auth_service.dart
import 'dart:developer';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_state.dart';

class UserAuthNotifier extends StateNotifier<UserAuthState> {
  UserAuthNotifier() : super(const UnauthenticatedState()) {
    log('UserAuthNotifier initialized', name: 'Auth');
  }

  /// Mock login — replace with Firebase Auth later.
  Future<void> login({required String email, required String password}) async {
    log('Login attempt: $email', name: 'Auth');
    await Future.delayed(const Duration(milliseconds: 300));

    if (email.isEmpty || password.length < 6) {
      log('Login failed: invalid credentials', name: 'Auth');
      throw ArgumentError('Invalid credentials');
    }

    final isPro = email.endsWith('@pro.test');
    state = AuthenticatedState(
      userId: 'mock-uid-${email.hashCode.abs()}',
      email: email,
      isPro: isPro,
    );
    log('Login success: $email isPro=$isPro', name: 'Auth');
  }

  /// Mock registration — replace with Firebase Auth later.
  Future<void> register({
    required String email,
    required String password,
  }) async {
    log('Register attempt: $email', name: 'Auth');
    await Future.delayed(const Duration(milliseconds: 300));

    if (email.isEmpty || !email.contains('@')) {
      log('Register failed: invalid email', name: 'Auth');
      throw ArgumentError('Invalid email');
    }
    if (password.length < 6) {
      log('Register failed: password too short', name: 'Auth');
      throw ArgumentError('Password must be at least 6 characters');
    }

    state = AuthenticatedState(
      userId: 'mock-uid-${email.hashCode.abs()}',
      email: email,
      isPro: false,
    );
    log('Register success: $email', name: 'Auth');
  }

  void upgradeToPro() {
    final current = state;
    if (current is AuthenticatedState) {
      state = current.copyWith(isPro: true);
      log('Upgraded to Pro: ${current.email}', name: 'Auth');
    }
  }

  void logout() {
    log('Logout', name: 'Auth');
    state = const UnauthenticatedState();
  }

  bool get isAuthenticated => state is AuthenticatedState;

  bool get isPro {
    final current = state;
    return current is AuthenticatedState && current.isPro;
  }
}

final userAuthProvider =
    StateNotifierProvider<UserAuthNotifier, UserAuthState>(
  (ref) => UserAuthNotifier(),
);

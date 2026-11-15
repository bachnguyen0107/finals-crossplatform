import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

const _connectionErrorMessage =
    'Unable to connect to the server. Please check your internet connection and try again.';

const _genericAuthErrorMessage = 'Authentication failed. Please try again.';

const _networkTimeout = Duration(seconds: 15);

class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

String authErrorMessage(AuthException error) {
  if (error is AuthRetryableFetchException) {
    return _connectionErrorMessage;
  }

  final raw = error.message.trim();
  final msg = raw.toLowerCase();

  if (msg.contains('failed to fetch') ||
      msg.contains('clientexception') ||
      msg.contains('socketexception') ||
      msg.contains('network') ||
      msg.contains('connection')) {
    return _connectionErrorMessage;
  }

  if (msg.contains('invalid login credentials')) {
    return 'Incorrect email or password. Please try again.';
  }
  if (msg.contains('user already registered') ||
      msg.contains('already exists')) {
    return 'An account with this email already exists.';
  }
  if (msg.contains('email not confirmed')) {
    return 'Please confirm your email address before signing in.';
  }
  if (msg.contains('password should be at least')) {
    return 'Password must be at least 6 characters long.';
  }
  if (msg.contains('unable to validate email address') ||
      msg.contains('invalid email')) {
    return 'Please enter a valid email address.';
  }
  if (msg.contains('rate limit') || msg.contains('too many requests')) {
    return 'Too many attempts. Please wait a moment and try again.';
  }

  if (_isSafeReadableMessage(raw)) {
    return raw;
  }

  return _genericAuthErrorMessage;
}

bool _isSafeReadableMessage(String message) {
  if (message.isEmpty || message.length > 120 || message.contains('\n')) {
    return false;
  }
  final lower = message.toLowerCase();
  if (lower.contains('http') ||
      lower.contains('exception') ||
      lower.contains('uri=') ||
      lower.contains('supabase') ||
      lower.contains('stacktrace')) {
    return false;
  }
  return true;
}

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;

  Session? get currentSession => _client.auth.currentSession;

  Stream<AuthState> authStateChanges() => _client.auth.onAuthStateChange;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      return await _client.auth
          .signUp(
            email: email.trim(),
            password: password,
            data: {'display_name': displayName.trim()},
          )
          .timeout(_networkTimeout);
    } on TimeoutException {
      throw const AuthFailure(_connectionErrorMessage);
    } on AuthException catch (e) {
      throw AuthFailure(authErrorMessage(e));
    } catch (_) {
      throw const AuthFailure(_connectionErrorMessage);
    }
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _client.auth
          .signInWithPassword(
            email: email.trim(),
            password: password,
          )
          .timeout(_networkTimeout);
    } on TimeoutException {
      throw const AuthFailure(_connectionErrorMessage);
    } on AuthException catch (e) {
      throw AuthFailure(authErrorMessage(e));
    } catch (_) {
      throw const AuthFailure(_connectionErrorMessage);
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut().timeout(_networkTimeout);
    } on TimeoutException {
      throw const AuthFailure(_connectionErrorMessage);
    } on AuthException catch (e) {
      throw AuthFailure(authErrorMessage(e));
    } catch (_) {
      throw const AuthFailure('Unable to sign out right now. Please try again.');
    }
  }
}
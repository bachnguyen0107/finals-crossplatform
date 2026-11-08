import 'package:supabase_flutter/supabase_flutter.dart';

class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
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
      return await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'display_name': displayName.trim()},
      );
    } on AuthException catch (e) {
      throw AuthFailure(_mapAuthException(e));
    } catch (_) {
      throw const AuthFailure(
        'Unable to connect to the server. Please check your internet connection and try again.',
      );
    }
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } on AuthException catch (e) {
      throw AuthFailure(_mapAuthException(e));
    } catch (_) {
      throw const AuthFailure(
        'Unable to connect to the server. Please check your internet connection and try again.',
      );
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (e) {
      throw AuthFailure(_mapAuthException(e));
    } catch (_) {
      throw const AuthFailure('Unable to sign out right now. Please try again.');
    }
  }

  String _mapAuthException(AuthException error) {
    final msg = error.message.toLowerCase();

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

    return error.message.isNotEmpty
        ? error.message
        : 'Authentication failed. Please try again.';
  }
}

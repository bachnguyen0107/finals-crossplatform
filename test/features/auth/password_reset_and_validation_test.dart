import 'package:finals/features/auth/application/password_validators.dart';
import 'package:finals/features/auth/data/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('Password validation', () {
    test('rejects empty password', () {
      expect(validateNewPassword(''), 'Password is required.');
      expect(validateNewPassword(null), 'Password is required.');
    });

    test('rejects password shorter than 6 characters', () {
      expect(
        validateNewPassword('12345'),
        'Password must be at least 6 characters.',
      );
    });

    test('accepts password with 6 or more characters', () {
      expect(validateNewPassword('123456'), isNull);
      expect(validateNewPassword('strongPass99'), isNull);
    });

    test('validates confirmation password match', () {
      expect(
        validateConfirmPassword('', 'secret123'),
        'Please confirm your new password.',
      );
      expect(
        validateConfirmPassword('secret124', 'secret123'),
        'Passwords do not match.',
      );
      expect(validateConfirmPassword('secret123', 'secret123'), isNull);
    });
  });

  group('OTP and password error mapping', () {
    test('maps expired OTP error to friendly message', () {
      const error = AuthException(
        'Token has expired or is invalid',
        code: 'otp_expired',
      );
      expect(
        authErrorMessage(error),
        'Invalid or expired verification code. Please check the 6-digit code or request a new one.',
      );
    });

    test('maps invalid OTP error to friendly message', () {
      const error = AuthException('Invalid OTP token provided');
      expect(
        authErrorMessage(error),
        'Invalid verification code. Please check the 6-digit code and try again.',
      );
    });

    test('maps weak password error to friendly message', () {
      const error = AuthException(
        'Password is too weak',
        code: 'weak_password',
      );
      expect(
        authErrorMessage(error),
        'Password must be at least 6 characters long.',
      );
    });

    test('maps rate limit error to friendly message', () {
      const error = AuthException(
        'For security purposes, you can only request this after 58 seconds',
        statusCode: '429',
      );
      expect(
        authErrorMessage(error),
        'Too many attempts. Please wait a moment and try again.',
      );
    });

    test('maps network exception to friendly connection message', () {
      final error = AuthRetryableFetchException(message: 'Failed to fetch');
      expect(
        authErrorMessage(error),
        'Unable to connect to the server. Please check your internet connection and try again.',
      );
    });
  });
}
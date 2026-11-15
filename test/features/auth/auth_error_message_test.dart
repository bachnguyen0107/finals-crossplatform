import 'package:finals/features/auth/data/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const connectionMessage =
      'Unable to connect to the server. Please check your internet connection and try again.';

  group('authErrorMessage', () {
    test('returns connection message for AuthRetryableFetchException', () {
      final error = AuthRetryableFetchException(
        message:
            'ClientException: Failed to fetch, uri=https://nxiajtfwoizbpqsljpwu.supabase.co/auth/v1/token?grant_type=password',
      );

      expect(authErrorMessage(error), connectionMessage);
    });

    test('returns connection message for network-style AuthException message', () {
      const error = AuthException(
        'SocketException: Failed host lookup: supabase.co',
      );

      expect(authErrorMessage(error), connectionMessage);
    });

    test('returns wrong-password message for "Invalid login credentials"', () {
      const error = AuthException('Invalid login credentials');

      expect(
        authErrorMessage(error),
        'Incorrect email or password. Please try again.',
      );
    });

    test('does not leak URL or exception class names for unknown messages', () {
      const error = AuthException(
        'CustomException occurred at https://nxiajtfwoizbpqsljpwu.supabase.co/auth/v1/signup',
      );

      final result = authErrorMessage(error);

      expect(result, isNot(contains('http')));
      expect(result, isNot(contains('supabase.co')));
      expect(result, isNot(contains('Exception')));
      expect(result, 'Authentication failed. Please try again.');
    });
  });
}
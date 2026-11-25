import 'package:finals/features/sharing/presentation/share_note_dialog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateShareEmailInput', () {
    test('rejects empty or whitespace-only email', () {
      expect(
        validateShareEmailInput(rawEmail: '   '),
        'Please enter an email address.',
      );
    });

    test('rejects malformed email addresses', () {
      expect(
        validateShareEmailInput(rawEmail: 'not-an-email'),
        'Please enter a valid email address.',
      );
      expect(
        validateShareEmailInput(rawEmail: 'user@domain'),
        'Please enter a valid email address.',
      );
      expect(
        validateShareEmailInput(rawEmail: '@domain.com'),
        'Please enter a valid email address.',
      );
    });

    test('rejects sharing with current user email (case-insensitive)', () {
      expect(
        validateShareEmailInput(
          rawEmail: 'Owner@Example.com',
          currentUserEmail: 'owner@example.com',
        ),
        'You cannot share a note with yourself.',
      );
    });

    test('rejects duplicate recipient email (case-insensitive & trimmed)', () {
      expect(
        validateShareEmailInput(
          rawEmail: '  Teammate@Example.COM ',
          currentUserEmail: 'owner@example.com',
          existingRecipientEmails: const ['teammate@example.com'],
        ),
        'This note is already shared with this user.',
      );
    });

    test('accepts valid non-self, non-duplicate email', () {
      expect(
        validateShareEmailInput(
          rawEmail: '  new.user@example.com ',
          currentUserEmail: 'owner@example.com',
          existingRecipientEmails: const ['other@example.com'],
        ),
        isNull,
      );
    });
  });
}
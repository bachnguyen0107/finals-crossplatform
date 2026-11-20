import 'package:finals/features/notes/application/note_view_mode.dart';
import 'package:finals/features/settings/application/avatar_validator.dart';
import 'package:finals/features/settings/data/preferences_repository.dart';
import 'package:finals/features/settings/presentation/widgets/user_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('PreferencesRepository persistence', () {
    test('returns default values when preferences are empty', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = PreferencesRepository(prefs);

      expect(repository.getThemeMode(), ThemeMode.system);
      expect(repository.getNoteFontSize(), NoteFontSize.medium);
      expect(repository.getNoteViewMode(), NoteViewMode.grid);
    });

    test('persists and restores theme, font size and note view mode', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = PreferencesRepository(prefs);

      await repository.setThemeMode(ThemeMode.dark);
      await repository.setNoteFontSize(NoteFontSize.large);
      await repository.setNoteViewMode(NoteViewMode.list);

      final reloadedRepository = PreferencesRepository(prefs);
      expect(reloadedRepository.getThemeMode(), ThemeMode.dark);
      expect(reloadedRepository.getNoteFontSize(), NoteFontSize.large);
      expect(reloadedRepository.getNoteViewMode(), NoteViewMode.list);
    });
  });

  group('Avatar validation and default avatar initials', () {
    test('accepts valid jpg, png and webp images within 2 MB', () {
      expect(
        validateAvatarFile(fileName: 'photo.jpg', byteLength: 500 * 1024)
            .isValid,
        isTrue,
      );
      expect(
        validateAvatarFile(fileName: 'avatar.PNG', byteLength: 1024 * 1024)
            .isValid,
        isTrue,
      );
      expect(
        validateAvatarFile(
          fileName: 'blob',
          mimeType: 'image/webp',
          byteLength: 2 * 1024 * 1024,
        ).isValid,
        isTrue,
      );
    });

    test('rejects unsupported file types and images larger than 2 MB', () {
      final badType = validateAvatarFile(
        fileName: 'anim.gif',
        byteLength: 100 * 1024,
      );
      expect(badType.isValid, isFalse);

      final tooLarge = validateAvatarFile(
        fileName: 'large.png',
        byteLength: (2 * 1024 * 1024) + 1,
      );
      expect(tooLarge.isValid, isFalse);
    });

    testWidgets('UserAvatar displays initials when no avatarUrl is provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: UserAvatar(
                displayName: 'Vuong Gia Huy',
                email: 'huy@example.com',
              ),
            ),
          ),
        ),
      );

      expect(find.text('VH'), findsOneWidget);
    });
  });
}
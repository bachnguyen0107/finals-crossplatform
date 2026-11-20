import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/application/auth_providers.dart';
import '../../auth/data/auth_repository.dart';
import '../../notes/application/note_view_mode.dart';
import '../application/settings_providers.dart';
import '../data/preferences_repository.dart';
import 'widgets/user_avatar.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _imagePicker = ImagePicker();

  bool _isUploadingAvatar = false;
  bool _isUpdatingName = false;
  bool _isSigningOut = false;

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Future<void> _pickAndUploadAvatar() async {
    if (_isUploadingAvatar) return;

    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      setState(() {
        _isUploadingAvatar = true;
      });

      final bytes = await picked.readAsBytes();
      await ref.read(authRepositoryProvider).uploadAvatar(
            bytes: bytes,
            fileName: picked.name,
            mimeType: picked.mimeType,
          );
      _showSnackBar('Avatar updated.');
    } on AuthFailure catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar(
        'Unable to update avatar. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
        });
      }
    }
  }

  Future<void> _editDisplayName(String currentName) async {
    if (_isUpdatingName) return;

    final controller = TextEditingController(text: currentName);
    final formKey = GlobalKey<FormState>();

    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit display name'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Display name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Display name cannot be empty.';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(dialogContext).pop(controller.text.trim());
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    if (newName == null || newName == currentName.trim()) return;

    setState(() {
      _isUpdatingName = true;
    });

    try {
      await ref.read(authRepositoryProvider).updateDisplayName(newName);
      _showSnackBar('Display name updated.');
    } on AuthFailure catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar(
        'Unable to update display name. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingName = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    if (_isSigningOut) return;

    setState(() {
      _isSigningOut = true;
    });

    try {
      await ref.read(authRepositoryProvider).signOut();
      if (!mounted) return;
      context.go('/login');
    } on AuthFailure catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar('Unable to sign out right now.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSigningOut = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final metadata = user?.userMetadata ?? const <String, dynamic>{};

    final displayName = (metadata['display_name'] as String? ?? '').trim();
    final avatarUrl = (metadata['avatar_url'] as String? ?? '').trim();
    final email = user?.email ?? '';

    final themeMode = ref.watch(themeModeProvider);
    final noteFontSize = ref.watch(noteFontSizeProvider);
    final noteViewMode = ref.watch(noteViewModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            UserAvatar(
                              avatarUrl: avatarUrl,
                              displayName: displayName,
                              email: email,
                              radius: 36,
                            ),
                            Material(
                              color: theme.colorScheme.primary,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: _isUploadingAvatar
                                    ? null
                                    : _pickAndUploadAvatar,
                                child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: _isUploadingAvatar
                                      ? SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: theme.colorScheme.onPrimary,
                                          ),
                                        )
                                      : Icon(
                                          Icons.camera_alt_outlined,
                                          size: 16,
                                          color: theme.colorScheme.onPrimary,
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      displayName.isNotEmpty
                                          ? displayName
                                          : 'No display name',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Edit display name',
                                    onPressed: _isUpdatingName
                                        ? null
                                        : () => _editDisplayName(displayName),
                                    icon: _isUpdatingName
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.edit_outlined),
                                  ),
                                ],
                              ),
                              if (email.isNotEmpty)
                                Text(
                                  email,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              const SizedBox(height: 4),
                              Text(
                                'JPG, PNG or WEBP (max 2 MB)',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Account',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.lock_reset_outlined),
                    title: const Text('Change password'),
                    subtitle: const Text(
                      'Update your password using your current password',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/settings/change-password'),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Preferences',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Theme', style: theme.textTheme.titleSmall),
                        const SizedBox(height: 8),
                        SegmentedButton<ThemeMode>(
                          segments: const [
                            ButtonSegment(
                              value: ThemeMode.system,
                              label: Text('System'),
                              icon: Icon(Icons.brightness_auto_outlined),
                            ),
                            ButtonSegment(
                              value: ThemeMode.light,
                              label: Text('Light'),
                              icon: Icon(Icons.light_mode_outlined),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              label: Text('Dark'),
                              icon: Icon(Icons.dark_mode_outlined),
                            ),
                          ],
                          selected: {themeMode},
                          onSelectionChanged: (selection) {
                            ref
                                .read(themeModeProvider.notifier)
                                .setThemeMode(selection.first);
                          },
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Note font size',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<NoteFontSize>(
                          segments: const [
                            ButtonSegment(
                              value: NoteFontSize.small,
                              label: Text('Small'),
                            ),
                            ButtonSegment(
                              value: NoteFontSize.medium,
                              label: Text('Medium'),
                            ),
                            ButtonSegment(
                              value: NoteFontSize.large,
                              label: Text('Large'),
                            ),
                          ],
                          selected: {noteFontSize},
                          onSelectionChanged: (selection) {
                            ref
                                .read(noteFontSizeProvider.notifier)
                                .setNoteFontSize(selection.first);
                          },
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Default note view',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<NoteViewMode>(
                          segments: const [
                            ButtonSegment(
                              value: NoteViewMode.grid,
                              label: Text('Grid'),
                              icon: Icon(Icons.grid_view_outlined),
                            ),
                            ButtonSegment(
                              value: NoteViewMode.list,
                              label: Text('List'),
                              icon: Icon(Icons.view_list_outlined),
                            ),
                          ],
                          selected: {noteViewMode},
                          onSelectionChanged: (selection) {
                            if (selection.first != noteViewMode) {
                              ref.read(noteViewModeProvider.notifier).toggle();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.tonalIcon(
                  onPressed: _isSigningOut ? null : _signOut,
                  style: FilledButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: _isSigningOut
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.logout),
                  label: const Text('Logout'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
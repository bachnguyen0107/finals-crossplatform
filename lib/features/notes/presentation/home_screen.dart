import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/application/auth_providers.dart';
import '../application/note_view_mode.dart';
import '../application/notes_providers.dart';
import 'widgets/notes_view.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesControllerProvider);
    final mode = ref.watch(noteViewModeProvider);
    final isGrid = mode == NoteViewMode.grid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
        actions: [
          IconButton(
            tooltip: isGrid ? 'Show as list' : 'Show as grid',
            icon: Icon(
              isGrid ? Icons.view_agenda_outlined : Icons.grid_view_outlined,
            ),
            onPressed: () => ref.read(noteViewModeProvider.notifier).toggle(),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(notesControllerProvider),
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Show progress while refreshing, even when old notes are on screen.
          if (notesAsync.isLoading && notesAsync.hasValue)
            const LinearProgressIndicator(),
          Expanded(
            child: notesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _MessageState(
                icon: Icons.cloud_off_outlined,
                title: 'Could not load notes',
                message: error.toString(),
                actionLabel: 'Retry',
                onAction: () => ref.invalidate(notesControllerProvider),
              ),
              data: (notes) {
                if (notes.isEmpty) {
                  return const _MessageState(
                    icon: Icons.note_add_outlined,
                    title: 'No notes yet',
                    message: 'Notes you create will appear here.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    try {
                      ref.invalidate(notesControllerProvider);
                      await ref.read(notesControllerProvider.future);
                    } catch (_) {
                      // The error state is shown by notesAsync.when.
                    }
                  },
                  child: NotesView(notes: notes, mode: mode),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
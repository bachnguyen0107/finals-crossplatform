import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/application/auth_providers.dart';
import '../../labels/application/labels_providers.dart';
import '../application/note_view_mode.dart';
import '../application/notes_providers.dart';
import 'widgets/notes_view.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedLabelId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesControllerProvider);
    final labelsAsync = ref.watch(labelsControllerProvider);
    final noteLabelLinks =
        ref.watch(allNoteLabelLinksProvider).value ??
        const <String, Set<String>>{};
    final mode = ref.watch(noteViewModeProvider);
    final isGrid = mode == NoteViewMode.grid;
    final labels = labelsAsync.value ?? const [];
    final offline = ref.watch(notesOfflineProvider);
    final pendingCount = ref.watch(notesPendingCountProvider);

    ref.listen<int>(notesConflictCopiesProvider, (previous, count) {
      if (count == 0) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count == 1
                ? 'A note was changed on another device. '
                      'Your offline version was saved as a copy.'
                : '$count notes were changed on another device. '
                      'Your offline versions were saved as copies.',
          ),
        ),
      );
      ref.read(notesConflictCopiesProvider.notifier).set(0);
    });

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
            onPressed: () {
              ref.invalidate(notesControllerProvider);
              ref.invalidate(labelsControllerProvider);
              ref.invalidate(allNoteLabelLinksProvider);
            },
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/notes/new'),
        icon: const Icon(Icons.add),
        label: const Text('New note'),
      ),
      body: Column(
        children: [
          // Show progress while refreshing, even when old notes are on screen.
          if (offline || pendingCount > 0)
            _SyncBanner(offline: offline, pendingCount: pendingCount),
          if (notesAsync.isLoading && notesAsync.hasValue)
            const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search notes...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          if (labels.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                itemCount: labels.length + 1,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return ChoiceChip(
                      label: const Text('All'),
                      selected: _selectedLabelId == null,
                      onSelected: (_) =>
                          setState(() => _selectedLabelId = null),
                    );
                  }
                  final label = labels[index - 1];
                  return ChoiceChip(
                    label: Text(label.name),
                    selected: _selectedLabelId == label.id,
                    onSelected: (_) => setState(() {
                      _selectedLabelId = _selectedLabelId == label.id
                          ? null
                          : label.id;
                    }),
                  );
                },
              ),
            ),
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
                    message: 'Tap "New note" to create your first note.',
                  );
                }

                final normalizedQuery = _searchQuery.trim().toLowerCase();
                final filteredNotes = notes.where((note) {
                  final matchesQuery =
                      normalizedQuery.isEmpty ||
                      note.title.toLowerCase().contains(normalizedQuery) ||
                      note.content.toLowerCase().contains(normalizedQuery);
                  if (!matchesQuery) return false;

                  final selectedLabel = _selectedLabelId;
                  if (selectedLabel == null) return true;
                  final noteLabels =
                      noteLabelLinks[note.id] ?? const <String>{};
                  return noteLabels.contains(selectedLabel);
                }).toList();

                if (filteredNotes.isEmpty) {
                  return const _MessageState(
                    icon: Icons.search_off_outlined,
                    title: 'No matching notes',
                    message: 'Try a different keyword or label filter.',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    try {
                      ref.invalidate(notesControllerProvider);
                      ref.invalidate(labelsControllerProvider);
                      ref.invalidate(allNoteLabelLinksProvider);
                      await ref.read(notesControllerProvider.future);
                    } catch (_) {
                      // The error state is shown by notesAsync.when.
                    }
                  },
                  child: NotesView(
                    notes: filteredNotes,
                    mode: mode,
                    onOpen: (note) => context.push('/notes/${note.id}'),
                  ),
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
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.offline, required this.pendingCount});

  final bool offline;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final changes = pendingCount == 1 ? '1 change' : '$pendingCount changes';
    final String message;
    if (!offline) {
      message = 'Syncing $changes...';
    } else if (pendingCount == 0) {
      message = 'You are offline. Showing notes saved on this device.';
    } else {
      message = 'You are offline. $changes will sync when you are back online.';
    }
    return Semantics(
      liveRegion: true,
      child: Material(
        color: scheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                offline ? Icons.cloud_off_outlined : Icons.cloud_upload_outlined,
                size: 18,
                color: scheme.onSecondaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: scheme.onSecondaryContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

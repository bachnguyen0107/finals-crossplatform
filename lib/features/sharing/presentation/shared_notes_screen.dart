import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/sharing_providers.dart';

class SharedNotesScreen extends ConsumerWidget {
  const SharedNotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sharedNotesAsync = ref.watch(sharedWithMeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shared'),
      ),
      body: sharedNotesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 12),
                Text(
                  'Failed to load shared notes.\n$error',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(sharedWithMeProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(sharedWithMeProvider);
                await ref.read(sharedWithMeProvider.future);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 160),
                  Center(
                    child: Text('No notes have been shared with you yet'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(sharedWithMeProvider);
              await ref.read(sharedWithMeProvider.future);
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                final rawTitle = item.title.trim();
                final displayTitle = rawTitle.isEmpty ? 'Untitled' : rawTitle;
                final sharerText = item.sharerEmail.trim().isNotEmpty
                    ? item.sharerEmail.trim()
                    : (item.sharerDisplayName.trim().isNotEmpty
                        ? item.sharerDisplayName.trim()
                        : 'Unknown sender');
                final updatedText = _formatTimestamp(item.updatedAt);

                return ListTile(
                  leading: Icon(
                    item.isLocked ? Icons.lock : Icons.description_outlined,
                  ),
                  title: Text(
                    displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      Text(
                        'Shared by $sharerText',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Updated $updatedText',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  trailing: Chip(
                    label: Text(item.permission.label),
                    visualDensity: VisualDensity.compact,
                  ),
                  isThreeLine: true,
                  onTap: () => context.push('/notes/${item.noteId}'),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
}
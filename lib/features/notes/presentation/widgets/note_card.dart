import 'package:flutter/material.dart';

import '../../domain/note.dart';

class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    this.compact = false,
    this.onTap,
  });

  final Note note;

  /// true in list view: the card sizes to its content.
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = note.title.trim().isEmpty ? 'Untitled' : note.title.trim();
    // Never show the content of a locked note in the list.
    final preview = note.isLocked ? 'Locked note' : note.content.trim();

    final previewText = Text(
      preview,
      maxLines: compact ? 2 : 6,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontStyle: note.isLocked ? FontStyle.italic : null,
      ),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  NoteStatusIcons(note: note),
                ],
              ),
              const SizedBox(height: 6),
              if (compact) previewText else Expanded(child: previewText),
              const SizedBox(height: 8),
              Text(
                formatNoteDate(note.updatedAt),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Status indicators. A note can show several at once.
/// The shared indicator is added when sharing is implemented.
class NoteStatusIcons extends StatelessWidget {
  const NoteStatusIcons({super.key, required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (note.isPinned)
          Tooltip(
            message: 'Pinned',
            child: Icon(Icons.push_pin, size: 18, color: color),
          ),
        if (note.isLocked)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Tooltip(
              message: 'Locked',
              child: Icon(Icons.lock, size: 18, color: color),
            ),
          ),
      ],
    );
  }
}

String formatNoteDate(DateTime time) {
  final t = time.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(t.day)}/${two(t.month)}/${t.year} ${two(t.hour)}:${two(t.minute)}';
}
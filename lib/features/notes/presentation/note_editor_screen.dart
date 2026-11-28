import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../attachments/presentation/note_attachments_section.dart';
import '../../labels/application/labels_providers.dart';
import '../../sharing/application/sharing_providers.dart';
import '../../sharing/domain/share_models.dart';
import '../../sharing/presentation/share_note_dialog.dart';
import '../application/auto_saver.dart';
import '../application/notes_providers.dart';
import '../domain/note.dart';
import 'widgets/delete_note_dialog.dart';
import 'widgets/save_status_indicator.dart';

/// One screen for both creating and editing a note.
class NoteEditorScreen extends ConsumerWidget {
  const NoteEditorScreen({super.key, this.noteId});

  final String? noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = noteId;
    if (id == null) return const _NoteEditorForm();

    return ref
        .watch(noteByIdProvider(id))
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, _) => Scaffold(
            appBar: AppBar(
              leading: IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _leave(context),
              ),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(error.toString(), textAlign: TextAlign.center),
              ),
            ),
          ),
          data: (note) => _NoteEditorForm(note: note),
        );
  }
}

void _leave(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/home');
  }
}

class _NoteEditorForm extends ConsumerStatefulWidget {
  const _NoteEditorForm({this.note});

  final Note? note;

  @override
  ConsumerState<_NoteEditorForm> createState() => _NoteEditorFormState();
}

class _NoteEditorFormState extends ConsumerState<_NoteEditorForm> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final NotesController _notes;
  late final AutoSaver _saver;

  String? _noteId;
  // Latest text, kept as plain strings so a save can still run
  // after the text controllers are disposed.
  String _title = '';
  String _content = '';
  SaveStatus _status = SaveStatus.idle;
  bool _closing = false;
  bool _deleted = false;
  late bool _isPinned;
  bool _pinning = false;
  bool _isReadOnly = false;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    _noteId = note?.id;
    _title = note?.title ?? '';
    _content = note?.content ?? '';
    _titleController = TextEditingController(text: _title);
    _contentController = TextEditingController(text: _content);
    _notes = ref.read(notesControllerProvider.notifier);
    _saver = AutoSaver(
      save: _save,
      onStatusChanged: (status) {
        if (mounted) setState(() => _status = status);
      },
    );
    _isPinned = note?.isPinned ?? false;
    _isReadOnly = note != null;
    // Save right away when the app is paused, hidden or closed,
    // e.g. switching browser tabs or pressing Home on Android.
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        if (state != AppLifecycleState.resumed && !_isReadOnly) {
          unawaited(_saver.flush());
        }
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    // Save the last changes when the screen goes away.
    if (!_isReadOnly) {
      unawaited(_saver.flush());
    }
    _saver.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_deleted || _isReadOnly) return;
    final title = _title.trim();
    final content = _content;
    final id = _noteId;

    if (id == null) {
      // Do not create empty notes.
      if (title.isEmpty && content.trim().isEmpty) return;
      final created = await _notes.create(title: title, content: content);
      _noteId = created.id;
      if (mounted) setState(() {}); // shows the delete button
    } else {
      await _notes.saveNote(id, title: title, content: content);
    }
  }

  void _onTitleChanged(String value) {
    if (_isReadOnly) return;
    _title = value;
    _saver.markChanged();
  }

  void _onContentChanged(String value) {
    if (_isReadOnly) return;
    _content = value;
    _saver.markChanged();
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    if (_isReadOnly) {
      _leave(context);
      return;
    }

    await _saver.flush();
    if (!mounted) return;

    if (_saver.status == SaveStatus.failed) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Changes not saved'),
          content: const Text(
            'Your latest changes could not be saved. Leave anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Stay'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Leave'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (leave != true) {
        _closing = false;
        return;
      }
    }
    _leave(context);
  }

  Future<void> _openShareDialog() async {
    final id = _noteId;
    if (id == null) return;
    final currentTitle = _title.trim().isEmpty ? 'Untitled' : _title.trim();
    await showDialog<void>(
      context: context,
      builder: (_) => ShareNoteDialog(
        noteId: id,
        noteTitle: currentTitle,
      ),
    );
  }

  Future<void> _togglePin() async {
    if (_pinning) return;
    // Make sure the note exists on the server before pinning it.
    await _saver.flush();
    final id = _noteId;
    if (id == null || !mounted) return;

    setState(() => _pinning = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final updated = await _notes.setPinned(id, pinned: !_isPinned);
      if (mounted) setState(() => _isPinned = updated.isPinned);
      messenger.showSnackBar(
        SnackBar(
          content: Text(updated.isPinned ? 'Note pinned' : 'Note unpinned'),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _pinning = false);
    }
  }

  Future<void> _delete() async {
    final id = _noteId;
    if (id == null) return;
    final title = _title.trim().isEmpty ? 'Untitled' : _title.trim();

    final confirmed = await confirmDeleteNote(context, title: title);
    if (!confirmed || !mounted) return;

    _deleted = true; // stop auto-save for this note
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _notes.delete(id);
    } catch (error) {
      _deleted = false;
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
      return;
    }
    if (!mounted) return;
    _closing = true;
    _leave(context);
    messenger.showSnackBar(const SnackBar(content: Text('Note deleted')));
  }

  NoteAccess _resolveAccess() {
    final note = widget.note;
    if (note == null) return NoteAccess.owner;
    final accessAsync = ref.watch(
      noteAccessProvider((noteId: note.id, ownerId: note.ownerId)),
    );
    return accessAsync.when(
      data: (access) => access,
      loading: () => NoteAccess.read,
      error: (_, _) => NoteAccess.read,
    );
  }

  @override
  Widget build(BuildContext context) {
    final locked = widget.note?.isLocked ?? false;
    final access = _resolveAccess();
    final isOwner = access == NoteAccess.owner;
    final isReadOnly = access == NoteAccess.read;
    _isReadOnly = isReadOnly;

    return PopScope(
      // Handle system/browser back ourselves so pending changes are saved.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back),
            onPressed: _close,
          ),
          title: isReadOnly
              ? const Chip(
                  label: Text('View only'),
                  visualDensity: VisualDensity.compact,
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SaveStatusIndicator(
                      status: _status,
                      onRetry: () => _saver.flush(),
                    ),
                    if (access == NoteAccess.edit) ...[
                      const SizedBox(width: 8),
                      const Chip(
                        label: Text('Shared with you'),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ],
                ),
          actions: [
            if (isOwner && _noteId != null && !locked)
              IconButton(
                tooltip: 'Share note',
                icon: const Icon(Icons.share_outlined),
                onPressed: _openShareDialog,
              ),
            if (isOwner && _noteId != null && !locked)
              IconButton(
                tooltip: _isPinned ? 'Unpin note' : 'Pin note',
                icon: Icon(
                  _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                ),
                onPressed: _pinning ? null : _togglePin,
              ),
            if (isOwner && _noteId != null)
              IconButton(
                tooltip: 'Delete note',
                icon: const Icon(Icons.delete_outline),
                onPressed: _delete,
              ),
          ],
        ),
        body: locked ? const _LockedMessage() : _buildFields(context, access),
      ),
    );
  }

  Widget _buildFields(BuildContext context, NoteAccess access) {
    final theme = Theme.of(context);
    final savedNoteId = _noteId;
    final isOwner = access == NoteAccess.owner;
    final isReadOnly = access == NoteAccess.read;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            children: [
              TextField(
                controller: _titleController,
                readOnly: isReadOnly,
                autofocus: widget.note == null && !isReadOnly,
                textInputAction: TextInputAction.next,
                style: theme.textTheme.headlineSmall,
                decoration: const InputDecoration(
                  hintText: 'Title',
                  border: InputBorder.none,
                ),
                onChanged: _onTitleChanged,
              ),
              const Divider(height: 1),
              Expanded(
                child: TextField(
                  controller: _contentController,
                  readOnly: isReadOnly,
                  expands: true,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    hintText: 'Start typing your note...',
                    border: InputBorder.none,
                  ),
                  onChanged: _onContentChanged,
                ),
              ),
              if (savedNoteId != null) ...[
                if (isOwner) _NoteLabelsSelector(noteId: savedNoteId),
                NoteAttachmentsSection(
                  noteId: savedNoteId,
                  readOnly: isReadOnly,
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Save the note first to add files',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteLabelsSelector extends ConsumerWidget {
  const _NoteLabelsSelector({required this.noteId});

  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allLabelsAsync = ref.watch(labelsControllerProvider);
    final attachedIdsAsync = ref.watch(noteLabelIdsProvider(noteId));
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 20),
        Text('Labels', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        allLabelsAsync.when(
          loading: () => const SizedBox(
            height: 32,
            child: Align(
              alignment: Alignment.centerLeft,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (err, _) => Text(
            'Could not load labels: $err',
            style: TextStyle(color: theme.colorScheme.error),
          ),
          data: (labels) {
            if (labels.isEmpty) {
              return Text(
                'No labels created yet.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              );
            }

            final attachedIds = attachedIdsAsync.value ?? const <String>{};

            return Wrap(
              spacing: 8,
              runSpacing: 6,
              children: labels.map<Widget>((label) {
                final selected = attachedIds.contains(label.id);
                return FilterChip(
                  label: Text(label.name),
                  selected: selected,
                  onSelected: (_) async {
                    try {
                      await ref
                          .read(noteLabelIdsProvider(noteId).notifier)
                          .toggleLabel(label.id);
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(SnackBar(content: Text('$e')));
                    }
                  },
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _LockedMessage extends StatelessWidget {
  const _LockedMessage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 48),
            SizedBox(height: 12),
            Text('This note is locked.', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../attachments/presentation/note_attachments_section.dart';
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

    return ref.watch(noteByIdProvider(id)).when(
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
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
  }

  @override
  void dispose() {
    // Save the last changes when the screen goes away.
    unawaited(_saver.flush());
    _saver.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_deleted) return;
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
    _title = value;
    _saver.markChanged();
  }

  void _onContentChanged(String value) {
    _content = value;
    _saver.markChanged();
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
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

  @override
  Widget build(BuildContext context) {
    final locked = widget.note?.isLocked ?? false;

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
          title: SaveStatusIndicator(
            status: _status,
            onRetry: () => _saver.flush(),
          ),
          actions: [
            if (_noteId != null)
              IconButton(
                tooltip: 'Delete note',
                icon: const Icon(Icons.delete_outline),
                onPressed: _delete,
              ),
          ],
        ),
        body: locked ? const _LockedMessage() : _buildFields(context),
      ),
    );
  }

  Widget _buildFields(BuildContext context) {
    final theme = Theme.of(context);
    final savedNoteId = _noteId;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            children: [
              TextField(
                controller: _titleController,
                autofocus: widget.note == null,
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
              if (savedNoteId != null)
                NoteAttachmentsSection(noteId: savedNoteId)
              else
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
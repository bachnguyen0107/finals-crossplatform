import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/local_database.dart';
import '../../auth/application/auth_providers.dart';
import '../data/notes_local_store.dart';
import '../data/notes_repository.dart';
import '../domain/note.dart';

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  return NotesRepository(ref.watch(supabaseClientProvider));
});

// Current user id (null when logged out).
final notesUserIdProvider = Provider<String?>((ref) {
  return ref.watch(currentUserProvider.select((user) => user?.id));
});

// One local database per account, closed on logout or account switch.
final notesLocalStoreProvider = FutureProvider.autoDispose<NotesLocalStore?>((
  ref,
) async {
  final userId = ref.watch(notesUserIdProvider);
  if (userId == null) return null;
  final db = await openLocalDatabase('notes_$userId.db');
  ref.onDispose(db.close);
  return NotesLocalStore(db);
});

// True when the list comes from the local cache instead of the server.
final notesOfflineProvider = NotifierProvider<NotesOfflineController, bool>(
  NotesOfflineController.new,
);

class NotesOfflineController extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool offline) => state = offline;
}

// Offline changes still waiting to be sent to the server.
final notesPendingCountProvider = NotifierProvider<NotesCounter, int>(
  NotesCounter.new,
);

// Conflict copies made by the last sync. Home shows a message, then resets it.
final notesConflictCopiesProvider = NotifierProvider<NotesCounter, int>(
  NotesCounter.new,
);

class NotesCounter extends Notifier<int> {
  @override
  int build() => 0;

  void set(int value) => state = value;
}

final notesControllerProvider =
    AsyncNotifierProvider<NotesController, List<Note>>(
      NotesController.new,
      // No auto retry, the user can tap Retry instead.
      retry: (retryCount, error) => null,
    );

final noteByIdProvider = FutureProvider.autoDispose.family<Note, String>((
  ref,
  id,
) async {
  final loaded = ref.read(notesControllerProvider).value ?? const <Note>[];
  for (final note in loaded) {
    if (note.id == id) return note;
  }
  try {
    return await ref.read(notesRepositoryProvider).fetchNote(id);
  } on NotesFailure {
    // Offline: try the local copy.
    final local = await ref.read(notesLocalStoreProvider.future);
    final cached = await local?.get(id);
    if (cached != null) return cached;
    rethrow;
  }
});

class NotesController extends AsyncNotifier<List<Note>> {
  // How long to wait before trying the server again while offline.
  static const retryDelay = Duration(seconds: 20);

  NotesRepository get _repository => ref.read(notesRepositoryProvider);
  NotesLocalStore? _local;
  Timer? _retryTimer;

  @override
  Future<List<Note>> build() async {
    // Rebuilds when the user changes, so accounts don't mix.
    final userId = ref.watch(notesUserIdProvider);
    final repository = ref.watch(notesRepositoryProvider);
    ref.onDispose(() => _retryTimer?.cancel());
    if (userId == null) {
      _local = null;
      return const [];
    }

    final local = await ref.watch(notesLocalStoreProvider.future);
    _local = local;

    try {
      if (local != null) await _syncPending(repository, local);
      final notes = await repository.fetchNotes();
      await local?.replaceAll(notes);
      _setOffline(false);
      return notes;
    } on NotesFailure {
      // Can't reach the server, fall back to cached notes.
      final cached = await local?.getAll() ?? const <Note>[];
      if (cached.isEmpty) rethrow;
      _setOffline(true);
      _scheduleRetry();
      return sortNotes(cached);
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<Note> create({required String title, String content = ''}) async {
    try {
      final note = await _repository.createNote(title: title, content: content);
      _replace(note);
      return note;
    } on NotesFailure catch (e) {
      final local = _local;
      final userId = ref.read(notesUserIdProvider);
      if (!e.isNetwork || local == null || userId == null) rethrow;
      // Offline: the note gets its id now and is sent to the server later.
      final now = DateTime.now().toUtc();
      final note = Note(
        id: const Uuid().v4(),
        ownerId: userId,
        title: title,
        content: content,
        isPinned: false,
        pinnedAt: null,
        isLocked: false,
        version: 1,
        createdAt: now,
        updatedAt: now,
      );
      await local.queueCreate(note);
      _setOffline(true);
      await _keepOnDevice(local, note);
      return note;
    }
  }

  Future<Note> saveNote(
    String id, {
    required String title,
    required String content,
  }) async {
    final local = _local;
    // A note with changes still waiting keeps saving on the device until
    // they are synced, so the edits reach the server in order.
    if (local != null && await local.pendingFor(id) != null) {
      return _saveOnDevice(local, id, title: title, content: content);
    }
    try {
      final updated = await _repository.updateNote(
        id,
        title: title,
        content: content,
      );
      _replace(updated);
      return updated;
    } on NotesFailure catch (e) {
      if (!e.isNetwork || local == null) rethrow;
      _setOffline(true);
      return _saveOnDevice(local, id, title: title, content: content);
    }
  }

  Future<Note> setPinned(String id, {required bool pinned}) async {
    final updated = await _repository.setPinned(id, pinned: pinned);
    _replace(updated);
    return updated;
  }

  Future<void> togglePin(Note note) async {
    final updated = await _repository.setPinned(
      note.id,
      pinned: !note.isPinned,
    );
    _replace(updated);
  }

  Future<void> delete(String id) async {
    final local = _local;
    if (local != null && await local.pendingFor(id) != null) {
      await local.queueDelete(id);
    } else {
      try {
        await _repository.deleteNote(id);
      } on NotesFailure catch (e) {
        if (!e.isNetwork || local == null) rethrow;
        await local.queueDelete(id);
        _setOffline(true);
        _scheduleRetry();
      }
    }
    if (local != null) {
      await local.delete(id);
      await _updatePendingCount(local);
    }
    final current = state.value ?? const <Note>[];
    state = AsyncData(current.where((n) => n.id != id).toList());
  }

  Future<Note> _saveOnDevice(
    NotesLocalStore local,
    String id, {
    required String title,
    required String content,
  }) async {
    final current =
        state.value?.where((n) => n.id == id).firstOrNull ??
        await local.get(id);
    if (current == null) {
      throw const NotesFailure('This note is not saved on this device.');
    }
    if (current.isLocked) {
      throw const NotesFailure('Locked notes can only be edited online.');
    }
    if (current.ownerId != ref.read(notesUserIdProvider)) {
      throw const NotesFailure('Shared notes can only be edited online.');
    }
    final updated = current.copyWith(
      title: title,
      content: content,
      updatedAt: DateTime.now().toUtc(),
    );
    await local.queueUpdate(updated);
    await _keepOnDevice(local, updated);
    return updated;
  }

  // Save the change locally, update the list, and retry later.
  Future<void> _keepOnDevice(NotesLocalStore local, Note note) async {
    await local.upsert(note);
    await _updatePendingCount(local);
    _scheduleRetry();
    final current = state.value ?? const <Note>[];
    final others = current.where((n) => n.id != note.id);
    state = AsyncData(sortNotes([...others, note]));
  }

  // Sends offline changes to the server, oldest first. A network error
  // stops it and the rest waits for the next try.
  Future<void> _syncPending(
    NotesRepository repository,
    NotesLocalStore local,
  ) async {
    var conflicts = 0;
    try {
      for (final change in await local.pendingChanges()) {
        switch (change.kind) {
          case PendingKind.create:
            await _skipServerErrors(
              () => repository.createNote(
                id: change.noteId,
                title: change.title,
                content: change.content,
              ),
            );
          case PendingKind.update:
            Note? saved;
            await _skipServerErrors(() async {
              saved = await repository.updateNoteIfVersion(
                change.noteId,
                title: change.title,
                content: change.content,
                baseVersion: change.baseVersion,
              );
            });
            if (saved == null) {
              final title = change.title.isEmpty ? 'Untitled' : change.title;
              await repository.createNote(
                title: '$title (conflict copy)',
                content: change.content,
              );
              conflicts++;
            }
          case PendingKind.delete:
            await _skipServerErrors(() => repository.deleteNote(change.noteId));
        }
        await local.removePending(change.noteId);
      }
    } finally {
      await _updatePendingCount(local);
      if (conflicts > 0 && ref.mounted) {
        ref.read(notesConflictCopiesProvider.notifier).set(conflicts);
      }
    }
  }

  Future<void> _skipServerErrors(Future<void> Function() action) async {
    try {
      await action();
    } on NotesFailure catch (e) {
      if (e.isNetwork) rethrow;
    }
  }

  // Try the server again in a bit
  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(retryDelay, () {
      if (ref.mounted) ref.invalidateSelf();
    });
  }

  Future<void> _updatePendingCount(NotesLocalStore local) async {
    final count = await local.pendingCount();
    if (ref.mounted) ref.read(notesPendingCountProvider.notifier).set(count);
  }

  // Update the list and the local cache after a successful server write.
  void _replace(Note note) {
    if (note.ownerId != ref.read(notesUserIdProvider)) {
      _setOffline(false);
      return;
    }
    final local = _local;
    if (local != null) unawaited(local.upsert(note));
    _setOffline(false);
    final current = state.value ?? const <Note>[];
    final others = current.where((n) => n.id != note.id);
    state = AsyncData(sortNotes([...others, note]));
  }

  void _setOffline(bool offline) {
    if (ref.mounted) ref.read(notesOfflineProvider.notifier).set(offline);
  }
}
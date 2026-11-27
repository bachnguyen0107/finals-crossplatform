import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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
final notesLocalStoreProvider =
    FutureProvider.autoDispose<NotesLocalStore?>((ref) async {
  final userId = ref.watch(notesUserIdProvider);
  if (userId == null) return null;
  final db = await openLocalDatabase('notes_$userId.db');
  ref.onDispose(db.close);
  return NotesLocalStore(db);
});

// True when the list comes from the local cache instead of the server.
final notesOfflineProvider =
    NotifierProvider<NotesOfflineController, bool>(NotesOfflineController.new);

class NotesOfflineController extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool offline) => state = offline;
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
  NotesRepository get _repository => ref.read(notesRepositoryProvider);
  NotesLocalStore? _local;

  @override
  Future<List<Note>> build() async {
    final userId = ref.watch(notesUserIdProvider);
    final repository = ref.watch(notesRepositoryProvider);
    if (userId == null) {
      _local = null;
      return const [];
    }

    final local = await ref.watch(notesLocalStoreProvider.future);
    _local = local;

    try {
      final notes = await repository.fetchNotes();
      await local?.replaceAll(notes);
      _setOffline(false);
      return notes;
    } on NotesFailure {
      // Can't reach the server, fall back to cached notes.
      final cached = await local?.getAll() ?? const <Note>[];
      if (cached.isEmpty) rethrow;
      _setOffline(true);
      return sortNotes(cached);
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<Note> create({required String title, String content = ''}) async {
    final note = await _repository.createNote(title: title, content: content);
    _replace(note);
    return note;
  }

  Future<Note> saveNote(
    String id, {
    required String title,
    required String content,
  }) async {
    final updated = await _repository.updateNote(
      id,
      title: title,
      content: content,
    );
    _replace(updated);
    return updated;
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
    await _repository.deleteNote(id);
    final local = _local;
    if (local != null) unawaited(local.delete(id));
    final current = state.value ?? const <Note>[];
    state = AsyncData(current.where((n) => n.id != id).toList());
  }

  // Update the list and the local cache after a successful server write.
  void _replace(Note note) {
    final local = _local;
    if (local != null) unawaited(local.upsert(note));
    _setOffline(false);
    final current = state.value ?? const <Note>[];
    final others = current.where((n) => n.id != note.id);
    state = AsyncData(sortNotes([...others, note]));
  }

  void _setOffline(bool offline) {
    ref.read(notesOfflineProvider.notifier).set(offline);
  }
}
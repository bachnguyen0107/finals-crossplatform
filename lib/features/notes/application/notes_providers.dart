import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/notes_repository.dart';
import '../domain/note.dart';

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  return NotesRepository(ref.watch(supabaseClientProvider));
});

final notesControllerProvider =
    AsyncNotifierProvider<NotesController, List<Note>>(
  NotesController.new,
  // Show errors right away; the user can press Retry.
  retry: (retryCount, error) => null,
);

class NotesController extends AsyncNotifier<List<Note>> {
  NotesRepository get _repository => ref.read(notesRepositoryProvider);

  @override
  Future<List<Note>> build() {
    // Reload when a different user logs in, so accounts never share notes.
    final userId = ref.watch(currentUserProvider.select((user) => user?.id));
    if (userId == null) return Future.value(const []);
    return ref.watch(notesRepositoryProvider).fetchNotes();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repository.fetchNotes);
  }

  Future<Note> create({required String title, String content = ''}) async {
    final note = await _repository.createNote(title: title, content: content);
    _replace(note);
    return note;
  }

  Future<void> togglePin(Note note) async {
    final updated = await _repository.setPinned(note.id, pinned: !note.isPinned);
    _replace(updated);
  }

  Future<void> delete(String id) async {
    await _repository.deleteNote(id);
    final current = state.value ?? const <Note>[];
    state = AsyncData(current.where((n) => n.id != id).toList());
  }

  void _replace(Note note) {
    final current = state.value ?? const <Note>[];
    final others = current.where((n) => n.id != note.id);
    state = AsyncData(sortNotes([...others, note]));
  }
}
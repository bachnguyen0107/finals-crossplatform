import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/labels_repository.dart';
import '../domain/label.dart';

final labelsRepositoryProvider = Provider<LabelsRepository>((ref) {
  return LabelsRepository(ref.watch(supabaseClientProvider));
});

final labelsControllerProvider =
    AsyncNotifierProvider<LabelsController, List<Label>>(LabelsController.new);

final allNoteLabelLinksProvider =
    FutureProvider.autoDispose<Map<String, Set<String>>>((ref) async {
  final userId = ref.watch(currentUserProvider.select((user) => user?.id));
  if (userId == null) return const <String, Set<String>>{};
  return ref.watch(labelsRepositoryProvider).fetchAllNoteLabelLinks();
});

final noteLabelIdsProvider = AsyncNotifierProvider.family<
    NoteLabelIdsController, Set<String>, String>(
  NoteLabelIdsController.new,
);

class NoteLabelIdsController extends AsyncNotifier<Set<String>> {
  NoteLabelIdsController(this.noteId);

  final String noteId;

  LabelsRepository get _repository => ref.read(labelsRepositoryProvider);

  @override
  Future<Set<String>> build() {
    final userId = ref.watch(currentUserProvider.select((user) => user?.id));
    if (userId == null) return Future.value(<String>{});
    return _repository.fetchLabelIdsForNote(noteId);
  }

  Future<void> toggleLabel(String labelId) async {
    final current = Set<String>.from(state.value ?? const <String>{});
    final willAttach = !current.contains(labelId);

    await _repository.setLabelAttached(
      noteId: noteId,
      labelId: labelId,
      attached: willAttach,
    );

    if (willAttach) {
      current.add(labelId);
    } else {
      current.remove(labelId);
    }
    state = AsyncData(current);
    ref.invalidate(allNoteLabelLinksProvider);
  }
}

class LabelsController extends AsyncNotifier<List<Label>> {
  LabelsRepository get _repository => ref.read(labelsRepositoryProvider);

  @override
  Future<List<Label>> build() {
    final userId = ref.watch(currentUserProvider.select((user) => user?.id));
    if (userId == null) return Future.value(const []);
    return ref.watch(labelsRepositoryProvider).fetchLabels();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repository.fetchLabels);
  }

  Future<Label> create({required String name}) async {
    final label = await _repository.createLabel(name: name);
    _refetch();
    return label;
  }

  Future<Label> rename({required String id, required String name}) async {
    final label = await _repository.renameLabel(id: id, name: name);
    _refetch();
    return label;
  }

  Future<void> delete(String id) async {
    await _repository.deleteLabel(id);
    final current = state.value ?? const <Label>[];
    state = AsyncData(current.where((l) => l.id != id).toList());
    ref.invalidate(allNoteLabelLinksProvider);
  }

  void _refetch() async {
    final labels = await _repository.fetchLabels();
    state = AsyncData(labels);
  }
}
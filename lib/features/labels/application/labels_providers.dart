import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/labels_repository.dart';
import '../domain/label.dart';

final labelsRepositoryProvider = Provider<LabelsRepository>((ref) {
  return LabelsRepository(ref.watch(supabaseClientProvider));
});

final labelsControllerProvider =
    AsyncNotifierProvider<LabelsController, List<Label>>(LabelsController.new);

class LabelsController extends AsyncNotifier<List<Label>> {
  LabelsRepository get _repository => ref.read(labelsRepositoryProvider);

  @override
  Future<List<Label>> build() {
    // Reload when a different user logs in.
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
  }

  void _refetch() async {
    final labels = await _repository.fetchLabels();
    state = AsyncData(labels);
  }
}
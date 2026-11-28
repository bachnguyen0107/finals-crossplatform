import 'package:finals/features/ai/data/ai_repository.dart';
import 'package:finals/features/auth/application/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepository(ref.watch(supabaseClientProvider));
});

final noteSummaryProvider =
    FutureProvider.autoDispose.family<String, String>(
  (ref, noteId) => ref.watch(aiRepositoryProvider).summarize(noteId),
);
import 'package:finals/features/auth/application/auth_providers.dart';
import 'package:finals/features/note_lock/data/note_lock_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final noteLockRepositoryProvider = Provider<NoteLockRepository>((ref) {
  return NoteLockRepository(ref.watch(supabaseClientProvider));
});
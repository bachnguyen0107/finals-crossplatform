import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AuthRepository(client);
});

final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.authStateChanges();
});

final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  return authState.maybeWhen(
    data: (state) => state.session?.user,
    orElse: () => ref.watch(authRepositoryProvider).currentUser,
  );
});

final isEmailVerifiedProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return false;
  }
  return user.emailConfirmedAt != null;
});

class PasswordRecoveryInProgressNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void start() => state = true;

  void reset() => state = false;
}

final passwordRecoveryInProgressProvider =
    NotifierProvider<PasswordRecoveryInProgressNotifier, bool>(
  PasswordRecoveryInProgressNotifier.new,
);
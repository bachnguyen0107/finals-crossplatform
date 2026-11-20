import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_providers.dart';
import '../features/auth/presentation/change_password_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/labels/presentation/labels_screen.dart';
import '../features/notes/presentation/home_screen.dart';
import '../features/notes/presentation/note_editor_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import 'app_shell.dart';

const publicRoutes = <String>[
  '/login',
  '/register',
  '/forgot-password',
];

class _AuthStreamListenable extends ChangeNotifier {
  _AuthStreamListenable(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  void trigger() => notifyListeners();

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  final refreshListenable = _AuthStreamListenable(
    authRepository.authStateChanges(),
  );
  ref.listen(passwordRecoveryInProgressProvider, (_, _) {
    refreshListenable.trigger();
  });
  ref.onDispose(refreshListenable.dispose);

  final router = GoRouter(
    initialLocation: '/home',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final isLoggedIn = authRepository.currentSession != null;
      final isRecoveryInProgress = ref.read(passwordRecoveryInProgressProvider);
      final isPublicRoute = publicRoutes.contains(state.matchedLocation);

      if (isLoggedIn && isRecoveryInProgress) {
        return state.matchedLocation == '/forgot-password'
            ? null
            : '/forgot-password';
      }
      if (!isLoggedIn && !isPublicRoute) {
        return '/login';
      }
      if (isLoggedIn && isPublicRoute) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/settings/change-password',
        builder: (_, _) => const ChangePasswordScreen(),
      ),
      GoRoute(path: '/notes/new', builder: (_, _) => const NoteEditorScreen()),
      GoRoute(
        path: '/notes/:id',
        builder: (_, state) =>
            NoteEditorScreen(noteId: state.pathParameters['id']),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          _branch('/home', const HomeScreen()),
          _branch('/labels', const LabelsScreen()),
          _branch('/shared', const Center(child: Text('Shared notes'))),
          _branch('/settings', const SettingsScreen()),
        ],
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});

StatefulShellBranch _branch(String path, Widget screen) {
  return StatefulShellBranch(
    routes: [GoRoute(path: path, builder: (_, _) => screen)],
  );
}
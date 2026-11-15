import 'package:finals/app/app_shell.dart';
import 'package:finals/features/auth/application/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

GoRouter _buildTestRouter() {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (_, _) => const Center(child: Text('Home Content')),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/labels',
                builder: (_, _) => const Center(child: Text('Labels Content')),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/shared',
                builder: (_, _) => const Center(child: Text('Shared Content')),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (_, _) =>
                    const Center(child: Text('Settings Content')),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

void main() {
  group('UnverifiedAccountBanner in AppShell', () {
    testWidgets('shows banner when user is unverified', (tester) async {
      final router = _buildTestRouter();
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isEmailVerifiedProvider.overrideWithValue(false),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(UnverifiedAccountBanner), findsOneWidget);
      expect(
        find.text(UnverifiedAccountBanner.bannerMessage),
        findsOneWidget,
      );
    });

    testWidgets('hides banner when user is verified', (tester) async {
      final router = _buildTestRouter();
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isEmailVerifiedProvider.overrideWithValue(true),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(UnverifiedAccountBanner), findsNothing);
      expect(
        find.text(UnverifiedAccountBanner.bannerMessage),
        findsNothing,
      );
    });
  });
}
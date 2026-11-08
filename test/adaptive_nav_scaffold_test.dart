import 'package:finals/app/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpAtSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: AdaptiveNavScaffold(
        selectedIndex: 0,
        onDestinationSelected: (_) {},
        body: const Text('Body'),
      ),
    ),
  );
}

void main() {
  testWidgets('Uses bottom navigation on phones', (tester) async {
    await pumpAtSize(tester, const Size(400, 800));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('Uses a side rail on wide screens', (tester) async {
    await pumpAtSize(tester, const Size(1000, 800));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
import 'package:finals/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App opens on the login screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: NoteApp()));
    await tester.pumpAndSettle();
    expect(find.text('Login'), findsOneWidget);
  });
}
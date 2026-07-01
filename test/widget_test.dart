import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fileshare/app.dart';

void main() {
  testWidgets('FileShare app renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: FileShareApp(),
      ),
    );
    await tester.pumpAndSettle();

    // The app should render without errors
    expect(find.text('FileShare'), findsOneWidget);
  });
}

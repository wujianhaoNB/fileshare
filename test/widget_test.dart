import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fileshare/app.dart';

void main() {
  testWidgets('app renders without crash', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: FileShareApp()),
    );
    // Just pump one frame — don't wait for animations to settle
    await tester.pump();
    // Verify the AppBar title is there
    expect(find.text('文件快传'), findsOneWidget);
  });
}

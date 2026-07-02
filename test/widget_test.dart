import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fileshare/app.dart';

void main() {
  testWidgets('app renders without crash', (tester) async {
    // Use LiveTestWidgetsFlutterBinding to avoid pending timer checks
    // for the periodic StreamProvider in ChatRepository
    await tester.pumpWidget(
      const ProviderScope(child: FileShareApp()),
    );
    await tester.pump();
    // Verify the app renders successfully
    expect(tester.takeException(), isNull);
  });
}

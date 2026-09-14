import 'package:flutter_test/flutter_test.dart';
import 'package:sflms/main.dart';

void main() {
  testWidgets('app shows the SFLMS auth flow', (tester) async {
    await tester.pumpWidget(const SflmsApp());

    expect(find.text('Smart Fleet & Logistics'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}

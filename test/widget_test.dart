import 'package:flutter_test/flutter_test.dart';

import 'package:mobil_haber/app.dart';

void main() {
  testWidgets('App boots with splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MobilHaberApp());
    await tester.pump();

    expect(find.text('mobil_haber'), findsWidgets);
  });
}

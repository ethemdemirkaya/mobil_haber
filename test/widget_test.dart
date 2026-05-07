import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobil_haber/app.dart';

void main() {
  setUp(() {
    // Splash, OnboardingProvider ve PreferencesProvider SharedPreferences'tan
    // veri okuyor; mock initial values vermezsek `getInstance` hiç dönmez ve
    // splash'taki `initialized` polling sonsuza kadar tıklar.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App boots with splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MobilHaberApp());
    await tester.pump();

    expect(find.text('mobil_haber'), findsWidgets);

    // Splash 1.6 sn timer'ını ileri sarıp Onboarding'e geçişi tamamla.
    // Onboarding'in PageView animasyonları periyodik değildir → settle eder.
    await tester.pumpAndSettle(const Duration(seconds: 6));
  });
}

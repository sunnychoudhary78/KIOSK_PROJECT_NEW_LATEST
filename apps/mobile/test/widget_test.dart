import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skp_mobile/app/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('guest welcome boots with brand and sign-in', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SkpMobileApp()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.textContaining('Smart Kiosk'), findsWidgets);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.textContaining('Sign in'), findsOneWidget);
  });
}

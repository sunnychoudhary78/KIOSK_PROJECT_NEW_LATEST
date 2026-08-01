import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_mobile/app/app.dart';

void main() {
  testWidgets('mobile app boots', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SkpMobileApp()));
    expect(find.text('Sign in'), findsOneWidget);
  });
}

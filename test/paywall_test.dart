import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spacemaker/entitlement.dart';
import 'package:spacemaker/screens/paywall_screen.dart';

void main() {
  testWidgets('unconfigured store never fakes a price and ads stay available', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await Entitlement.instance.load();
    await tester.pumpWidget(const MaterialApp(home: PaywallScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Continue with ads'), findsOneWidget);
    expect(find.text('Restore purchases'), findsOneWidget);
    expect(find.text('Subscription unavailable'), findsOneWidget);
    expect(find.textContaining('\$5.99'), findsNothing);
    expect(Entitlement.instance.isPlus, isFalse);
    expect(tester.takeException(), isNull);
  });
}

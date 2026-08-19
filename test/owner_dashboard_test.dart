import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/screens/owner_dashboard_screen.dart';

void main() {
  testWidgets('OwnerDashboardScreen builds', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: OwnerDashboardScreen()));
    expect(find.byType(OwnerDashboardScreen), findsOneWidget);
  });
}

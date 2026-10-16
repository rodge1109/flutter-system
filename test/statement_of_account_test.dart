import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_project/screens/statement_of_account_screen.dart';

void main() {
  testWidgets('StatementOfAccountScreen displays PickleBook Billing Division and 815 gross / 15 fee / 800 net', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final transactions = [
      {
        'id': 101,
        'player_name': 'Test Player',
        'court_name': 'MARS VALLEY (Green Court)',
        'created_at': '2026-10-12T08:00:00.000Z',
        'preferred_date': '2026-10-12',
        'preferred_time': '8:00 PM',
        'amount': 800.0,
        'serviceFee': 15.0,
        'booking_type': 'online',
      }
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: StatementOfAccountScreen(
          venueName: 'MARS VALLEY',
          ownerEmail: 'test@example.com',
          grossEarnings: 815.0,
          totalServiceFee: 15.0,
          totalNetEarnings: 800.0,
          transactions: transactions,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify "PickleBook Billing Division" is displayed
    expect(find.text('PickleBook Billing Division'), findsWidgets);

    // 2. Verify Gross, Fee, and Net for the 800 court booking (815 gross, 15 fee, 800 net)
    expect(find.text('₱815.00'), findsWidgets);
    expect(find.text('₱15.00'), findsWidgets);
    expect(find.text('₱800.00'), findsWidgets);
  });

  testWidgets('StatementOfAccountScreen calculates online (200 -> 215/15/200) and offline/maintenance (gross 0.00, net 0.00)', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final transactions = [
      {
        'id': 201,
        'player_name': 'Player A',
        'court_name': 'MARS VALLEY (Blue Court)',
        'created_at': '2026-10-12T08:00:00.000Z',
        'preferred_date': '2026-10-12',
        'preferred_time': '7:00 PM',
        'amount': 200.0,
        'serviceFee': 15.0,
        'booking_type': 'online',
      },
      {
        'id': 202,
        'player_name': 'Offline Booking: Brenda',
        'court_name': 'MARS VALLEY (Green Court)',
        'created_at': '2026-10-12T09:00:00.000Z',
        'preferred_date': '2026-10-12',
        'preferred_time': '8:00 PM',
        'amount': 0.0,
        'serviceFee': 15.0,
        'booking_type': 'owner_block',
      },
      {
        'id': 203,
        'player_name': 'Maintenance Block',
        'court_name': 'MARS VALLEY (Green Court)',
        'created_at': '2026-10-12T10:00:00.000Z',
        'preferred_date': '2026-10-12',
        'preferred_time': '9:00 PM',
        'amount': 0.0,
        'serviceFee': 15.0,
        'booking_type': 'owner_block',
      },
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: StatementOfAccountScreen(
          venueName: 'MARS VALLEY',
          ownerEmail: 'test@example.com',
          grossEarnings: 215.0,
          totalServiceFee: 45.0,
          totalNetEarnings: 200.0,
          transactions: transactions,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify online booking (200 court rate) has gross 215, net 200
    expect(find.text('₱215.00'), findsOneWidget);
    expect(find.text('₱200.00'), findsOneWidget);

    // Verify offline booking and maintenance block have gross 0.00 and net 0.00
    expect(find.text('₱0.00'), findsWidgets);

    // Verify total net payable is ₱45.00
    expect(find.textContaining('45.00'), findsWidgets);
  });

  testWidgets('StatementOfAccountScreen PDF generation succeeds without errors', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final transactions = [
      {
        'id': 301,
        'player_name': 'Test Player',
        'court_name': 'MARS VALLEY (Green Court)',
        'created_at': '2026-10-12T08:00:00.000Z',
        'preferred_date': '2026-10-12',
        'preferred_time': '8:00 PM',
        'amount': 800.0,
        'serviceFee': 15.0,
        'booking_type': 'online',
      }
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: StatementOfAccountScreen(
          venueName: 'MARS VALLEY',
          ownerEmail: 'test@example.com',
          grossEarnings: 815.0,
          totalServiceFee: 15.0,
          totalNetEarnings: 800.0,
          transactions: transactions,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify the widget state exists and can generate PDF
    final state = tester.state(find.byType(StatementOfAccountScreen)) as dynamic;
    final pdfBytes = await state.generatePdfForTest();
    expect(pdfBytes, isNotNull);
    expect(pdfBytes.length, greaterThan(1000));
  });

  testWidgets('Maintenance Block and Offline Bookings are strictly Gross PHP 0.00 and Net PHP 0.00 even if raw amount is non-zero', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final transactions = [
      {
        'id': 1276621,
        'player_name': 'Maintenance Block',
        'court_name': 'RED GOOSE',
        'status': 'blocked',
        'created_at': '2026-10-10T07:03:00.000Z',
        'preferred_date': '2026-10-10',
        'preferred_time': '4:00 PM',
        'amount': 15.0,
        'grossAmount': 30.0,
        'serviceFee': 15.0,
      },
      {
        'id': 1276615,
        'player_name': 'Offline Booking: Chris',
        'court_name': 'RED GOOSE',
        'status': 'blocked',
        'created_at': '2026-10-10T07:02:00.000Z',
        'preferred_date': '2026-10-10',
        'preferred_time': '3:00 PM',
        'amount': 15.0,
        'grossAmount': 30.0,
        'serviceFee': 15.0,
      },
      {
        'id': 1276396,
        'player_name': 'Offline Booking: John',
        'court_name': 'RED GOOSE',
        'status': 'blocked',
        'created_at': '2026-10-10T06:57:00.000Z',
        'preferred_date': '2026-10-10',
        'preferred_time': '5:00 PM',
        'amount': 15.0,
        'grossAmount': 30.0,
        'serviceFee': 15.0,
      },
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: StatementOfAccountScreen(
          venueName: 'RED GOOSE',
          ownerEmail: 'redgoose@gmail.com',
          grossEarnings: 0.0,
          totalServiceFee: 45.0,
          totalNetEarnings: 0.0,
          transactions: transactions,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // All 3 offline/maintenance transactions must display ₱0.00 gross and ₱0.00 net
    expect(find.text('₱0.00'), findsNWidgets(7)); // 3 rows * 2 columns (gross + net) + 1 in online summary box
    expect(find.text('₱30.00'), findsNothing);

    // Verify PDF generation also works cleanly for these
    final state = tester.state(find.byType(StatementOfAccountScreen)) as dynamic;
    final pdfBytes = await state.generatePdfForTest();
    expect(pdfBytes, isNotNull);
  });

  testWidgets('StatementOfAccountScreen strips court name in parentheses like MARS VALLEY (Green Court) and displays venue name MARS VALLEY', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final transactions = [
      {
        'id': 101,
        'player_name': 'Test Player',
        'court_name': 'MARS VALLEY (Green Court)',
        'created_at': '2026-10-12T08:00:00.000Z',
        'amount': 800.0,
        'serviceFee': 15.0,
      }
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: StatementOfAccountScreen(
          venueName: 'MARS VALLEY (Green Court)',
          ownerEmail: 'mar15oporto@gmail.com',
          grossEarnings: 815.0,
          totalServiceFee: 15.0,
          totalNetEarnings: 800.0,
          transactions: transactions,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify "MARS VALLEY" is displayed as venue name / billed to
    expect(find.text('MARS VALLEY'), findsWidgets);
    expect(find.text('MARS VALLEY (Green Court)'), findsNothing);
  });

  testWidgets('StatementOfAccountScreen filters out cancelled bookings like Jeanette Francisco', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final transactions = [
      {
        'id': 1188028,
        'player_name': 'Jeanette Francisco',
        'court_name': 'AMINOVA (Red Court)',
        'status': 'cancelled',
        'created_at': '2026-10-08T11:23:00.000Z',
        'preferred_date': '2026-10-09',
        'preferred_time': '5:00 PM',
        'total_amount': 300.0,
        'serviceFee': 15.0,
      },
      {
        'id': 1188029,
        'player_name': 'Valid Player',
        'court_name': 'AMINOVA (Red Court)',
        'status': 'confirmed',
        'created_at': '2026-10-08T12:00:00.000Z',
        'preferred_date': '2026-10-09',
        'preferred_time': '6:00 PM',
        'amount': 300.0,
        'serviceFee': 15.0,
      },
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: StatementOfAccountScreen(
          venueName: 'AMINOVA',
          ownerEmail: 'aminova@gmail.com',
          grossEarnings: 315.0,
          totalServiceFee: 15.0,
          totalNetEarnings: 300.0,
          transactions: transactions,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Jeanette Francisco is cancelled, so should not appear in the statement
    expect(find.text('Jeanette Francisco'), findsNothing);
    expect(find.text('#1188028'), findsNothing);

    // Valid Player should appear
    expect(find.text('Valid Player'), findsOneWidget);
  });
}


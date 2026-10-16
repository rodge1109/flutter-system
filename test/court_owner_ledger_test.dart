import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_project/models/ledger_entry_model.dart';

void main() {
  group('LedgerEntryModel Tests', () {
    test('Correctly parses Charge entry and amounts', () {
      final json = {
        'id': 1,
        'owner_email': 'karlonezeroz@gmail.com',
        'venue_name': 'Secret Drill',
        'transaction_date': '2026-10-01',
        'particulars': 'Monthly Platform Fee',
        'type': 'charge',
        'amount': '1500.00',
        'charges': '1500.00',
        'payment': '0.00',
        'running_balance': '1500.00',
        'reference_number': 'INV-001',
        'notes': 'Regular fee',
        'created_by': 'Super Admin'
      };

      final entry = LedgerEntryModel.fromJson(json);

      expect(entry.id, 1);
      expect(entry.ownerEmail, 'karlonezeroz@gmail.com');
      expect(entry.isCharge, true);
      expect(entry.isPayment, false);
      expect(entry.amount, 1500.00);
      expect(entry.charges, 1500.00);
      expect(entry.payment, 0.0);
      expect(entry.runningBalance, 1500.00);
      expect(entry.referenceNumber, 'INV-001');
    });

    test('Correctly parses Payment entry and amounts', () {
      final json = {
        'id': 2,
        'owner_email': 'karlonezeroz@gmail.com',
        'venue_name': 'Secret Drill',
        'transaction_date': '2026-10-05',
        'particulars': 'GCash Remittance',
        'type': 'payment',
        'amount': 1000.0,
        'charges': 0.0,
        'payment': 1000.0,
        'running_balance': 500.0,
        'reference_number': 'GCASH-12345',
      };

      final entry = LedgerEntryModel.fromJson(json);

      expect(entry.id, 2);
      expect(entry.isCharge, false);
      expect(entry.isPayment, true);
      expect(entry.amount, 1000.00);
      expect(entry.charges, 0.0);
      expect(entry.payment, 1000.00);
      expect(entry.runningBalance, 500.00);
    });

    test('Chronological running balance computation logic', () {
      final rawTransactions = [
        {'type': 'charge', 'amount': 2000.0},
        {'type': 'payment', 'amount': 1500.0},
        {'type': 'charge', 'amount': 500.0},
        {'type': 'payment', 'amount': 1000.0},
      ];

      double runningBalance = 0.0;
      final balances = <double>[];

      for (var t in rawTransactions) {
        final isCharge = t['type'] == 'charge';
        final amt = t['amount'] as double;
        final chg = isCharge ? amt : 0.0;
        final pay = !isCharge ? amt : 0.0;
        runningBalance += (chg - pay);
        balances.add(runningBalance);
      }

      expect(balances, [2000.0, 500.0, 1000.0, 0.0]);
    });
  });

  group('LedgerOwnerSummary Tests', () {
    test('Parses summary JSON correctly', () {
      final json = {
        'owner_email': 'karlonezeroz@gmail.com',
        'owner_name': 'Jonathan Dadley',
        'venue_name': 'Secret Drill',
        'total_charges': '3000.00',
        'total_payments': '2500.00',
        'current_balance': '500.00',
        'total_entries': 5,
        'last_transaction_date': '2026-10-15',
      };

      final summary = LedgerOwnerSummary.fromJson(json);

      expect(summary.ownerEmail, 'karlonezeroz@gmail.com');
      expect(summary.ownerName, 'Jonathan Dadley');
      expect(summary.venueName, 'Secret Drill');
      expect(summary.totalCharges, 3000.0);
      expect(summary.totalPayments, 2500.0);
      expect(summary.currentBalance, 500.0);
      expect(summary.totalEntries, 5);
      expect(summary.lastTransactionDate, '2026-10-15');
    });
  });
}

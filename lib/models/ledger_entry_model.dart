class LedgerEntryModel {
  final int? id;
  final String ownerEmail;
  final String? venueName;
  final String transactionDate;
  final String particulars;
  final String type; // 'charge' or 'payment'
  final double amount;
  final double charges;
  final double payment;
  final double runningBalance;
  final String? referenceNumber;
  final String? notes;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  LedgerEntryModel({
    this.id,
    required this.ownerEmail,
    this.venueName,
    required this.transactionDate,
    required this.particulars,
    required this.type,
    required this.amount,
    this.charges = 0.0,
    this.payment = 0.0,
    this.runningBalance = 0.0,
    this.referenceNumber,
    this.notes,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  bool get isCharge => type.toLowerCase() == 'charge';
  bool get isPayment => type.toLowerCase() == 'payment';

  factory LedgerEntryModel.fromJson(Map<String, dynamic> json) {
    double parsedAmount = 0.0;
    if (json['amount'] != null) {
      parsedAmount = double.tryParse(json['amount'].toString()) ?? 0.0;
    }

    String entryType = (json['type'] ?? 'charge').toString().toLowerCase();
    double parsedCharges = 0.0;
    if (json['charges'] != null) {
      parsedCharges = double.tryParse(json['charges'].toString()) ?? 0.0;
    } else if (entryType == 'charge') {
      parsedCharges = parsedAmount;
    }

    double parsedPayment = 0.0;
    if (json['payment'] != null) {
      parsedPayment = double.tryParse(json['payment'].toString()) ?? 0.0;
    } else if (entryType == 'payment') {
      parsedPayment = parsedAmount;
    }

    double parsedRunningBalance = 0.0;
    if (json['running_balance'] != null) {
      parsedRunningBalance = double.tryParse(json['running_balance'].toString()) ?? 0.0;
    }

    DateTime? created;
    if (json['created_at'] != null) {
      try {
        created = DateTime.parse(json['created_at'].toString());
      } catch (_) {}
    }

    DateTime? updated;
    if (json['updated_at'] != null) {
      try {
        updated = DateTime.parse(json['updated_at'].toString());
      } catch (_) {}
    }

    return LedgerEntryModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      ownerEmail: json['owner_email']?.toString() ?? '',
      venueName: json['venue_name']?.toString(),
      transactionDate: json['transaction_date']?.toString().split('T')[0] ?? '',
      particulars: json['particulars']?.toString() ?? '',
      type: entryType,
      amount: parsedAmount,
      charges: parsedCharges,
      payment: parsedPayment,
      runningBalance: parsedRunningBalance,
      referenceNumber: json['reference_number']?.toString(),
      notes: json['notes']?.toString(),
      createdBy: json['created_by']?.toString(),
      createdAt: created,
      updatedAt: updated,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'owner_email': ownerEmail,
      if (venueName != null) 'venue_name': venueName,
      'transaction_date': transactionDate,
      'particulars': particulars,
      'type': type,
      'amount': amount,
      if (referenceNumber != null) 'reference_number': referenceNumber,
      if (notes != null) 'notes': notes,
      if (createdBy != null) 'created_by': createdBy,
    };
  }
}

class LedgerOwnerSummary {
  final String ownerEmail;
  final String ownerName;
  final String venueName;
  final double totalCharges;
  final double totalPayments;
  final double currentBalance;
  final int totalEntries;
  final String? lastTransactionDate;

  LedgerOwnerSummary({
    required this.ownerEmail,
    required this.ownerName,
    required this.venueName,
    required this.totalCharges,
    required this.totalPayments,
    required this.currentBalance,
    required this.totalEntries,
    this.lastTransactionDate,
  });

  factory LedgerOwnerSummary.fromJson(Map<String, dynamic> json) {
    return LedgerOwnerSummary(
      ownerEmail: json['owner_email']?.toString() ?? '',
      ownerName: json['owner_name']?.toString() ?? 'Court Owner',
      venueName: json['venue_name']?.toString() ?? 'Pickleball Court',
      totalCharges: double.tryParse(json['total_charges']?.toString() ?? '0') ?? 0.0,
      totalPayments: double.tryParse(json['total_payments']?.toString() ?? '0') ?? 0.0,
      currentBalance: double.tryParse(json['current_balance']?.toString() ?? '0') ?? 0.0,
      totalEntries: int.tryParse(json['total_entries']?.toString() ?? '0') ?? 0,
      lastTransactionDate: json['last_transaction_date']?.toString().split('T')[0],
    );
  }
}

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';
import '../utils/picklebook_logo.dart';
import '../utils/download_helper_stub.dart'
    if (dart.library.html) '../utils/download_helper_web.dart' as dl_helper;

class StatementOfAccountScreen extends StatefulWidget {
  final String? venueName;
  final String? ownerEmail;
  final DateTimeRange? dateRange;
  final double grossEarnings;
  final double totalServiceFee;
  final double totalNetEarnings;
  final List<dynamic> transactions;

  const StatementOfAccountScreen({
    super.key,
    this.venueName,
    this.ownerEmail,
    this.dateRange,
    required this.grossEarnings,
    required this.totalServiceFee,
    required this.totalNetEarnings,
    required this.transactions,
  });

  @override
  State<StatementOfAccountScreen> createState() => _StatementOfAccountScreenState();
}

class _StatementOfAccountScreenState extends State<StatementOfAccountScreen> {
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _selectedDateRange = widget.dateRange;
  }

  Future<void> _pickDateRange() async {
    final DateTime now = DateTime.now();
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange ?? DateTimeRange(
        start: now.subtract(const Duration(days: 30)),
        end: now,
      ),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primaryGreen,
              onPrimary: Colors.white,
              onSurface: AppColors.richBlack,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  void _clearDateRange() {
    setState(() {
      _selectedDateRange = null;
    });
  }

  List<dynamic> get _currentTransactions {
    final list = widget.transactions.where((item) {
      final tx = Map<String, dynamic>.from(item is Map ? item : {});
      final status = (tx['status'] ?? '').toString().toLowerCase().trim();
      return status != 'cancelled';
    }).toList();

    if (_selectedDateRange == null) return list;
    final start = DateTime(
      _selectedDateRange!.start.year,
      _selectedDateRange!.start.month,
      _selectedDateRange!.start.day,
      0, 0, 0,
    );
    final end = DateTime(
      _selectedDateRange!.end.year,
      _selectedDateRange!.end.month,
      _selectedDateRange!.end.day,
      23, 59, 59, 999,
    );

    return list.where((item) {
      final tx = Map<String, dynamic>.from(item is Map ? item : {});
      final dtRaw = tx['created_at'] ?? tx['preferred_date'] ?? tx['date'];
      final dt = _parseDateStandard(dtRaw);
      return !dt.isBefore(start) && !dt.isAfter(end);
    }).toList();
  }

  Map<String, double> _getTxFinancials(Map<String, dynamic> tx) {
    double fee = double.tryParse((tx['serviceFee'] ?? tx['service_fee'] ?? tx['fee'] ?? 15.0).toString()) ?? 15.0;
    if (fee <= 0) fee = 15.0;

    if (_isOfflineBooking(tx)) {
      // Offline booking or maintenance block: gross is ZERO
      return {'gross': 0.0, 'fee': fee, 'net': 0.0};
    }

    double rawGross = double.tryParse((tx['grossAmount'] ?? tx['gross_amount'] ?? 0).toString()) ?? 0.0;
    double rawNet = double.tryParse((tx['netEarnings'] ?? tx['net_amount'] ?? tx['court_net'] ?? 0).toString()) ?? 0.0;
    double rawBase = double.tryParse((tx['amount'] ?? tx['total_amount'] ?? 0).toString()) ?? 0.0;

    double gross;
    double net;

    if (rawGross > 0 && rawBase > 0 && rawGross > rawBase && (rawGross - fee) == rawBase) {
      gross = rawGross;
      net = rawBase;
    } else if (rawGross > 0 && rawNet > 0 && (rawGross - rawNet) == fee) {
      gross = rawGross;
      net = rawNet;
    } else {
      double courtAmount = rawBase > 0 ? rawBase : (rawGross > 0 ? rawGross : (rawNet > 0 ? rawNet : 0.0));
      gross = courtAmount + fee;
      net = courtAmount;
    }

    return {'gross': gross, 'fee': fee, 'net': net};
  }

  double get _currentGross {
    double sum = 0.0;
    for (var item in _currentTransactions) {
      final tx = Map<String, dynamic>.from(item is Map ? item : {});
      sum += _getTxFinancials(tx)['gross']!;
    }
    return sum;
  }

  double get _currentServiceFee {
    double sum = 0.0;
    for (var item in _currentTransactions) {
      final tx = Map<String, dynamic>.from(item is Map ? item : {});
      sum += _getTxFinancials(tx)['fee']!;
    }
    return sum;
  }

  double get _currentNet {
    double sum = 0.0;
    for (var item in _currentTransactions) {
      final tx = Map<String, dynamic>.from(item is Map ? item : {});
      sum += _getTxFinancials(tx)['net']!;
    }
    return sum;
  }

  String _formatCurrency(double amount) {
    final format = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
    return format.format(amount);
  }

  DateTime _parseDateStandard(dynamic dateRaw) {
    if (dateRaw == null) return DateTime.now();
    String s = dateRaw.toString().trim();
    if (s.isEmpty) return DateTime.now();
    try {
      String clean = s.replaceAll(RegExp(r'Z$|[+-]\d{2}:?\d{2}$'), '');
      return DateTime.parse(clean);
    } catch (_) {
      try {
        return DateTime.parse(s);
      } catch (_) {
        return DateTime.now();
      }
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return '-';
    try {
      final date = _parseDateStandard(dateStr);
      return DateFormat('MMM dd, yyyy h:mm a').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String get _cleanVenueName {
    String? raw = widget.venueName;
    if (raw == null || raw.trim().isEmpty) return 'Registered Court Facility';
    String v = raw.trim();
    // Strip trailing court parenthetical like "(Green Court)" or "(Court 1)"
    if (v.contains('(')) {
      v = v.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
    }
    // Strip trailing court dash like "- Green Court"
    if (v.contains(' - ')) {
      v = v.split(' - ')[0].trim();
    }
    return v.isNotEmpty ? v : raw.trim();
  }

  String _getStatementNumber() {
    final now = DateTime.now();
    final cleanVenue = _cleanVenueName
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .toUpperCase();
    final venueCode = cleanVenue.length >= 4 ? cleanVenue.substring(0, 4) : cleanVenue.padRight(4, 'X');
    final timeCode = now.millisecondsSinceEpoch.toString().substring(7);
    return 'SOA-${DateFormat('yyyyMM').format(now)}-$venueCode-$timeCode';
  }

  String _getBillingPeriod() {
    if (_selectedDateRange != null) {
      final start = DateFormat('MMM dd, yyyy').format(_selectedDateRange!.start);
      final end = DateFormat('MMM dd, yyyy').format(_selectedDateRange!.end);
      return '$start – $end';
    }
    if (_currentTransactions.isNotEmpty) {
      try {
        List<DateTime> dates = _currentTransactions.map((t) {
          return _parseDateStandard(t['created_at'] ?? t['preferred_date']);
        }).toList();
        dates.sort();
        final start = DateFormat('MMM dd, yyyy').format(dates.first);
        final end = DateFormat('MMM dd, yyyy').format(dates.last);
        return '$start – $end';
      } catch (_) {}
    }
    return DateFormat('MMMM dd, yyyy').format(DateTime.now());
  }

  bool _isOfflineBooking(dynamic item) {
    if (item == null) return false;
    final tx = Map<String, dynamic>.from(item is Map ? item : {});
    final bType = (tx['booking_type'] ?? '').toString().toLowerCase().trim();
    final status = (tx['status'] ?? '').toString().toLowerCase().trim();
    final pName = (tx['player_name'] ?? tx['full_name'] ?? '').toString().toLowerCase().trim();
    final pType = (tx['payment_type'] ?? tx['payment_method'] ?? '').toString().toLowerCase().trim();
    final pRef = (tx['payment_reference'] ?? tx['payment_ref'] ?? tx['ref_no'] ?? '').toString().toLowerCase().trim();

    return bType == 'owner_block' ||
           bType == 'offline' ||
           bType == 'walkin' ||
           bType == 'walk-in' ||
           bType == 'maintenance' ||
           bType == 'maintenance_block' ||
           bType == 'block' ||
           bType.contains('offline') ||
           bType.contains('block') ||
           bType.contains('maintenance') ||
           bType.contains('walk') ||
           status == 'blocked' ||
           status == 'maintenance' ||
           status.contains('block') ||
           status.contains('maintenance') ||
           pName.contains('offline') ||
           pName.contains('walk-in') ||
           pName.contains('walkin') ||
           pName.contains('maintenance') ||
           pName.contains('block') ||
           pType == 'offline' ||
           pType == 'cash' ||
           pRef == 'offline';
  }

  Map<String, dynamic> _calculateBreakdown() {
    int onlineCount = 0;
    int offlineCount = 0;
    double onlineGross = 0;
    double offlineGross = 0;
    double onlineFees = 0;
    double offlineFees = 0;

    for (var item in _currentTransactions) {
      final tx = Map<String, dynamic>.from(item is Map ? item : {});
      final isOff = _isOfflineBooking(tx);
      final fin = _getTxFinancials(tx);
      final gross = fin['gross']!;
      final fee = fin['fee']!;

      if (isOff) {
        offlineCount++;
        offlineGross += gross;
        offlineFees += fee;
      } else {
        onlineCount++;
        onlineGross += gross;
        onlineFees += fee;
      }
    }

    return {
      'onlineCount': onlineCount,
      'offlineCount': offlineCount,
      'onlineGross': onlineGross,
      'offlineGross': offlineGross,
      'onlineFees': onlineFees,
      'offlineFees': offlineFees,
    };
  }

  Future<void> _downloadPdf(BuildContext context) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generating official PDF statement...'),
          duration: Duration(seconds: 1),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
      final pdfBytes = await _generatePdfDocument();
      final filename = '${_getStatementNumber()}.pdf';

      if (kIsWeb) {
        dl_helper.downloadFileFromBytes(
          pdfBytes,
          filename,
          mimeType: 'application/pdf',
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Downloaded $filename successfully.'),
              backgroundColor: AppColors.primaryGreen,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      try {
        await Printing.sharePdf(bytes: pdfBytes, filename: filename);
      } catch (_) {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdfBytes,
          name: filename,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download PDF: $e')),
        );
      }
    }
  }

  Future<void> _printOrExportSOA(BuildContext context) async {
    final String htmlContent = _generatePrintableHtml();
    try {
      final Uri uri = Uri.dataFromString(
        htmlContent,
        mimeType: 'text/html',
        encoding: utf8,
      );
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open HTML preview: $e')),
        );
      }
    }
  }

  Future<void> _printPdf(BuildContext context) async {
    try {
      final pdfBytes = await _generatePdfDocument();
      final filename = '${_getStatementNumber()}.pdf';
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: filename,
      );
    } catch (_) {
      if (context.mounted) {
        await _printOrExportSOA(context);
      }
    }
  }

  Future<void> _downloadCsv(BuildContext context) async {
    try {
      final String csvContent = _generateCsvContent();
      final filename = '${_getStatementNumber()}.csv';
      if (kIsWeb) {
        dl_helper.downloadFileFromBytes(
          Uint8List.fromList(utf8.encode(csvContent)),
          filename,
          mimeType: 'text/csv;charset=utf-8',
        );
      } else {
        final Uri uri = Uri.dataFromString(
          csvContent,
          mimeType: 'text/csv',
          encoding: utf8,
        );
        await launchUrl(uri);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded $filename successfully.'),
            duration: const Duration(seconds: 2),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download CSV: $e')),
        );
      }
    }
  }

  String _generateCsvContent() {
    final transactions = _currentTransactions;
    final grossEarnings = _currentGross;
    final totalServiceFee = _currentServiceFee;
    final totalNetEarnings = _currentNet;

    final breakdown = _calculateBreakdown();
    final int onlineCount = breakdown['onlineCount'];
    final int offlineCount = breakdown['offlineCount'];
    final double onlineFees = breakdown['onlineFees'];
    final double offlineFees = breakdown['offlineFees'];
    final double onlineGross = breakdown['onlineGross'];
    final double offlineGross = breakdown['offlineGross'];

    final StringBuffer buf = StringBuffer();
    buf.writeln('STATEMENT OF ACCOUNT');
    buf.writeln('Picklebook By Dynamics Software Solutions');
    buf.writeln('Statement Ref,${_getStatementNumber()}');
    buf.writeln('Billing Period,"${_getBillingPeriod()}"');
    buf.writeln('Billing Email,billing@picklebook-ph.com');
    buf.writeln('Address,"Bogo, Cebu, Philippines 6010"');
    buf.writeln('Tax Status,"NON-VAT Reg. TIN: 211-051-054"');
    buf.writeln('Status,"CURRENT BILLING"');
    buf.writeln('Date Issued,"${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}"');
    buf.writeln('Billed To,"${_cleanVenueName.replaceAll('"', '""')}"');
    buf.writeln('Owner Email,"${widget.ownerEmail ?? ''}"');
    buf.writeln('');
    buf.writeln('STATEMENT SUMMARY (SERVICE CHARGES)');
    buf.writeln('Total Booking Transactions,${transactions.length}');
    buf.writeln('Online Bookings Count,$onlineCount');
    buf.writeln('Online Service Fees (PHP),${onlineFees.toStringAsFixed(2)}');
    buf.writeln('Online Gross Player Payments (PHP),${onlineGross.toStringAsFixed(2)}');
    buf.writeln('Offline Bookings Count,$offlineCount');
    buf.writeln('Offline Service Fees (PHP),${offlineFees.toStringAsFixed(2)}');
    buf.writeln('Offline Gross Player Payments (PHP),${offlineGross.toStringAsFixed(2)}');
    buf.writeln('TOTAL NET PAYABLE (SERVICE CHARGE) (PHP),${totalServiceFee.toStringAsFixed(2)}');
    buf.writeln('Total Player Collections (Gross) (PHP),${grossEarnings.toStringAsFixed(2)}');
    buf.writeln('Total Net Court Revenue Remitted (PHP),${totalNetEarnings.toStringAsFixed(2)}');
    buf.writeln('');
    buf.writeln('Item #,Booking Type,Date & Time,Transaction ID,Payment Ref No,Player Name,Court Name,Schedule,Gross Paid (PHP),Service Fee (PHP),Net Court Amount (PHP)');

    int idx = 1;
    for (var item in transactions) {
      Map<String, dynamic> tx = Map<String, dynamic>.from(item);
      final isOff = _isOfflineBooking(tx);
      final typeStr = isOff ? 'Offline' : 'Online';
      String dateStr = _formatDate((tx['created_at'] ?? tx['preferred_date'] ?? '').toString()).replaceAll('"', '""');

      String rawTxnId = (tx['id'] ?? '').toString();
      if (tx['all_ids'] != null && (tx['all_ids'] as List).isNotEmpty) {
        rawTxnId = (tx['all_ids'] as List).join('; ');
      }
      String refNo = (tx['payment_ref_no'] ?? tx['ref_no'] ?? '').toString().replaceAll('"', '""');
      String player = (tx['player_name'] ?? tx['full_name'] ?? 'Player').toString().replaceAll('"', '""');
      String court = (tx['court_name'] ?? tx['service_type'] ?? 'Court').toString().replaceAll('"', '""');
      String sched = (tx['preferred_time'] ?? tx['booking_time'] ?? '').toString().replaceAll('"', '""');

      final fin = _getTxFinancials(tx);
      double gross = isOff ? 0.0 : fin['gross']!;
      double fee = fin['fee']!;
      double net = isOff ? 0.0 : fin['net']!;

      buf.writeln('$idx,"$typeStr","$dateStr","$rawTxnId","$refNo","$player","$court","$sched",${gross.toStringAsFixed(2)},-${fee.toStringAsFixed(2)},${net.toStringAsFixed(2)}');
      idx++;
    }

    buf.writeln('');
    buf.writeln('TOTALS,,Online Fees: ${onlineFees.toStringAsFixed(2)},Offline Fees: ${offlineFees.toStringAsFixed(2)},,,,TOTAL NET PAYABLE (SERVICE CHARGE):,"${totalServiceFee.toStringAsFixed(2)}"');
    return buf.toString();
  }

  @visibleForTesting
  Future<Uint8List> generatePdfForTest() => _generatePdfDocument();

  Future<Uint8List> _generatePdfDocument() async {
    final transactions = _currentTransactions;
    final totalServiceFee = _currentServiceFee;
    pw.MemoryImage? logoImage;
    try {
      final Uint8List logoBytes = base64Decode(kPicklebookLogoBase64);
      logoImage = pw.MemoryImage(logoBytes);
    } catch (_) {
      try {
        final ByteData logoData = await rootBundle.load('assets/logo.png');
        logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
      } catch (_) {}
    }

    final pdf = pw.Document();
    final statementNo = _getStatementNumber();
    final billingPeriod = _getBillingPeriod();
    final todayStr = DateFormat('MMMM dd, yyyy').format(DateTime.now());
    final displayName = _cleanVenueName;

    String formatPhp(double amount) {
      final format = NumberFormat.currency(locale: 'en_PH', symbol: 'PHP ');
      return format.format(amount);
    }

    final breakdown = _calculateBreakdown();
    List<List<String>> tableData = [];
    int index = 1;
    for (var item in transactions) {
      Map<String, dynamic> tx = Map<String, dynamic>.from(item);
      final isOff = _isOfflineBooking(tx);
      String dateStr = _formatDate((tx['created_at'] ?? tx['preferred_date'] ?? '').toString());

      String rawTxnId = (tx['id'] ?? '').toString();
      if (tx['all_ids'] != null && (tx['all_ids'] as List).isNotEmpty) {
        rawTxnId = '#${(tx['all_ids'] as List).join(', #')}';
      } else if (rawTxnId.isNotEmpty) {
        rawTxnId = '#$rawTxnId';
      } else {
        rawTxnId = 'N/A';
      }
      String refNo = (tx['payment_ref_no'] ?? tx['ref_no'] ?? '-').toString();
      String typeLabel = isOff ? '[OFFLINE]' : '[ONLINE]';
      String refText = refNo != '-' && refNo.isNotEmpty ? '$typeLabel\n$rawTxnId\nRef: $refNo' : '$typeLabel\n$rawTxnId';

      String player = (tx['player_name'] ?? tx['full_name'] ?? 'Player').toString();
      String court = (tx['court_name'] ?? tx['service_type'] ?? 'Court').toString();
      String sched = (tx['preferred_time'] ?? tx['booking_time'] ?? '').toString();
      String courtAndSched = sched.isNotEmpty ? '$court\n$sched' : court;

      final fin = _getTxFinancials(tx);
      double gross = isOff ? 0.0 : fin['gross']!;
      double fee = fin['fee']!;
      double net = isOff ? 0.0 : fin['net']!;

      tableData.add([
        index.toString(),
        dateStr,
        refText,
        player,
        courtAndSched,
        formatPhp(gross),
        '-${formatPhp(fee)}',
        formatPhp(net),
      ]);
      index++;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (pw.Context context) {
          if (context.pageNumber > 1) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 10),
              padding: const pw.EdgeInsets.only(bottom: 6),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('STATEMENT OF ACCOUNT - $statementNo',
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1A5D1A'))),
                  pw.Text('Billed To: $displayName | Period: $billingPeriod',
                      style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                ],
              ),
            );
          }
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (logoImage != null)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 3),
                          child: pw.Image(
                            logoImage,
                            height: 22,
                            fit: pw.BoxFit.contain,
                          ),
                        )
                      else
                        pw.Text(
                          'PICKLEBOOK',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#1A5D1A'),
                          ),
                        ),
                      pw.Text(
                        'BY DYNAMICS SOFTWARE SOLUTIONS',
                        style: pw.TextStyle(
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#475569'),
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Bogo, Cebu, Philippines 6010',
                        style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                      ),
                      pw.Text(
                        'NON-VAT Reg. TIN: 211-051-054 | billing@picklebook-ph.com',
                        style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'STATEMENT OF ACCOUNT',
                        style: pw.TextStyle(
                          fontSize: 15,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#1E293B'),
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'SOA Ref: $statementNo',
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#1A5D1A'),
                        ),
                      ),
                      pw.Text(
                        'Issue Date: $todayStr',
                        style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                      ),
                      pw.Text(
                        'Billing Period: $billingPeriod',
                        style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1.2, color: PdfColor.fromHex('#1A5D1A')),
              pw.SizedBox(height: 8),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 8),
            padding: const pw.EdgeInsets.only(top: 6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Confidential & Proprietary • Picklebook By Dynamics Software Solutions • Automated Settlement',
                  style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) => [
          // 1. Billed To Card
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F8FAFC'),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
              border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('BILLED TO (COURT FACILITY / OWNER):',
                        style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                    pw.SizedBox(height: 2),
                    pw.Text(displayName,
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E293B'))),
                    if (widget.ownerEmail != null && widget.ownerEmail!.trim().isNotEmpty) ...[
                      pw.SizedBox(height: 1),
                      pw.Text('Account Email: ${widget.ownerEmail}',
                          style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                    ],
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('STATUS:',
                        style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                    pw.SizedBox(height: 2),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#DCFCE7'),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                      ),
                      child: pw.Text('CURRENT BILLING',
                          style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#15803D'))),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 10),

          // 2. Financial Summary Box
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(7),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#EFF6FF'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    border: pw.Border.all(color: PdfColor.fromHex('#BFDBFE')),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('ONLINE BOOKINGS (${breakdown['onlineCount']})',
                          style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1D4ED8'))),
                      pw.SizedBox(height: 2),
                      pw.Text(formatPhp(breakdown['onlineFees']),
                          style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E293B'))),
                      pw.Text('Gross: ${formatPhp(breakdown['onlineGross'])} (fee: PHP 15/ea)', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600)),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(7),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F5F3FF'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    border: pw.Border.all(color: PdfColor.fromHex('#DDD6FE')),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('OFFLINE BOOKINGS (${breakdown['offlineCount']})',
                          style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#6D28D9'))),
                      pw.SizedBox(height: 2),
                      pw.Text(formatPhp(breakdown['offlineFees']),
                          style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E293B'))),
                      pw.Text('Gross: ${formatPhp(breakdown['offlineGross'])} (fee: PHP 15/ea)', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600)),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(7),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#FFF7ED'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    border: pw.Border.all(color: PdfColor.fromHex('#FDBA74')),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('TOTAL NET PAYABLE (SERVICE CHARGE)',
                          style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#C2410C'))),
                      pw.SizedBox(height: 2),
                      pw.Text(formatPhp(totalServiceFee),
                          style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#C2410C'))),
                      pw.Text('${transactions.length} total txns @ PHP 15 fixed fee', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),

          // Policy Note
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F8FAFC'),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
            ),
            child: pw.Text(
              'Billing & Service Charge Policy: In accordance with the Facility Partner Agreement, a fixed service fee of PHP 15.00 is charged per checkout reservation session (covering platform infrastructure, player booking coordination, and payment processing). Gross amounts reflect customer collections; the PHP 15.00 fee is deducted to compute Net Remitted.',
              style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700),
            ),
          ),
          pw.SizedBox(height: 10),

          // Table Header Label
          pw.Text('ITEMIZED TRANSACTION BREAKDOWN',
              style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E293B'))),
          pw.SizedBox(height: 5),

          // Table
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: PdfColor.fromHex('#E2E8F0'), width: 0.5),
            headerStyle: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#1A5D1A')),
            cellStyle: const pw.TextStyle(fontSize: 6.5),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            columnWidths: {
              0: const pw.FixedColumnWidth(18),
              1: const pw.FixedColumnWidth(65),
              2: const pw.FixedColumnWidth(60),
              3: const pw.FixedColumnWidth(65),
              4: const pw.FlexColumnWidth(1.2),
              5: const pw.FixedColumnWidth(55),
              6: const pw.FixedColumnWidth(55),
              7: const pw.FixedColumnWidth(55),
            },
            cellAlignments: {
              0: pw.Alignment.center,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerLeft,
              4: pw.Alignment.centerLeft,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
              7: pw.Alignment.centerRight,
            },
            headerAlignments: {
              0: pw.Alignment.center,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerLeft,
              4: pw.Alignment.centerLeft,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
              7: pw.Alignment.centerRight,
            },
            headers: ['#', 'Date & Time', 'Txn / Ref #', 'Player Name', 'Court & Sched', 'Gross', 'Fee (P15)', 'Net'],
            data: tableData,
          ),
          pw.SizedBox(height: 6),

          // Table Totals (Moved Amount Down To Prevent Overlap / Margin Overflow)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#1B4332'),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'TOTAL STATEMENT SUMMARY (${transactions.length} Transactions):',
                      style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                    ),
                    pw.Row(
                      children: [
                        pw.Text(
                          'Online (${breakdown['onlineCount']}): ${formatPhp(breakdown['onlineFees'])}    ',
                          style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#93C5FD')),
                        ),
                        pw.Text(
                          'Offline (${breakdown['offlineCount']}): ${formatPhp(breakdown['offlineFees'])}',
                          style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#DDD6FE')),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 5),
                pw.Container(height: 0.5, color: PdfColor.fromHex('#2D6A4F')),
                pw.SizedBox(height: 5),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'PLATFORM SERVICE FEE TOTAL DUE',
                      style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#D1D5DB')),
                    ),
                    pw.Text(
                      'NET PAYABLE (SERVICE CHARGE): ${formatPhp(totalServiceFee)}',
                      style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#86EFAC')),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Signatures
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Prepared & Certified Correct By:', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                  pw.SizedBox(height: 26),
                  pw.Container(width: 150, height: 1, color: PdfColors.grey600),
                  pw.SizedBox(height: 3),
                  pw.Text('PickleBook Billing Division', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Picklebook By Dynamics Software Solutions', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Received & Acknowledged By:', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                  pw.SizedBox(height: 26),
                  pw.Container(width: 150, height: 1, color: PdfColors.grey600),
                  pw.SizedBox(height: 3),
                  pw.Text(displayName, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Authorized Facility Representative', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600)),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    return await pdf.save();
  }

  @override
  Widget build(BuildContext context) {
    final statementNo = _getStatementNumber();
    final billingPeriod = _getBillingPeriod();
    final todayStr = DateFormat('MMMM dd, yyyy').format(DateTime.now());
    final displayName = _cleanVenueName;

    final transactions = _currentTransactions;
    final totalServiceFee = _currentServiceFee;

    final breakdown = _calculateBreakdown();
    final int onlineCount = breakdown['onlineCount'];
    final int offlineCount = breakdown['offlineCount'];
    final double onlineFees = breakdown['onlineFees'];
    final double offlineFees = breakdown['offlineFees'];
    final double onlineGross = breakdown['onlineGross'];
    final double offlineGross = breakdown['offlineGross'];

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text(
          'Statement of Account',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: AppColors.richBlack,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.richBlack),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          InkWell(
            onTap: _pickDateRange,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _selectedDateRange != null ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _selectedDateRange != null ? AppColors.primaryGreen : Colors.grey.shade300,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.date_range_rounded,
                    size: 16,
                    color: _selectedDateRange != null ? AppColors.primaryGreen : Colors.grey.shade700,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _selectedDateRange == null
                        ? 'Filter Dates'
                        : '${DateFormat('MMM dd').format(_selectedDateRange!.start)} – ${DateFormat('MMM dd, yyyy').format(_selectedDateRange!.end)}',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _selectedDateRange != null ? AppColors.primaryGreen : AppColors.richBlack,
                    ),
                  ),
                  if (_selectedDateRange != null) ...[
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: _clearDateRange,
                      child: const Icon(Icons.close, size: 14, color: AppColors.primaryGreen),
                    ),
                  ] else ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Download CSV (Excel)',
            icon: const Icon(Icons.table_chart_outlined, color: AppColors.primaryGreen, size: 20),
            onPressed: () => _downloadCsv(context),
          ),
          IconButton(
            tooltip: 'Print Statement',
            icon: const Icon(Icons.print_outlined, color: AppColors.primaryGreen, size: 20),
            onPressed: () => _printPdf(context),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 4),
            child: Center(
              child: ElevatedButton.icon(
                onPressed: () => _downloadPdf(context),
                icon: const Icon(Icons.download_rounded, size: 16),
                label: Text(
                  'Download PDF',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  minimumSize: const Size(0, 36),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- HEADER / LETTERHEAD ---
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Image.memory(
                              base64Decode(kPicklebookLogoBase64),
                              height: 42,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                              errorBuilder: (context, error, stackTrace) => Image.asset(
                                'assets/logo.png',
                                height: 42,
                                fit: BoxFit.contain,
                                errorBuilder: (c, e, s) => Text(
                                  'PICKLEBOOK',
                                  style: GoogleFonts.outfit(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'BY DYNAMICS SOFTWARE SOLUTIONS',
                              style: GoogleFonts.outfit(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                color: AppColors.stoneGray,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Sports Facility Booking & Queue Management Platform',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            Text(
                              'Bogo, Cebu, Philippines 6010 • billing@picklebook-ph.com',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            Text(
                              'NON-VAT Reg. TIN: 211-051-054',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade700,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.richBlack,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'STATEMENT OF ACCOUNT',
                              style: GoogleFonts.outfit(
                                color: AppColors.accentLime,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Statement No: $statementNo',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: AppColors.richBlack,
                            ),
                          ),
                          Text(
                            'Date of Issue: $todayStr',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Text(
                              'STATUS: CURRENT BILLING',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  Divider(color: Colors.grey.shade300, thickness: 1.2),
                  const SizedBox(height: 16),

                  // --- BILLED TO & PERIOD ---
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'BILLED TO (COURT OWNER / FACILITY):',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                  color: AppColors.stoneGray,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                displayName,
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.richBlack,
                                ),
                              ),
                              if (widget.ownerEmail != null && widget.ownerEmail!.trim().isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Account: ${widget.ownerEmail!.trim()}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ],
                              Text(
                                'Facility Location: Bogo, Cebu, Philippines 6010',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 70,
                          color: Colors.grey.shade300,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'STATEMENT PERIOD & SUMMARY:',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                  color: AppColors.stoneGray,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                billingPeriod,
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.deepTeal,
                                ),
                              ),
                              const SizedBox(height: 5),
                              InkWell(
                                onTap: _pickDateRange,
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _selectedDateRange != null ? const Color(0xFFDCFCE7) : const Color(0xFFF0FDF4),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: _selectedDateRange != null ? AppColors.primaryGreen : AppColors.primaryGreen.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.primaryGreen),
                                      const SizedBox(width: 4),
                                      Text(
                                        _selectedDateRange == null ? 'Filter / Select Date Range' : 'Change Date Range',
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryGreen,
                                        ),
                                      ),
                                      if (_selectedDateRange != null) ...[
                                        const SizedBox(width: 6),
                                        InkWell(
                                          onTap: _clearDateRange,
                                          child: const Icon(Icons.close, size: 12, color: AppColors.primaryGreen),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Total Transactions: ${transactions.length} Verified Bookings',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              Text(
                                'Settlement Term: Automated Net Remittance',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // --- FINANCIAL SUMMARY CARDS ---
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 600;
                      return isNarrow
                          ? Column(
                              children: [
                                _buildSummaryBox(
                                  title: 'Online Bookings ($onlineCount)',
                                  amount: onlineFees,
                                  subtitle: 'Gross: ${_formatCurrency(onlineGross)} • ₱15/txn fee',
                                  color: const Color(0xFF1E88E5),
                                  icon: Icons.language,
                                ),
                                const SizedBox(height: 10),
                                _buildSummaryBox(
                                  title: 'Offline Bookings ($offlineCount)',
                                  amount: offlineFees,
                                  subtitle: 'Gross: ${_formatCurrency(offlineGross)} • ₱15/txn fee',
                                  color: const Color(0xFF7C3AED),
                                  icon: Icons.storefront_outlined,
                                ),
                                const SizedBox(height: 10),
                                _buildSummaryBox(
                                  title: 'TOTAL NET PAYABLE',
                                  amount: totalServiceFee,
                                  subtitle: '${transactions.length} total txns × ₱15.00 platform charge',
                                  color: const Color(0xFFE65100),
                                  icon: Icons.receipt_long_outlined,
                                  highlight: true,
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: _buildSummaryBox(
                                    title: 'Online Bookings ($onlineCount)',
                                    amount: onlineFees,
                                    subtitle: 'Gross: ${_formatCurrency(onlineGross)} • ₱15/txn fee',
                                    color: const Color(0xFF1E88E5),
                                    icon: Icons.language,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildSummaryBox(
                                    title: 'Offline Bookings ($offlineCount)',
                                    amount: offlineFees,
                                    subtitle: 'Gross: ${_formatCurrency(offlineGross)} • ₱15/txn fee',
                                    color: const Color(0xFF7C3AED),
                                    icon: Icons.storefront_outlined,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildSummaryBox(
                                    title: 'TOTAL NET PAYABLE',
                                    amount: totalServiceFee,
                                    subtitle: '${transactions.length} total txns × ₱15.00 platform charge',
                                    color: const Color(0xFFE65100),
                                    icon: Icons.receipt_long_outlined,
                                    highlight: true,
                                  ),
                                ),
                              ],
                            );
                    },
                  ),

                  const SizedBox(height: 16),

                  // --- SERVICE CHARGE EXPLANATION NOTICE ---
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFE082)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, color: Color(0xFFF57F17), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Platform Billing Note: Picklebook charges a fixed service fee of ₱15.00 per booking checkout transaction to cover secure payment gateway fees, automated SMS/email booking notifications, queue system maintenance, and platform infrastructure. All service charges are billed transparently below.',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: const Color(0xFF5D4037),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- ITEMIZED TRANSACTION TABLE ---
                  Text(
                    'ITEMIZED TRANSACTION AUDIT TRAIL',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: AppColors.richBlack,
                    ),
                  ),
                  const SizedBox(height: 8),

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(const Color(0xFFF3F4F6)),
                        headingRowHeight: 40,
                        dataRowMinHeight: 44,
                        dataRowMaxHeight: 56,
                        horizontalMargin: 14,
                        columnSpacing: 18,
                        columns: [
                          DataColumn(label: Text('#', style: _tableHeaderStyle())),
                          DataColumn(label: Text('Date & Time', style: _tableHeaderStyle())),
                          DataColumn(label: Text('Txn / Ref #', style: _tableHeaderStyle())),
                          DataColumn(label: Text('Customer & Schedule', style: _tableHeaderStyle())),
                          DataColumn(label: Text('Gross Paid', style: _tableHeaderStyle()), numeric: true),
                          DataColumn(label: Text('Service Fee (₱15)', style: _tableHeaderStyle()), numeric: true),
                          DataColumn(label: Text('Net to Owner', style: _tableHeaderStyle()), numeric: true),
                        ],
                        rows: List.generate(transactions.length, (index) {
                          final tx = transactions[index];
                          final isOff = _isOfflineBooking(tx);
                          final isEven = index % 2 == 0;
                          final player = (tx['player_name'] ?? 'Player').toString();
                          final court = (tx['court_name'] ?? 'Court').toString();
                          final slot = (tx['preferred_time'] ?? '').toString();
                          final refNo = (tx['payment_reference'] ?? tx['payment_ref'] ?? tx['ref_no'] ?? tx['id'] ?? '-').toString();
                          final fin = _getTxFinancials(tx);
                          final gross = isOff ? 0.0 : fin['gross']!;
                          final fee = fin['fee']!;
                          final net = isOff ? 0.0 : fin['net']!;
                          final dateStr = _formatDate((tx['created_at'] ?? tx['preferred_date']).toString());

                          return DataRow(
                            color: WidgetStateProperty.all(isEven ? Colors.white : const Color(0xFFFAFAFA)),
                            cells: [
                              DataCell(Text('${index + 1}', style: const TextStyle(fontSize: 11, color: Colors.grey))),
                              DataCell(
                                Text(
                                  dateStr,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                                ),
                              ),
                              DataCell(
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: isOff ? const Color(0xFFEDE9FE) : const Color(0xFFE0F2FE),
                                            borderRadius: BorderRadius.circular(3),
                                            border: Border.all(
                                              color: isOff ? const Color(0xFFDDD6FE) : const Color(0xFFBAE6FD),
                                              width: 0.5,
                                            ),
                                          ),
                                          child: Text(
                                            isOff ? 'OFFLINE' : 'ONLINE',
                                            style: TextStyle(
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.w800,
                                              color: isOff ? const Color(0xFF6D28D9) : const Color(0xFF0369A1),
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            'Ref: $refNo',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text('ID: ${tx['id'] ?? '-'}', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                                  ],
                                ),
                              ),
                              DataCell(
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(player, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    Text(
                                      '$court • $slot',
                                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(
                                Text(
                                  _formatCurrency(gross),
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.orange.shade200, width: 0.5),
                                  ),
                                  child: Text(
                                    _formatCurrency(fee),
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  _formatCurrency(net),
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // --- TOTALS ROW HIGHLIGHT (Clean 2-Row Layout, Amount Moved Down) ---
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Text(
                              'TOTAL STATEMENT SUMMARY (${transactions.length} Bookings):',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Online ($onlineCount): ${_formatCurrency(onlineFees)}',
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFF93C5FD),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Offline ($offlineCount): ${_formatCurrency(offlineFees)}',
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFFDDD6FE),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(height: 0.6, color: Colors.white24),
                        const SizedBox(height: 10),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Text(
                              'PLATFORM SERVICE FEE TOTAL DUE:',
                              style: GoogleFonts.outfit(
                                color: Colors.grey.shade400,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'NET PAYABLE (SERVICE CHARGE): ${_formatCurrency(totalServiceFee)}',
                              style: GoogleFonts.outfit(
                                color: AppColors.accentLime,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // --- CERTIFICATION & SIGNATURES ---
                  Divider(color: Colors.grey.shade300, thickness: 1),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PREPARED & CERTIFIED BY:',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Container(width: 160, height: 1, color: Colors.black87),
                            const SizedBox(height: 4),
                            Text(
                              'PickleBook Billing Division',
                              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Picklebook By Dynamics Software Solutions',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'RECEIVED & ACKNOWLEDGED BY:',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Container(width: 180, height: 1, color: Colors.black87),
                            const SizedBox(height: 4),
                            Text(
                              displayName,
                              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Authorized Court Facility Representative',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'This is an official computer-generated Statement of Account from Picklebook By Dynamics Software Solutions • Generated on $todayStr',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontFamily: 'Poppins'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Back'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.richBlack,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _downloadCsv(context),
                icon: const Icon(Icons.table_chart_outlined, size: 16, color: AppColors.primaryGreen),
                label: const Text('CSV / Excel'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  side: const BorderSide(color: AppColors.primaryGreen),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _printPdf(context),
                icon: const Icon(Icons.print_outlined, size: 16),
                label: const Text('Print'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.richBlack,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _downloadPdf(context),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Download PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryBox({
    required String title,
    required double amount,
    required String subtitle,
    required Color color,
    required IconData icon,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFFFFF3E0) : color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlight ? Colors.orange.shade300 : color.withValues(alpha: 0.25),
          width: highlight ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _formatCurrency(amount),
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.richBlack,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _tableHeaderStyle() {
    return GoogleFonts.outfit(
      fontSize: 11,
      fontWeight: FontWeight.bold,
      color: AppColors.richBlack,
    );
  }

  String _generatePrintableHtml() {
    final transactions = _currentTransactions;
    final totalServiceFee = _currentServiceFee;
    final statementNo = _getStatementNumber();
    final billingPeriod = _getBillingPeriod();
    final todayStr = DateFormat('MMMM dd, yyyy').format(DateTime.now());
    final displayName = _cleanVenueName;

    final breakdown = _calculateBreakdown();
    final int onlineCount = breakdown['onlineCount'];
    final int offlineCount = breakdown['offlineCount'];
    final double onlineFees = breakdown['onlineFees'];
    final double offlineFees = breakdown['offlineFees'];
    final double onlineGross = breakdown['onlineGross'];
    final double offlineGross = breakdown['offlineGross'];

    final StringBuffer rowsHtml = StringBuffer();
    for (int i = 0; i < transactions.length; i++) {
      final tx = transactions[i];
      final isOff = _isOfflineBooking(tx);
      final isEven = i % 2 == 0;
      final player = (tx['player_name'] ?? 'Player').toString();
      final court = (tx['court_name'] ?? 'Court').toString();
      final slot = (tx['preferred_time'] ?? '').toString();
      final refNo = (tx['payment_reference'] ?? tx['payment_ref'] ?? tx['ref_no'] ?? tx['id'] ?? '-').toString();
      final fin = _getTxFinancials(tx);
      final gross = isOff ? 0.0 : fin['gross']!;
      final fee = fin['fee']!;
      final net = isOff ? 0.0 : fin['net']!;
      final dateStr = _formatDate((tx['created_at'] ?? tx['preferred_date']).toString());

      final badgeStyle = isOff
          ? 'background: #ede9fe; color: #6d28d9; border: 1px solid #ddd6fe;'
          : 'background: #e0f2fe; color: #0369a1; border: 1px solid #bae6fd;';
      final badgeLabel = isOff ? 'OFFLINE' : 'ONLINE';

      rowsHtml.write('''
        <tr style="background-color: ${isEven ? '#ffffff' : '#f9fafb'};">
          <td style="text-align: center; color: #6b7280;">${i + 1}</td>
          <td><strong>$dateStr</strong></td>
          <td>
            <span style="display: inline-block; padding: 1px 5px; border-radius: 3px; font-size: 8.5px; font-weight: 800; margin-bottom: 2px; $badgeStyle">$badgeLabel</span>
            <div style="font-weight: 600;">Ref: $refNo</div>
            <div style="font-size: 10px; color: #6b7280;">ID: ${tx['id'] ?? '-'}</div>
          </td>
          <td>
            <div style="font-weight: 600;">$player</div>
            <div style="font-size: 10px; color: #6b7280;">$court • $slot</div>
          </td>
          <td style="text-align: right; font-weight: 600;">${_formatCurrency(gross)}</td>
          <td style="text-align: right; font-weight: 700; color: #b45309;">${_formatCurrency(fee)}</td>
          <td style="text-align: right; font-weight: 700; color: #15803d;">${_formatCurrency(net)}</td>
        </tr>
      ''');
    }

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Statement of Account - $displayName</title>
  <style>
    @page { size: A4 portrait; margin: 15mm; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
      color: #111827;
      margin: 0;
      padding: 20px;
      font-size: 12px;
      line-height: 1.4;
      background: #fff;
    }
    .header {
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      border-bottom: 2px solid #e5e7eb;
      padding-bottom: 14px;
      margin-bottom: 14px;
    }
    .logo-title {
      font-size: 24px;
      font-weight: 900;
      color: #1b4332;
      letter-spacing: -0.5px;
      margin: 0;
    }
    .logo-sub {
      font-size: 10px;
      font-weight: 700;
      color: #6b7280;
      letter-spacing: 1.5px;
      text-transform: uppercase;
      margin-bottom: 4px;
    }
    .soa-badge {
      background: #0a0f0d;
      color: #a7e23a;
      padding: 5px 10px;
      border-radius: 4px;
      font-weight: 700;
      font-size: 12px;
      display: inline-block;
      margin-bottom: 6px;
    }
    .meta-box {
      text-align: right;
    }
    .info-grid {
      display: flex;
      background: #f9fafb;
      border: 1px solid #e5e7eb;
      border-radius: 6px;
      padding: 12px;
      margin-bottom: 16px;
    }
    .info-col {
      flex: 1;
    }
    .info-col:first-child {
      border-right: 1px solid #e5e7eb;
      padding-right: 16px;
      margin-right: 16px;
    }
    .info-label {
      font-size: 10px;
      font-weight: 700;
      color: #6b7280;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      margin-bottom: 4px;
    }
    .summary-boxes {
      display: flex;
      gap: 12px;
      margin-bottom: 16px;
    }
    .summary-card {
      flex: 1;
      padding: 12px;
      border-radius: 6px;
      border: 1px solid #e5e7eb;
      background: #f9fafb;
    }
    .summary-card.highlight {
      background: #fffbeb;
      border-color: #fde68a;
    }
    .summary-card .title {
      font-size: 10px;
      font-weight: 700;
      color: #4b5563;
      text-transform: uppercase;
      margin-bottom: 4px;
    }
    .summary-card .val {
      font-size: 18px;
      font-weight: 800;
      color: #111827;
      margin-bottom: 2px;
    }
    .callout {
      background: #eff6ff;
      border-left: 3px solid #3b82f6;
      padding: 8px 12px;
      font-size: 10.5px;
      color: #1e3a8a;
      border-radius: 0 4px 4px 0;
      margin-bottom: 16px;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      font-size: 11px;
      margin-bottom: 16px;
    }
    th {
      background: #f3f4f6;
      color: #111827;
      font-weight: 700;
      text-align: left;
      padding: 8px 10px;
      border: 1px solid #e5e7eb;
    }
    td {
      padding: 8px 10px;
      border: 1px solid #e5e7eb;
    }
    .totals-banner {
      background: #1b4332;
      color: #fff;
      padding: 10px 14px;
      border-radius: 6px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      font-weight: 700;
      margin-bottom: 24px;
    }
    .signatures {
      display: flex;
      justify-content: space-between;
      margin-top: 30px;
      padding-top: 16px;
      border-top: 1px solid #e5e7eb;
    }
    .sign-col {
      width: 45%;
    }
    .sign-line {
      border-bottom: 1px solid #111827;
      margin-top: 32px;
      margin-bottom: 6px;
    }
    @media print {
      body { padding: 0; }
      .no-print { display: none !important; }
    }
  </style>
</head>
<body>
  <div class="no-print" style="margin-bottom: 16px; text-align: right;">
    <button onclick="window.print()" style="background: #1b4332; color: #fff; border: none; padding: 8px 16px; font-weight: bold; border-radius: 6px; cursor: pointer;">
      Print / Save as PDF
    </button>
  </div>

  <div class="header">
    <div>
      <img src="data:image/png;base64,$kPicklebookLogoBase64" height="38" style="object-fit: contain; display: block; margin-bottom: 4px;" alt="Picklebook Logo" />
      <div class="logo-sub">By Dynamics Software Solutions</div>
      <div style="color: #4b5563; font-size: 11px;">Sports Facility Booking & Queue Management Platform</div>
      <div style="color: #6b7280; font-size: 10px;">Bogo, Cebu, Philippines 6010 • billing@picklebook-ph.com • NON-VAT Reg. TIN: 211-051-054</div>
    </div>
    <div class="meta-box">
      <div class="soa-badge">STATEMENT OF ACCOUNT</div>
      <div style="font-weight: 700; font-size: 12px;">$statementNo</div>
      <div style="color: #6b7280; font-size: 11px;">Issue Date: $todayStr</div>
      <div style="color: #15803d; font-weight: 700; font-size: 10px; margin-top: 2px;">STATUS: CURRENT BILLING</div>
    </div>
  </div>

  <div class="info-grid">
    <div class="info-col">
      <div class="info-label">Billed To (Court Facility / Owner)</div>
      <div style="font-size: 16px; font-weight: 800; color: #111827;">$displayName</div>
      <div style="color: #4b5563; margin-top: 2px;">Account: ${widget.ownerEmail ?? 'Facility Administrator'}</div>
      <div style="color: #6b7280; font-size: 10px;">Location: Bogo, Cebu, Philippines 6010</div>
    </div>
    <div class="info-col">
      <div class="info-label">Statement Period & Activity</div>
      <div style="font-size: 14px; font-weight: 700; color: #1b4332;">$billingPeriod</div>
      <div style="color: #4b5563; margin-top: 2px;">Volume: ${transactions.length} Verified Bookings</div>
      <div style="color: #6b7280; font-size: 10px;">Settlement: Automated Net Remittance</div>
    </div>
  </div>

  <div class="summary-boxes">
    <div class="summary-card">
      <div class="title" style="color: #1d4ed8;">Online Bookings ($onlineCount)</div>
      <div class="val">${_formatCurrency(onlineFees)}</div>
      <div style="color: #6b7280; font-size: 10px;">Gross: ${_formatCurrency(onlineGross)} • ₱15/txn fee</div>
    </div>
    <div class="summary-card">
      <div class="title" style="color: #6d28d9;">Offline Bookings ($offlineCount)</div>
      <div class="val">${_formatCurrency(offlineFees)}</div>
      <div style="color: #6b7280; font-size: 10px;">Gross: ${_formatCurrency(offlineGross)} • ₱15/txn fee</div>
    </div>
    <div class="summary-card highlight">
      <div class="title" style="color: #b45309;">TOTAL NET PAYABLE</div>
      <div class="val" style="color: #b45309;">${_formatCurrency(totalServiceFee)}</div>
      <div style="color: #6b7280; font-size: 10px;">${transactions.length} total txns • ₱15.00 platform charge</div>
    </div>
  </div>

  <div class="callout">
    <strong>Billing Policy Notice:</strong> Picklebook charges a fixed platform service charge of ₱15.00 per booking checkout session to cover payment gateway fees, instant SMS notifications, online reservation queue automation, and cloud system hosting. All transactions and platform charges are detailed in the audit trail below.
  </div>

  <table>
    <thead>
      <tr>
        <th style="width: 28px; text-align: center;">#</th>
        <th style="width: 140px;">Date & Time</th>
        <th style="width: 120px;">Txn / Ref #</th>
        <th>Customer & Schedule</th>
        <th style="text-align: right; width: 90px;">Gross Paid</th>
        <th style="text-align: right; width: 90px;">Service Fee</th>
        <th style="text-align: right; width: 90px;">Net to Owner</th>
      </tr>
    </thead>
    <tbody>
      $rowsHtml
    </tbody>
  </table>

  <div class="totals-banner" style="display: flex; flex-direction: column; gap: 8px; padding: 12px 16px;">
    <div style="display: flex; justify-content: space-between; align-items: center;">
      <div style="font-weight: 700;">TOTAL STATEMENT SUMMARY (${transactions.length} Bookings)</div>
      <div>
        <span style="color: #93c5fd; margin-right: 14px; font-size: 11px;">Online ($onlineCount): ${_formatCurrency(onlineFees)}</span>
        <span style="color: #ddd6fe; font-size: 11px;">Offline ($offlineCount): ${_formatCurrency(offlineFees)}</span>
      </div>
    </div>
    <div style="border-top: 1px solid #2d6a4f; padding-top: 8px; display: flex; justify-content: space-between; align-items: center;">
      <div style="font-size: 11px; color: #9ca3af; text-transform: uppercase; font-weight: 600;">Platform Service Fee Total Due</div>
      <div style="color: #a7e23a; font-size: 13px; font-weight: 900;">NET PAYABLE (SERVICE CHARGE): ${_formatCurrency(totalServiceFee)}</div>
    </div>
  </div>

  <div class="signatures">
    <div class="sign-col">
      <div class="info-label">Prepared & Certified By</div>
      <div class="sign-line"></div>
      <div style="font-weight: 700;">PickleBook Billing Division</div>
      <div style="color: #6b7280; font-size: 10px;">Picklebook By Dynamics Software Solutions</div>
    </div>
    <div class="sign-col" style="text-align: right;">
      <div class="info-label">Received & Acknowledged By</div>
      <div class="sign-line"></div>
      <div style="font-weight: 700;">$displayName</div>
      <div style="color: #6b7280; font-size: 10px;">Authorized Facility Representative</div>
    </div>
  </div>

  <div style="text-align: center; color: #9ca3af; font-size: 9.5px; margin-top: 24px;">
    Official Statement of Account Generated by Picklebook By Dynamics Software Solutions • $todayStr
  </div>
</body>
</html>
    ''';
  }
}

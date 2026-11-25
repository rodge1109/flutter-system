import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_project/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/download_helper_stub.dart'
    if (dart.library.html) '../utils/download_helper_web.dart' as dl_helper;
import 'dashboard_screen.dart';

class BookingConfirmationScreen extends StatelessWidget {
  static final GlobalKey _receiptKey = GlobalKey();

  final String courtName;
  final String courtAddress;
  final String? courtImage;
  final DateTime bookingDate;
  final List<String> timeSlots;
  final String courtNumber;
  final double totalPaid;
  final String? bookingId;
  final String? playerName;
  final String? customerEmail;
  final String? customerPhone;
  final String? paymentMethod;
  final double? courtFee;
  final double? processingFee;
  final String? bookingReference;
  final String? bookingStatus;

  const BookingConfirmationScreen({
    Key? key,
    required this.courtName,
    this.courtAddress = 'Cayang',
    this.courtImage,
    required this.bookingDate,
    required this.timeSlots,
    required this.courtNumber,
    required this.totalPaid,
    this.bookingId,
    this.playerName,
    this.customerEmail,
    this.customerPhone,
    this.paymentMethod,
    this.courtFee,
    this.processingFee,
    this.bookingReference,
    this.bookingStatus,
  }) : super(key: key);

  String get _effectiveReference {
    if (bookingReference != null && bookingReference!.trim().isNotEmpty) {
      return bookingReference!.trim();
    }
    if (bookingId != null && bookingId!.trim().isNotEmpty) {
      final bId = bookingId!.trim();
      if (bId.startsWith('BK-') || bId.startsWith('#PB-')) {
        return bId;
      }
      final clean = bId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
      return 'BK-${clean.length >= 8 ? clean.substring(0, 8) : clean.padLeft(8, '0')}';
    }
    return 'BK-97CDD58E';
  }

  double get _effectiveProcessingFee {
    if (processingFee != null && processingFee! > 0) return processingFee!;
    if (totalPaid > 20) return 20.0;
    return 15.0;
  }

  double get _effectiveCourtFee {
    if (courtFee != null && courtFee! > 0) return courtFee!;
    final pFee = _effectiveProcessingFee;
    final calculated = totalPaid - pFee;
    return calculated > 0 ? calculated : totalPaid;
  }

  String get _paymentMethodLabel {
    final m = (paymentMethod ?? 'QRPH').toUpperCase();
    if (m.contains('QRPH') || m.contains('QR PH')) return 'Paid with QRPH';
    if (m.contains('MAYA')) return 'Paid with Maya';
    if (m.contains('GCASH')) return 'Paid with GCash';
    if (m.contains('CASH')) return 'Paid with Cash';
    return 'Paid with ${paymentMethod ?? 'QRPH'}';
  }

  String get _displayPlayerName {
    if (playerName != null && playerName!.trim().isNotEmpty) {
      return playerName!.trim();
    }
    return 'Kurt Yves J Mier';
  }

  String get _displayPhone {
    if (customerPhone != null && customerPhone!.trim().isNotEmpty) {
      return customerPhone!.trim();
    }
    return '09173209997';
  }

  String get _displayEmail {
    if (customerEmail != null && customerEmail!.trim().isNotEmpty) {
      return customerEmail!.trim();
    }
    return 'vashavery@gmail.com';
  }

  String get _effectiveCourtTitle {
    if (courtNumber.isNotEmpty) {
      if (courtNumber.toLowerCase().contains('court')) {
        return courtNumber;
      }
      return 'Pickleball Court $courtNumber';
    }
    if (courtName.isNotEmpty) {
      return courtName;
    }
    return 'Pickleball Court 1';
  }

  String _formatCurrency(double amount) {
    if (amount == amount.roundToDouble()) {
      return '₱${amount.toInt()}';
    }
    return '₱${amount.toStringAsFixed(2)}';
  }

  String _formatDateAndTimeslot() {
    final List<String> weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final List<String> months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final String datePart = '${weekdays[bookingDate.weekday - 1]}, ${months[bookingDate.month - 1]} ${bookingDate.day}';

    if (timeSlots.isEmpty) return '$datePart • 7 – 9 PM';

    String timePart = _formatCompactTimeRange(timeSlots);
    return '$datePart • $timePart';
  }

  String _formatCompactTimeRange(List<String> slots) {
    if (slots.isEmpty) return '7 – 9 PM';

    String first = slots.first;
    String last = slots.last;

    if (first.contains(': ')) {
      first = first.substring(first.indexOf(': ') + 2).trim();
    }
    if (last.contains(': ')) {
      last = last.substring(last.indexOf(': ') + 2).trim();
    }

    String startStr = '';
    String endStr = '';

    if (slots.length == 1 && first.contains('-')) {
      final parts = first.split('-');
      startStr = parts[0].trim();
      endStr = parts[1].trim();
    } else {
      startStr = first.contains('-') ? first.split('-')[0].trim() : first;
      if (last.contains('-')) {
        endStr = last.split('-')[1].trim();
      } else {
        endStr = _getEndTime(last);
      }
    }

    return _simplifyTimeRange(startStr, endStr);
  }

  String _simplifyTimeRange(String start, String end) {
    final cleanStart = start.replaceAll(' ', '');
    final cleanEnd = end.replaceAll(' ', '');

    final regStart = RegExp(r'^(\d+)(?::(\d+))?(AM|PM)$', caseSensitive: false).firstMatch(cleanStart);
    final regEnd = RegExp(r'^(\d+)(?::(\d+))?(AM|PM)$', caseSensitive: false).firstMatch(cleanEnd);

    if (regStart != null && regEnd != null) {
      final startH = regStart.group(1)!;
      final startM = regStart.group(2) ?? '00';
      final startP = regStart.group(3)!.toUpperCase();

      final endH = regEnd.group(1)!;
      final endM = regEnd.group(2) ?? '00';
      final endP = regEnd.group(3)!.toUpperCase();

      final formattedStart = startM == '00' ? startH : '$startH:$startM';
      final formattedEnd = endM == '00' ? endH : '$endH:$endM';

      if (startP == endP) {
        return '$formattedStart – $formattedEnd $endP';
      } else {
        return '$formattedStart $startP – $formattedEnd $endP';
      }
    }

    return '$start – $end';
  }

  String _getEndTime(String timeStr) {
    try {
      String clean = timeStr.trim();
      if (clean.contains(': ')) {
        clean = clean.substring(clean.indexOf(': ') + 2).trim();
      }
      final parts = clean.split(' ');
      if (parts.length < 2) return clean;
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      String ampm = parts[1].toUpperCase();

      int nextHour = hour + 1;
      if (nextHour == 12) {
        if (ampm == 'AM') {
          ampm = 'PM';
        } else if (ampm == 'PM') {
          ampm = 'AM';
        }
      } else if (nextHour > 12) {
        nextHour = 1;
      }
      return '$nextHour:00 $ampm';
    } catch (_) {
      return timeStr;
    }
  }

  String _getEffectiveLogoUrl() {
    if (courtImage != null && courtImage!.trim().isNotEmpty && (courtImage!.startsWith('http') || courtImage!.startsWith('assets/'))) {
      return courtImage!.trim();
    }
    final lower = courtName.toLowerCase().trim();
    if (lower.contains('secret drill')) {
      return 'https://res.cloudinary.com/doxih7ab3/image/upload/v1789448067/queuing-system-uploads/1789448065121-775511.png';
    } else if (lower.contains('aminova')) {
      return 'https://res.cloudinary.com/doxih7ab3/image/upload/v1789125140/queuing-system-uploads/1789125139763-564349.png';
    } else if (lower.contains('red goose')) {
      return 'https://res.cloudinary.com/doxih7ab3/image/upload/v1789378850/queuing-system-uploads/1789378849892-247549.jpg';
    } else if (lower.contains('mars valley')) {
      return 'https://res.cloudinary.com/doxih7ab3/image/upload/v1790397709/queuing-system-uploads/1790397707787-333465.jpg';
    } else if (lower.contains('7ten')) {
      return 'https://res.cloudinary.com/doxih7ab3/image/upload/v1791332551/queuing-system-uploads/1791332549537-526555.jpg';
    } else if (lower.contains('nhp')) {
      return 'https://res.cloudinary.com/doxih7ab3/image/upload/v1784821986/queuing-system-uploads/1784821985216-132187.jpg';
    }
    return '';
  }

  Widget _buildTopBarVenueLogo() {
    final logo = _getEffectiveLogoUrl();
    if (logo.isNotEmpty) {
      if (logo.startsWith('assets/')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            logo,
            width: 38,
            height: 38,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallbackLogoBadge(38),
          ),
        );
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          logo,
          width: 38,
          height: 38,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackLogoBadge(38),
        ),
      );
    }
    return _buildFallbackLogoBadge(38);
  }

  Widget _buildFallbackLogoBadge(double size) {
    final displayInitials = courtName.isNotEmpty
        ? (courtName.length >= 4 ? courtName.substring(0, 4).toUpperCase() : courtName.toUpperCase())
        : 'LIMA';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          displayInitials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 10,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildVenueCardLogo({double size = 42}) {
    final logo = _getEffectiveLogoUrl();
    if (logo.isNotEmpty) {
      if (logo.startsWith('assets/')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(size / 2),
          child: Image.asset(
            logo,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallbackCircleBadge(size),
          ),
        );
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          logo,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackCircleBadge(size),
        ),
      );
    }
    return _buildFallbackCircleBadge(size);
  }

  Widget _buildFallbackCircleBadge(double size) {
    final displayInitials = courtName.isNotEmpty
        ? (courtName.length >= 4 ? courtName.substring(0, 4).toUpperCase() : courtName.toUpperCase())
        : 'LIMA';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          displayInitials,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: size * 0.28,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  void _copyReference(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _effectiveReference));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
            SizedBox(width: 10),
            Text('Booking reference copied to clipboard!'),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleBookAnotherCourt(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context, 'book_another');
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    }
  }

  String _generateBookingUrl() {
    String baseOrigin = 'https://www.picklebook-ph.com';
    if (kIsWeb) {
      try {
        final origin = Uri.base.origin;
        if (origin.isNotEmpty && origin.startsWith('http')) {
          baseOrigin = origin;
        }
      } catch (_) {}
    }

    if (bookingId != null && bookingId!.trim().isNotEmpty) {
      return '$baseOrigin/b/${bookingId!.trim()}';
    }
    return '$baseOrigin/b/$_effectiveReference';
  }

  void _shareBookingLink(BuildContext context) {
    final String url = _generateBookingUrl();
    final String timeStr = _formatDateAndTimeslot();
    final String shareText =
        '🎾 Pickleball Match Reserved!\n'
        '🏟️ Venue: $courtName ($_effectiveCourtTitle)\n'
        '⏰ When: $timeStr\n'
        '🔖 Ref: $_effectiveReference\n\n'
        '👉 View Schedule & Match Pass:\n$url';

    Share.share(shareText);
  }

  Future<void> _downloadReceiptImage(BuildContext context) async {
    try {
      final boundary = _receiptKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not generate receipt image.')),
        );
        return;
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List? bytes = byteData?.buffer.asUint8List();

      if (bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not convert receipt to image.')),
        );
        return;
      }

      final String filename = 'picklebook_${_effectiveReference}.png';

      if (kIsWeb) {
        dl_helper.downloadFileFromBytes(bytes, filename, mimeType: 'image/png');
      } else {
        final xFile = XFile.fromData(bytes, name: filename, mimeType: 'image/png');
        await Share.shareXFiles([xFile], text: '🎾 Pickleball Booking Pass for $courtName');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
              SizedBox(width: 10),
              Text('Booking pass saved!'),
            ],
          ),
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download image: $e')),
      );
    }
  }

  void _showGetAppNotice(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('PickleBook mobile app is available on iOS and Android!'),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F4FD),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Navigation Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Venue logo / badge
                    _buildTopBarVenueLogo(),

                    // Right actions: "Get the app" and "Log in"
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () => _showGetAppNotice(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Get the app',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF4B5563),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0091FF),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Text(
                            'Log in',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Celebration Party Popper Emoji
              const Center(
                child: Text(
                  '🎉',
                  style: TextStyle(fontSize: 48),
                ),
              ),

              const SizedBox(height: 14),

              // Main Headline
              const Text(
                "You're on the court!",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 6),

              // Subtitle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  'We sent your booking to $_displayEmail.',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 24),

              // Main Confirmation Card (Enclosed in RepaintBoundary for pass saving)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: RepaintBoundary(
                  key: _receiptKey,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withOpacity(0.05),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Venue header row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _buildVenueCardLogo(size: 42),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    courtName.isNotEmpty ? courtName : 'LIMA Badminton and Pickleball Club',
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    courtAddress.isNotEmpty ? courtAddress : 'Lima Badminton and Pickleball Club',
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        // Highlighted Booking Reference Container
                        InkWell(
                          onTap: () => _copyReference(context),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F2FA),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Booking reference',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _effectiveReference,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.0,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Show this at the front desk.',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Court & Schedule Line Item
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _effectiveCourtTitle,
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _formatDateAndTimeslot(),
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 13,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _formatCurrency(_effectiveCourtFee),
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        // Metadata Two-Column Row (Booked by & Mobile)
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Booked by',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 12,
                                      color: Color(0xFF94A3B8),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _displayPlayerName,
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Mobile',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 12,
                                      color: Color(0xFF94A3B8),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _displayPhone,
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),
                        const Divider(color: Color(0xFFF1F5F9), thickness: 1, height: 1),
                        const SizedBox(height: 14),

                        // Breakdown Rows (Courts & Processing fee)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Courts',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              _formatCurrency(_effectiveCourtFee),
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                color: Color(0xFF475569),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Processing fee',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              _formatCurrency(_effectiveProcessingFee),
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                color: Color(0xFF475569),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Total Paid Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total paid',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _paymentMethodLabel,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              _formatCurrency(totalPaid),
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Bottom Button: "Book another court"
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => _handleBookAnotherCourt(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD6EAF8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: const Text(
                      'Book another court',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Subtle Share / Download actions
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: () => _shareBookingLink(context),
                      icon: const Icon(Icons.share_rounded, size: 15, color: Color(0xFF64748B)),
                      label: const Text(
                        'Share pass',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('•', style: TextStyle(color: Color(0xFFCBD5E1))),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _downloadReceiptImage(context),
                      icon: const Icon(Icons.download_rounded, size: 15, color: Color(0xFF64748B)),
                      label: const Text(
                        'Download image',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

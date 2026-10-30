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
  }) : super(key: key);

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
    final uri = Uri.parse('$baseOrigin/b').replace(queryParameters: {
      'court': courtName,
      'address': courtAddress,
      'date': _formatDate(bookingDate),
      'time': _formatTimeRange(timeSlots),
      'courtNum': courtNumber,
      'price': totalPaid.toStringAsFixed(2),
      if (playerName != null && playerName!.isNotEmpty) 'name': playerName!,
    });
    return uri.toString();
  }

  void _shareBookingLink(BuildContext context) {
    final String url = _generateBookingUrl();
    final String formattedDate = _formatDate(bookingDate);
    final String timeStr = _formatTimeRange(timeSlots);
    final String shareText =
        '🎾 Pickleball Match Reserved!\n'
        '🏟️ Venue: $courtName ($courtNumber)\n'
        '📅 Date: $formattedDate\n'
        '⏰ Time: $timeStr\n'
        '📍 Address: $courtAddress\n\n'
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

      final String filename = 'picklebook_receipt_${bookingId?.trim().isNotEmpty == true ? bookingId!.trim() : DateTime.now().millisecondsSinceEpoch}.png';

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
              Icon(Icons.check_circle_rounded, color: AppColors.accentLime, size: 20),
              SizedBox(width: 10),
              Text('Receipt image downloaded / saved!'),
            ],
          ),
          backgroundColor: AppColors.richBlack,
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

  void _copyBookingLink(BuildContext context) {
    final String url = _generateBookingUrl();
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: AppColors.accentLime, size: 20),
            SizedBox(width: 10),
            Text('Booking pass link copied to clipboard!'),
          ],
        ),
        backgroundColor: AppColors.richBlack,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final List<String> months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final List<String> weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    
    String monthStr = months[date.month - 1];
    String weekdayStr = weekdays[date.weekday - 1];
    return '$monthStr ${date.day}, ${date.year} ($weekdayStr)';
  }

  String _formatTimeRange(List<String> slots) {
    if (slots.isEmpty) return '9:00 AM - 10:00 AM';

    final hasMultipleCourts = slots.any((s) => s.contains(': '));
    if (hasMultipleCourts) {
      return slots.map((s) {
        String cName = '';
        String clean = s;
        if (s.contains(': ')) {
          int idx = s.indexOf(': ');
          cName = s.substring(0, idx).trim();
          clean = s.substring(idx + 2).trim();
        }
        String end = _getEndTime(clean);
        return cName.isNotEmpty ? '$cName: $clean - $end' : '$clean - $end';
      }).join('\n');
    }

    if (slots.length == 1) {
      String raw = slots.first;
      String clean = raw.contains(': ') ? raw.substring(raw.indexOf(': ') + 2).trim() : raw;
      String end = _getEndTime(clean);
      return '$clean - $end';
    }
    String rawFirst = slots.first;
    String rawLast = slots.last;
    String cleanFirst = rawFirst.contains(': ') ? rawFirst.substring(rawFirst.indexOf(': ') + 2).trim() : rawFirst;
    String cleanLast = rawLast.contains(': ') ? rawLast.substring(rawLast.indexOf(': ') + 2).trim() : rawLast;
    String end = _getEndTime(cleanLast);
    return '$cleanFirst - $end';
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

  @override
  Widget build(BuildContext context) {
    final String formattedDateStr = _formatDate(bookingDate);
    final String timeRangeStr = _formatTimeRange(timeSlots);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFDCE9D5),
            Color(0xFFF7F9F1),
            Color(0xFFECF3E9),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
        child: Column(
          children: [
            // Top Checkmark Graphics with Confetti Elements
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: [
                    const SizedBox(height: 8),

                    // Confetti and Checkmark Badge
                    SizedBox(
                      height: 96,
                      width: 140,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Floating Confetti Shapes
                          _buildConfetti(top: 8, left: 24, color: const Color(0xFFFACC15), size: 8, angle: 0.3),
                          _buildConfetti(top: 6, right: 22, color: const Color(0xFF3B82F6), size: 6, angle: -0.4),
                          _buildConfetti(top: 32, left: 10, color: const Color(0xFFF97316), size: 8, angle: 0.8),
                          _buildConfetti(top: 40, right: 10, color: AppColors.accentLime, size: 7, angle: -0.2),
                          _buildConfetti(bottom: 12, left: 18, color: const Color(0xFFFACC15), size: 8, angle: -0.5),
                          _buildConfetti(bottom: 14, right: 18, color: AppColors.accentLime, size: 7, angle: 0.6),

                          // Outer Pulsing Halo
                          Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF0E6E59).withOpacity(0.5),
                            ),
                          ),

                          // Inner Glow Ring
                          Container(
                            width: 60,
                            height: 60,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF0E6E59),
                            ),
                          ),

                          // Center Solid Check Circle
                          Container(
                            width: 46,
                            height: 46,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.accentLime,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: AppColors.softWhite,
                              size: 30,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Title
                    Text(
                      'Booking Confirmed!',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.richBlack,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 4),

                    // Subtitle
                    Text(
                      'Your court is reserved.',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: AppColors.richBlack.withOpacity(0.54),
                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 14),

                    // Unified POS Paper Receipt & Match Pass
                    _buildUnifiedPosReceipt(context, formattedDateStr, timeRangeStr),

                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),

            // Bottom Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Column(
                children: [
                  // View My Bookings Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context, 'view_bookings');
                        } else {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const DashboardScreen(initialNavIndex: 2)),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'View My Bookings',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Back to Home Button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context, 'home');
                        } else {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const DashboardScreen()),
                          );
                        }
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                      child: Text(
                        'Back to Home',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.richBlack,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
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

  Widget _buildVenueLogo({double size = 48}) {
    final logo = _getEffectiveLogoUrl();
    if (logo.isNotEmpty) {
      if (logo.startsWith('assets/')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            logo,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildDefaultThumbnail(size: size),
          ),
        );
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          logo,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildDefaultThumbnail(size: size),
        ),
      );
    }
    return _buildDefaultThumbnail(size: size);
  }

  Widget _buildDefaultThumbnail({double size = 48}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Image.asset(
          'assets/app_icon.png',
          width: size * 0.7,
          height: size * 0.7,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Container(
            color: AppColors.primaryGreen,
            child: const Icon(Icons.sports_tennis, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }

  Widget _buildConfetti({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required Color color,
    required double size,
    required double angle,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: size,
          height: size * 1.5,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildUnifiedPosReceipt(BuildContext context, String formattedDateStr, String timeRangeStr) {
    const double toothWidth = 9.0;
    const double toothHeight = 4.5;
    const double radius = 14.0;

    return RepaintBoundary(
      key: _receiptKey,
      child: CustomPaint(
        painter: _PosPaperPainter(
          toothWidth: toothWidth,
          toothHeight: toothHeight,
          radius: radius,
        ),
      child: ClipPath(
        clipper: _PosPaperClipper(
          toothWidth: toothWidth,
          toothHeight: toothHeight,
          radius: radius,
        ),
        child: Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Venue Header with Logo
              Row(
                children: [
                  _buildVenueLogo(size: 46),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          courtName.isNotEmpty ? courtName : 'Smash Zone Pickleball',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.richBlack,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          courtAddress,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              Divider(height: 1, color: Colors.grey.shade200),
              const SizedBox(height: 12),

              // Booking Details
              Text(
                formattedDateStr,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.richBlack,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                timeRangeStr,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.richBlack,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                courtNumber.isNotEmpty ? courtNumber : 'Court 1',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.richBlack,
                ),
              ),

              const SizedBox(height: 12),
              Divider(height: 1, color: Colors.grey.shade200),
              const SizedBox(height: 12),

              // Total Paid Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Paid',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'P${totalPaid.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.richBlack,
                    ),
                  ),
                ],
              ),

              // Perforated Tear-off line
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _buildDashedDivider(),
              ),

              // Share Schedule with Buddies Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.share_rounded,
                      color: AppColors.primaryGreen,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Share Schedule with Buddies',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.richBlack,
                          ),
                        ),
                        Text(
                          'Let your group see the timeslot & court pass',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Link preview pill + Copy button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link_rounded, size: 15, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _generateBookingUrl(),
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: () => _copyBookingLink(context),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.copy_rounded, size: 13, color: AppColors.primaryGreen),
                            const SizedBox(width: 3),
                            Text(
                              'Copy',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Share & Download Action Row
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _shareBookingLink(context),
                      icon: const Icon(Icons.send_rounded, size: 14),
                      label: const Text(
                        'Share Booking Link',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Download Receipt Photo',
                    child: ElevatedButton(
                      onPressed: () => _downloadReceiptImage(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        minimumSize: const Size(42, 34),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        elevation: 0,
                      ),
                      child: const Icon(Icons.file_download_outlined, size: 17),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildDashedDivider({Color? color, double height = 1.0, double dashWidth = 5.0, double dashSpace = 3.5}) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final boxWidth = constraints.constrainWidth();
        final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: height,
              child: DecoratedBox(
                decoration: BoxDecoration(color: color ?? Colors.grey.shade300),
              ),
            );
          }),
        );
      },
    );
  }
}

Path _createPosPaperPath(Size size, double toothWidth, double toothHeight, double radius) {
  final path = Path();
  final w = size.width;
  final h = size.height;
  final baseH = h - toothHeight;

  // Top-left corner
  path.moveTo(0, radius);
  path.quadraticBezierTo(0, 0, radius, 0);

  // Top edge
  path.lineTo(w - radius, 0);

  // Top-right corner
  path.quadraticBezierTo(w, 0, w, radius);

  // Right edge down to baseH
  path.lineTo(w, baseH);

  // Sawtooth teeth across bottom edge from right to left
  final int count = (w / toothWidth).floor().clamp(10, 100);
  final double actualWidth = w / count;

  for (int i = 0; i < count; i++) {
    final double rightX = w - (i * actualWidth);
    final double midX = rightX - (actualWidth / 2);
    final double leftX = rightX - actualWidth;

    path.lineTo(midX, h);
    path.lineTo(leftX, baseH);
  }

  // Left edge up to top-left corner
  path.lineTo(0, radius);
  path.close();

  return path;
}

class _PosPaperClipper extends CustomClipper<Path> {
  final double toothWidth;
  final double toothHeight;
  final double radius;

  _PosPaperClipper({this.toothWidth = 9.0, this.toothHeight = 4.5, this.radius = 14.0});

  @override
  Path getClip(Size size) => _createPosPaperPath(size, toothWidth, toothHeight, radius);

  @override
  bool shouldReclip(covariant _PosPaperClipper oldClipper) =>
      oldClipper.toothWidth != toothWidth ||
      oldClipper.toothHeight != toothHeight ||
      oldClipper.radius != radius;
}

class _PosPaperPainter extends CustomPainter {
  final double toothWidth;
  final double toothHeight;
  final double radius;

  _PosPaperPainter({this.toothWidth = 9.0, this.toothHeight = 4.5, this.radius = 14.0});

  @override
  void paint(Canvas canvas, Size size) {
    final path = _createPosPaperPath(size, toothWidth, toothHeight, radius);

    // Realistic paper shadow
    canvas.drawShadow(path, Colors.black.withOpacity(0.06), 6.0, true);

    // Subtle paper edge border
    final borderPaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _PosPaperPainter oldDelegate) => false;
}

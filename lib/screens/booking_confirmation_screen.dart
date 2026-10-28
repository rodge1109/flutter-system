import 'package:flutter_project/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/custom_paddle_icon.dart';

class BookingConfirmationScreen extends StatelessWidget {
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
    if (bookingId != null && bookingId!.trim().isNotEmpty) {
      return 'https://pickle-system.onrender.com/b/${bookingId!.trim()}';
    }
    final uri = Uri.parse('https://pickle-system.onrender.com/b').replace(queryParameters: {
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

    SharePlus.instance.share(shareText, subject: '🎾 PickleBook Match Pass: $courtName');
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

    return Scaffold(
      backgroundColor: AppColors.softWhite,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            
            // Top Checkmark Graphics with Confetti Elements
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 24),

                    // Confetti and Checkmark Badge
                    SizedBox(
                      height: 184,
                      width: 200,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Floating Confetti Shapes
                          _buildConfetti(top: 20, left: 35, color: const Color(0xFFFACC15), size: 10, angle: 0.3),
                          _buildConfetti(top: 15, right: 30, color: const Color(0xFF3B82F6), size: 8, angle: -0.4),
                          _buildConfetti(top: 50, left: 15, color: const Color(0xFFF97316), size: 12, angle: 0.8),
                          _buildConfetti(top: 65, right: 15, color: AppColors.accentLime, size: 10, angle: -0.2),
                          _buildConfetti(bottom: 25, left: 25, color: const Color(0xFFFACC15), size: 12, angle: -0.5),
                          _buildConfetti(bottom: 30, right: 25, color: AppColors.accentLime, size: 9, angle: 0.6),

                          // Outer Pulsing Halo
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF0E6E59).withOpacity(0.5),
                            ),
                          ),

                          // Inner Glow Ring
                          Container(
                            width: 110,
                            height: 110,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF0E6E59),
                            ),
                          ),

                          // Center Solid Check Circle
                          Container(
                            width: 85,
                            height: 85,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.accentLime,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: AppColors.softWhite,
                              size: 54,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Title
                    Text(
                      'Booking Confirmed!',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.richBlack,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 8),

                    // Subtitle
                    Text(
                      'Your court is reserved.',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        color: AppColors.richBlack.withOpacity(0.54),
                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 32),

                    // Summary White Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Court Info Header (Image + Title + Location)
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: courtImage != null && courtImage!.startsWith('http')
                                    ? Image.network(
                                        courtImage!,
                                        width: 65,
                                        height: 65,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => _buildDefaultThumbnail(),
                                      )
                                    : _buildDefaultThumbnail(),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      courtName.isNotEmpty ? courtName : 'Smash Zone Pickleball',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.richBlack,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      courtAddress,
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 13,
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

                          const SizedBox(height: 16),
                          Divider(height: 1, color: Colors.grey.shade200),
                          const SizedBox(height: 16),

                          // Booking Details
                          Text(
                            formattedDateStr,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.richBlack,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            timeRangeStr,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.richBlack,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            courtNumber.isNotEmpty ? courtNumber : 'Court 1',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.richBlack,
                            ),
                          ),

                          const SizedBox(height: 16),
                          Divider(height: 1, color: Colors.grey.shade200),
                          const SizedBox(height: 16),

                          // Total Paid Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Paid',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 15,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                'P${totalPaid.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.richBlack,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Share Match Pass with Buddies Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.accentLime.withOpacity(0.6), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGreen.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.share_rounded,
                                  color: AppColors.primaryGreen,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Share Schedule with Buddies',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 14,
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
                          const SizedBox(height: 14),

                          // Link preview pill + Copy button
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.link_rounded, size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
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
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.copy_rounded, size: 14, color: AppColors.primaryGreen),
                                        const SizedBox(width: 4),
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

                          const SizedBox(height: 12),

                          // Share Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _shareBookingLink(context),
                              icon: const Icon(Icons.send_rounded, size: 16),
                              label: const Text(
                                'Share Match Pass Link',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
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

            // Bottom Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  // View My Bookings Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context, 'view_bookings');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentLime,
                        foregroundColor: AppColors.richBlack,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'View My Bookings',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.richBlack,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Back to Home Button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context, 'home');
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        'Back to Home',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
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
    );
  }

  Widget _buildDefaultThumbnail() {
    return Container(
      width: 65,
      height: 65,
      decoration: BoxDecoration(
        color: Colors.green.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: CustomPaddleIcon(
          color: Color(0xFF0F5B2A),
          size: 32,
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
}

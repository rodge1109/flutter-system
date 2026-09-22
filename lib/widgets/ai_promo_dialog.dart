import 'package:flutter/material.dart';
import '../screens/ai_promo_screen.dart';

class AiPromoDialog extends StatelessWidget {
  final String venueName;
  final List<dynamic> courts;
  final List<dynamic> todayBookings;
  final String ownerEmail;

  const AiPromoDialog({
    super.key,
    required this.venueName,
    required this.courts,
    required this.todayBookings,
    required this.ownerEmail,
  });

  @override
  Widget build(BuildContext context) {
    return AiPromoScreen(
      venueName: venueName,
      courts: courts,
      todayBookings: todayBookings,
      ownerEmail: ownerEmail,
    );
  }
}

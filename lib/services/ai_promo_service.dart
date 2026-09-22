import 'dart:convert';
import 'package:http/http.dart' as http;

class AiPromoService {
  // Optional default API key fallback; users/owners can also override
  static const String _geminiEndpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  /// Calculate open time slots for today given list of courts and existing bookings
  List<String> getTodayOpenSlots({
    required List<dynamic> courts,
    required List<dynamic> todayBookings,
    int startHour = 6, // 6 AM
    int endHour = 22,  // 10 PM
  }) {
    List<String> openSlots = [];

    // Collect all booked time strings for today
    Set<String> bookedTimes = {};
    for (var b in todayBookings) {
      if (b['status'] == 'cancelled' || b['status'] == 'rejected') continue;
      final timeStr = (b['appointment_time'] ?? '').toString().trim();
      if (timeStr.isNotEmpty) {
        bookedTimes.add(timeStr.toLowerCase());
      }
    }

    // Generate slot windows
    for (int hour = startHour; hour < endHour; hour++) {
      final startPeriod = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      final nextHour = hour + 1;
      final nextDisplayHour = nextHour > 12 ? nextHour - 12 : (nextHour == 0 ? 12 : nextHour);
      final nextPeriod = nextHour >= 12 ? 'PM' : 'AM';

      final slotLabel = '$displayHour:00 $startPeriod - $nextDisplayHour:00 $nextPeriod';
      final altSlotLabel = '$displayHour:00$startPeriod-$nextDisplayHour:00$nextPeriod';

      // Check if any booking matches this hour window
      bool isBooked = bookedTimes.any((bt) => 
        bt.contains('$displayHour:00') || 
        bt.contains('$displayHour $startPeriod') ||
        bt.contains(altSlotLabel.toLowerCase())
      );

      if (!isBooked) {
        openSlots.add(slotLabel);
      }
    }

    return openSlots;
  }

  /// Generate AI Facebook Promo Caption using Gemini 1.5 Flash API with local template fallback
  Future<String> generateFacebookPromoCaption({
    required String venueName,
    required List<String> openSlots,
    required String basePrice,
    required String bookingUrl,
    String? apiKey,
  }) async {
    final slotsFormatted = openSlots.isNotEmpty
        ? openSlots.map((s) => '• $s').join('\n')
        : '• Flexible evening slots available!';

    final prompt = '''
You are a professional social media manager for a sports & pickleball facility named "$venueName".
Write an engaging, high-converting Facebook post announcing today's open court slots.

Details:
- Venue Name: $venueName
- Open Slots Today:
$slotsFormatted
- Court Rate: ₱$basePrice / hour
- Direct Booking Link: $bookingUrl

Requirements:
- Add exciting emojis (e.g. 🏓, ⚡, 📍, ⏰, 📱).
- Keep it concise, friendly, and urge players to book before slots fill up.
- Include a clear Call To Action pointing to the booking link.
- Do NOT include markdown code blocks like ```. Just output the post text directly.
''';

    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        final response = await http.post(
          Uri.parse('$_geminiEndpoint?key=$apiKey'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'contents': [
              {
                'parts': [
                  {'text': prompt}
                ]
              }
            ],
            'generationConfig': {
              'temperature': 0.7,
              'maxOutputTokens': 500,
            }
          }),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final String? text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
          if (text != null && text.trim().isNotEmpty) {
            return text.trim();
          }
        }
      } catch (e) {
        print('Gemini API call failed, falling back to smart template: $e');
      }
    }

    // High-quality local AI-styled fallback
    return '''🏓 LAST-MINUTE COURT SLOTS AVAILABLE TODAY AT ${venueName.toUpperCase()}! ⚡

Looking for a game today? We still have prime pickleball court slots open for you and your friends!

⏰ AVAILABLE SLOTS TODAY:
${openSlots.take(5).map((s) => '👉 $s').join('\n')}

📍 Venue: $venueName
💰 Rates starting at ₱$basePrice/hr

📱 Secure your court in seconds before slots fill up!
👇 Book Online Now:
$bookingUrl

#Pickleball #OpenCourt #$venueName #PickleballLife #BookNow''';
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final email = 'rodge.tonacao@gmail.com';
  final url = 'http://localhost:5000/api/user/bookings/${Uri.encodeComponent(email)}';
  
  try {
    final res = await http.get(Uri.parse(url));
    print('Status: ${res.statusCode}');
    
    final data = json.decode(res.body);
    final bookings = data['bookings'] as List<dynamic>;
    print('Raw bookings count: ${bookings.length}');
    
    final now = DateTime.now();
    final upcoming = [];
    final past = [];

    for (var b in bookings) {
      if (b['status'] == 'cancelled') continue;
      try {
        final dateStr = b['appointment_date'];
        final timeStr = b['appointment_time'];
        
        DateTime parsedUtc = DateTime.parse(dateStr.toString());
        DateTime localDate = parsedUtc.toLocal();
        String dateString = '${localDate.year}-${localDate.month.toString().padLeft(2, '0')}-${localDate.day.toString().padLeft(2, '0')}';
        
        String timeString = timeStr.toString().trim();
        int hour = int.parse(timeString.split(':')[0]);
        int minute = int.parse(timeString.split(':')[1].substring(0, 2));
        bool isPM = timeString.toUpperCase().contains('PM');
        
        if (isPM && hour < 12) hour += 12;
        if (!isPM && hour == 12) hour = 0;
        
        String hourStr = hour.toString().padLeft(2, '0');
        String minStr = minute.toString().padLeft(2, '0');
        
        final dt = DateTime.parse('$dateString $hourStr:$minStr:00');
        
        if (dt.isAfter(now)) {
          upcoming.add(b);
        } else {
          past.add(b);
        }
      } catch (e) {
        upcoming.add(b);
      }
    }
    
    print('Upcoming count: ${upcoming.length}');
    print('Past count: ${past.length}');
    
    for (var b in upcoming) {
      print('UPCOMING: ${b['appointment_date']} ${b['appointment_time']}');
    }
    for (var b in past) {
      print('PAST: ${b['appointment_date']} ${b['appointment_time']}');
    }
  } catch (e) {
    print('Error: $e');
  }
}

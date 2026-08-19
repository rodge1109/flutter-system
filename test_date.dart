void main() {
  final now = DateTime.now();
  final dateStr = "2026-08-08T16:00:00.000Z";
  final timeStr = "5:00 PM";
  
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
  
  print('now: $now');
  print('localDate: $localDate');
  print('dateString: $dateString');
  print('dt: $dt');
  print('isAfter: ${dt.isAfter(now)}');
}

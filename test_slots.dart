import 'package:http/http.dart' as http;

void main() async {
  final url = Uri.parse('https://pickle-system.onrender.com/api/available-slots?date=2026-09-20&serviceType=Lima%20PickleBall%20Court');
  final response = await http.get(url);
  print(response.body);
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'booking_screen.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
import 'splash_screen.dart';

class DeepLinkHandlerScreen extends StatefulWidget {
  final String slug;
  
  const DeepLinkHandlerScreen({Key? key, required this.slug}) : super(key: key);

  @override
  _DeepLinkHandlerScreenState createState() => _DeepLinkHandlerScreenState();
}

class _DeepLinkHandlerScreenState extends State<DeepLinkHandlerScreen> {
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _processDeepLink();
  }

  Future<void> _processDeepLink() async {
    try {
      final services = await _apiService.fetchRawServices();
      
      if (services.isNotEmpty) {
        final List<String> fallbackImages = [
          'https://res.cloudinary.com/doxih7ab3/image/upload/v1784821555/queuing-system-uploads/1784821552618-505155.jpg',
          'https://res.cloudinary.com/doxih7ab3/image/upload/v1784821986/queuing-system-uploads/1784821985216-132187.jpg',
          'https://res.cloudinary.com/doxih7ab3/image/upload/v1784904651/queuing-system-uploads/1784904649498-925226.jpg',
        ];

        List<Map<String, dynamic>> courts = services.asMap().entries.map((entry) {
            int idx = entry.key;
            var s = entry.value;
            String rawPrice = (s['price'] ?? '300').toString().replaceAll(RegExp(r'[^0-9.]'), '');
            if (rawPrice.isEmpty || rawPrice == '0') rawPrice = '300';
            else rawPrice = double.parse(rawPrice).toStringAsFixed(0);
            
            String addr = (s['address'] ?? '').toString().isNotEmpty ? s['address'] : ((s['description'] ?? '').toString().isNotEmpty ? s['description'] : 'Cayang, Bogo');

            String imageUrl = fallbackImages[idx % fallbackImages.length];
            String iconStr = (s['icon'] ?? '').toString();
            if (iconStr.startsWith('http') || iconStr.startsWith('/uploads')) {
              imageUrl = iconStr.startsWith('/uploads') ? 'https://pickle-system.onrender.com$iconStr' : iconStr;
            }
            
            return {
              'id': s['id'].toString(),
              'name': s['name'] ?? 'Court',
              'address': addr,
              'price': rawPrice,
              'image': imageUrl,
              'latitude': s['latitude'],
              'longitude': s['longitude'],
              'facilities': s['facilities'] ?? [],
              'ownerEmail': s['owner_email'] ?? s['email'] ?? '',
              'venueName': s['venue_name'] ?? s['venueName'] ?? '',
              'logo': s['logo_url'] ?? s['logo'] ?? '',
              'about_venue': s['about_venue'] ?? s['aboutVenue'] ?? '',
              'booking_policy': s['booking_policy'] ?? s['bookingPolicy'] ?? '',
              'faq': s['faq'] ?? '',
            };
        }).toList();

        // Group logic identical to dashboard_screen.dart
        Map<String, List<Map<String, dynamic>>> venueGroups = {};
        for (var court in courts) {
          String? explicitVenue = court['venue_name'] ?? court['venueName'] ?? court['venue'];
          String ownerEmail = court['email'] ?? court['owner_email'] ?? court['ownerEmail'] ?? '';
          
          String cleanVenueName = '';
          if (explicitVenue != null && explicitVenue.toString().trim().isNotEmpty) {
            cleanVenueName = explicitVenue.toString().trim();
          } else {
            String rawName = court['name'] ?? 'Court';
            String addr = court['address'] ?? 'Cayang, Bogo';
            cleanVenueName = rawName
                .replaceAll(RegExp(r'[-\s]*(Court|CT|#)\s*\d+.*$', caseSensitive: false), '')
                .trim();
            if (cleanVenueName.isEmpty || cleanVenueName.toLowerCase() == 'court') {
              cleanVenueName = addr.isNotEmpty ? addr : 'Pickleball & Tennis Venue';
            }
          }

          String venueKey = ownerEmail.isNotEmpty
              ? '${cleanVenueName}_$ownerEmail'.toLowerCase()
              : cleanVenueName.toLowerCase();

          if (!venueGroups.containsKey(venueKey)) {
            venueGroups[venueKey] = [];
          }
          venueGroups[venueKey]!.add(court);
        }

        List<Map<String, dynamic>> venueList = [];
        venueGroups.forEach((key, courtList) {
          final first = courtList.first;
          String vTitle = first['venue_name'] ?? first['venueName'] ?? first['venue'] ?? first['name'] ?? 'Venue';
          if (first['venue_name'] == null && first['venueName'] == null && first['venue'] == null && courtList.length > 1) {
            vTitle = first['name'].replaceAll(RegExp(r'[-\s]*(Court|CT|#)\s*\d+.*$', caseSensitive: false), '').trim();
            if (vTitle.isEmpty) vTitle = first['address'] ?? 'Sports Venue';
          }

          venueList.add({
            'venueKey': key,
            'venueName': vTitle,
            'address': first['address'] ?? 'Cayang, Bogo',
            'image': first['image'],
            'logo_url': first['logo_url'] ?? first['logo'],
            'rating': first['rating'] ?? '4.8',
            'distance': first['distance'] ?? '2.0 km away',
            'basePrice': '300', // simplified
            'sports': ['Pickleball'], // simplified
            'courts': courtList,
            'latitude': first['latitude'],
            'longitude': first['longitude'],
            'aboutVenue': first['aboutVenue'] ?? first['about_venue'],
            'bookingPolicy': first['bookingPolicy'] ?? first['booking_policy'],
            'faq': first['faq'],
          });
        });

        // Find match
        Map<String, dynamic>? matchedVenue;
        final searchSlug = widget.slug.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        
        for (var venue in venueList) {
          final vName = venue['venueName'].toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
          final vKey = venue['venueKey'].toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
          if (vName.contains(searchSlug) || vKey.contains(searchSlug) || searchSlug.contains(vName)) {
            matchedVenue = venue;
            break;
          }
        }

        if (!mounted) return;

        if (matchedVenue != null) {
          final prefs = await SharedPreferences.getInstance();
          final userStr = prefs.getString('user');
          
          Widget baseScreen = userStr != null ? DashboardScreen() : LoginScreen();
          
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => baseScreen),
            (route) => false,
          );
          
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => BookingScreen(
              venue: matchedVenue,
              initialServiceName: matchedVenue!['venueName'],
              skipServiceSelection: false,
            )
          ));
          return;
        }
      }
    } catch (e) {
      debugPrint('Error deep linking: $e');
    }

    if (mounted) {
      // Fallback
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SplashScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

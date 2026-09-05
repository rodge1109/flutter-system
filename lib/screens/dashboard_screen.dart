import 'package:flutter_project/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../widgets/custom_paddle_icon.dart';
import 'package:flutter/services.dart';
import '../widgets/pickleball_icon.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'booking_screen.dart';
import 'package:flutter/services.dart';
import 'all_open_plays_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';
import 'inbox_screen.dart';
import 'chat_screen.dart';
import 'map_route_screen.dart';
import 'manage_open_plays_screen.dart';
import 'open_challenges_screen.dart';
import 'manage_challenges_screen.dart';
import 'live_broadcast_screen.dart';
import 'booking_assistant_screen.dart';
import 'pasalo_courts_screen.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchCtrl = TextEditingController();
  
  String _userName = 'Roger';
  String _userEmail = '';
  List<dynamic> _upcomingBookings = [];
  List<dynamic> _pastBookings = [];
  List<dynamic> _courtsList = [];
  List<Map<String, dynamic>> _openPlays = [];
  List<Map<String, dynamic>> _openChallenges = [];
  List<Map<String, dynamic>> _pasaloCourts = [];
  List<Map<String, dynamic>> _outgoingPasaloRequests = [];
  int _unreadCount = 0;
  int _unreadMessageCount = 0;
  int _selectedNavIndex = 0;
  bool _isLoading = true;
  String _selectedSportCategory = 'ALL'; // 'ALL', 'Pickleball', 'Tennis'
  Set<String> _favoriteCourts = {};
  String _searchQuery = '';
  double _filterMaxPrice = 1000;
  double _filterMinRating = 0;
  int get _activeFilterCount => (_filterMaxPrice < 1000 ? 1 : 0) + (_filterMinRating > 0 ? 1 : 0);
  Position? _currentPosition;

  List<Map<String, dynamic>> _getGroupedVenues(List<Map<String, dynamic>> rawCourts) {
    Map<String, List<Map<String, dynamic>>> venueGroups = {};

    for (var court in rawCourts) {
      String rawName = court['name'] ?? 'Court';
      String addr = court['address'] ?? 'Cayang, Bogo';
      
      String cleanVenueName = rawName
          .replaceAll(RegExp(r'[-\s]*(Court|CT|#)\s*\d+.*$', caseSensitive: false), '')
          .trim();
      if (cleanVenueName.isEmpty || cleanVenueName.toLowerCase() == 'court') {
        cleanVenueName = addr.isNotEmpty ? addr : 'Pickleball & Tennis Venue';
      }

      String venueKey = cleanVenueName.toLowerCase();

      if (!venueGroups.containsKey(venueKey)) {
        venueGroups[venueKey] = [];
      }
      venueGroups[venueKey]!.add(court);
    }

    List<Map<String, dynamic>> venueList = [];

    venueGroups.forEach((key, courtList) {
      final first = courtList.first;
      
      Set<String> sportsSet = {};
      for (var c in courtList) {
        String desc = (c['description'] ?? '').toString().toLowerCase();
        String name = (c['name'] ?? '').toString().toLowerCase();
        if (name.contains('tennis') || desc.contains('tennis')) {
          sportsSet.add('Tennis');
        }
        if (name.contains('pickle') || desc.contains('pickle') || !name.contains('tennis')) {
          sportsSet.add('Pickleball');
        }
      }
      if (sportsSet.isEmpty) sportsSet.add('Pickleball');

      double lowestPrice = 9999;
      for (var c in courtList) {
        double p = double.tryParse((c['price'] ?? '300').toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 300;
        if (p < lowestPrice) lowestPrice = p;
      }
      if (lowestPrice == 9999) lowestPrice = 300;

      String vTitle = first['name'] ?? 'Venue';
      if (courtList.length > 1) {
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
        'basePrice': lowestPrice.toInt().toString(),
        'sports': sportsSet.toList(),
        'courts': courtList,
        'latitude': first['latitude'],
        'longitude': first['longitude'],
        'aboutVenue': first['aboutVenue'] ?? first['about_venue'],
        'bookingPolicy': first['bookingPolicy'] ?? first['booking_policy'],
        'faq': first['faq'],
      });
    });

    return venueList;
  }

  // Initial fallback nearby courts matching actual database records
  final List<Map<String, dynamic>> _sampleCourts = [
    {
      'id': '17',
      'name': 'Court 1',
      'address': 'Silica Sand Surface',
      'distance': '1.8 km away',
      'rating': '4.8',
      'price': '250',
      'image': 'https://res.cloudinary.com/doxih7ab3/image/upload/v1784821555/queuing-system-uploads/1784821552618-505155.jpg',
      'slots': ['8:00 AM', '10:00 AM', '1:00 PM', '4:00 PM'],
      'selectedSlot': '8:00 AM',
    },
    {
      'id': '15',
      'name': 'Court 2',
      'address': 'Cayang, Bogo',
      'distance': '2.5 km away',
      'rating': '4.9',
      'price': '300',
      'image': 'https://res.cloudinary.com/doxih7ab3/image/upload/v1784821986/queuing-system-uploads/1784821985216-132187.jpg',
      'slots': ['9:00 AM', '11:00 AM', '2:00 PM', '5:00 PM'],
      'selectedSlot': '9:00 AM',
    },
    {
      'id': '13',
      'name': 'Court 3 (Bamboo Groove)',
      'address': 'Cayang, Bogo',
      'distance': '3.2 km away',
      'rating': '4.7',
      'price': '300',
      'image': 'https://res.cloudinary.com/doxih7ab3/image/upload/v1784904651/queuing-system-uploads/1784904649498-925226.jpg',
      'slots': ['7:00 AM', '10:00 AM', '1:00 PM', '3:00 PM'],
      'selectedSlot': '7:00 AM',
    },
  ];

  @override
  void initState() {
    super.initState();
    _determinePosition();
    _loadUserData();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.toLowerCase().trim());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  Future<void> _navigateToBookingScreen({String? initialServiceName, bool skipServiceSelection = false, String? initialTime}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingScreen(
          initialServiceName: initialServiceName,
          skipServiceSelection: skipServiceSelection,
          initialTime: initialTime,
        ),
      ),
    );
    // Small delay to allow DB write to propagate before fetching
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      _fetchBookings(_userEmail);
      _fetchOpenPlays();
    }
    if (result == 'view_bookings') {
      setState(() {
        _selectedNavIndex = 2;
      });
    }
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    if (userStr != null) {
      final userObj = json.decode(userStr);
      final email = userObj['email'] ?? '';
      setState(() {
        _userName = userObj['full_name'] ?? 'Roger';
        _userEmail = email;
      });

      // ── Load cached bookings instantly so UI shows immediately ──
      final cachedBookingsStr = prefs.getString('cached_bookings_$email');
      if (cachedBookingsStr != null) {
        try {
          final cachedList = json.decode(cachedBookingsStr) as List<dynamic>;
          _applyBookings(cachedList);
        } catch (_) {}
      }

      // ── Then fetch fresh data from server in background ──
      _fetchBookings(email);
      _fetchUnreadNotifications(email);
      _fetchUnreadMessages(email);
      _fetchCourts();
      _fetchOpenPlays();
      _fetchOpenChallenges();
      _fetchPasaloCourts();
      _fetchOutgoingPasaloRequests();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchPasaloCourts() async {
    try {
      final pasalo = await _apiService.fetchPasaloCourts();
      if (mounted) {
        setState(() {
          _pasaloCourts = pasalo;
        });
      }
    } catch (e) {
      print('Error fetching pasalo courts: $e');
    }
  }

  Future<void> _fetchOutgoingPasaloRequests() async {
    try {
      final requests = await _apiService.fetchOutgoingPasaloRequests(_userEmail);
      if (mounted) {
        setState(() {
          _outgoingPasaloRequests = requests;
        });
      }
    } catch (e) {
      print('Error fetching outgoing pasalo requests: $e');
    }
  }

  String _normalizeTime(String t) {
    if (t.toUpperCase().contains('AM') || t.toUpperCase().contains('PM')) {
      if (t.startsWith('0')) return t.substring(1);
      return t;
    }
    if (t.contains(':')) {
      final parts = t.split(':');
      if (parts.length >= 2) {
        int h = int.tryParse(parts[0]) ?? 0;
        String min = parts[1];
        String ampm = h < 12 ? 'AM' : 'PM';
        int displayH = h % 12;
        if (displayH == 0) displayH = 12;
        return '$displayH:$min $ampm';
      }
    }
    return t;
  }

  String _getEndTime(String t) {
    if (t.contains(':')) {
      final parts = t.split(':');
      if (parts.length >= 2) {
        int h = int.tryParse(parts[0]) ?? 0;
        final subParts = parts[1].split(' ');
        String min = subParts[0];
        String ampm = subParts.length > 1 ? subParts[1].toUpperCase() : '';
        
        h += 1;
        if (h == 12 && ampm == 'AM') {
          ampm = 'PM';
        } else if (h == 12 && ampm == 'PM') {
          ampm = 'AM';
        } else if (h > 12) {
          h = 1;
        }
        
        return '${h.toString().padLeft(2, '0')}:$min $ampm';
      }
    }
    return t;
  }

  Future<void> _fetchOpenPlays() async {
    try {
      final rawOpenPlays = await _apiService.fetchOpenPlays(_userEmail);
      
      Map<String, Map<String, dynamic>> grouped = {};
      for (var play in rawOpenPlays) {
        String key = '${play['host_name']}_${play['preferred_date']}_${play['service_type']}';
        if (!grouped.containsKey(key)) {
          grouped[key] = Map<String, dynamic>.from(play);
          grouped[key]!['appointment_ids'] = [play['id'].toString()];
          grouped[key]!['times'] = [play['preferred_time']];
        } else {
          grouped[key]!['appointment_ids'].add(play['id'].toString());
          grouped[key]!['times'].add(play['preferred_time']);
          
          int currentSpots = grouped[key]!['spots_left'] ?? 0;
          int playSpots = play['spots_left'] ?? 0;
          if (playSpots < currentSpots) {
             grouped[key]!['spots_left'] = playSpots;
          }
          
          // Do not sum up open_play_price; it should remain the inputted flat rate.
          if (play['has_joined'] == true) {
            grouped[key]!['has_joined'] = true;
          }
        }
      }

      List<Map<String, dynamic>> finalOpenPlays = grouped.values.map((g) {
        List<String> times = List<String>.from(g['times']);
        times.sort();
        if (times.length > 1) {
          g['preferred_time'] = '${_normalizeTime(times.first)} - ${_normalizeTime(_getEndTime(times.last))}';
        } else {
          g['preferred_time'] = '${_normalizeTime(times.first)} - ${_normalizeTime(_getEndTime(times.first))}';
        }
        g['id'] = g['appointment_ids'].join(',');
        return g;
      }).toList();

      if (mounted) {
        setState(() {
          _openPlays = finalOpenPlays;
        });
        
        // Handle pending deep link for open play
        final prefs = await SharedPreferences.getInstance();
        final pendingOpenPlay = prefs.getString('pending_openplay');
        if (pendingOpenPlay != null && pendingOpenPlay.isNotEmpty) {
          final targetPlay = finalOpenPlays.where((p) => p['id'].toString().contains(pendingOpenPlay)).toList();
          if (targetPlay.isNotEmpty) {
            await prefs.remove('pending_openplay');
            Future.delayed(Duration(milliseconds: 300), () {
              if (mounted) _showJoinOpenPlayDialog(targetPlay.first);
            });
          }
        }
      }
    } catch (e) {
      print('Error fetching open plays: $e');
    }
  }

  Future<void> _fetchOpenChallenges() async {
    try {
      final challenges = await _apiService.fetchOpenChallenges(_userEmail);
      if (mounted) {
        setState(() {
          _openChallenges = challenges;
        });
      }
    } catch (e) {
      print('Error fetching open challenges: $e');
    }
  }

  Future<void> _fetchCourts() async {
    try {
      final services = await _apiService.fetchServices();
      if (services.isNotEmpty) {
        final List<String> fallbackImages = [
          'https://res.cloudinary.com/doxih7ab3/image/upload/v1784821555/queuing-system-uploads/1784821552618-505155.jpg',
          'https://res.cloudinary.com/doxih7ab3/image/upload/v1784821986/queuing-system-uploads/1784821985216-132187.jpg',
          'https://res.cloudinary.com/doxih7ab3/image/upload/v1784904651/queuing-system-uploads/1784904649498-925226.jpg',
        ];

        final now = DateTime.now();
        final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
        
        final slotResults = await Future.wait(
          services.map((s) => _apiService.fetchAvailableSlots(todayStr, s.name))
        );

        setState(() {
          _courtsList = services.asMap().entries.map((entry) {
            int idx = entry.key;
            var s = entry.value;
            var slotsMap = slotResults[idx];
            
            // Clean numerical base price
            String rawPrice = s.price.replaceAll(RegExp(r'[^0-9.]'), '');
            if (rawPrice.isEmpty || rawPrice == '0') rawPrice = '300';
            else rawPrice = double.parse(rawPrice).toStringAsFixed(0);

            // Use address if provided, otherwise description or default location
            String addr = s.address.isNotEmpty 
                ? s.address 
                : (s.description.isNotEmpty ? s.description : 'Cayang, Bogo');

            // Use real image from server icon if URL, otherwise fallback
            String imageUrl = fallbackImages[idx % fallbackImages.length];
            if (s.icon.startsWith('http') || s.icon.startsWith('/uploads')) {
              imageUrl = s.icon.startsWith('/uploads') ? 'https://pickle-system.onrender.com${s.icon}' : s.icon;
            }

            // Extract real available slot times
            List<String> backendAvailable = [];
            if (slotsMap['availableSlots'] != null) {
              backendAvailable = List<String>.from(slotsMap['availableSlots']!);
              // Filter out past times for today
              final now = DateTime.now();
              backendAvailable.removeWhere((timeStr) {
                // Parse "8:00 AM" to hour
                int hour = 0;
                if (timeStr.contains(':')) {
                  final parts = timeStr.split(RegExp(r'[:\s]'));
                  if (parts.length >= 3) {
                    hour = int.tryParse(parts[0]) ?? 0;
                    if (parts[2].toUpperCase() == 'PM' && hour < 12) hour += 12;
                    if (parts[2].toUpperCase() == 'AM' && hour == 12) hour = 0;
                  }
                }
                if (hour < now.hour) return true;
                if (hour == now.hour && now.minute > 0) return true;
                return false;
              });
            }

            // Extract defined slot times for the court
            List<String> definedSlots = [];
            if (s.variablePrices != null && s.variablePrices!.isNotEmpty) {
              for (var vp in s.variablePrices!) {
                if (vp is Map && vp['time'] != null && vp['time'].toString().isNotEmpty) {
                  definedSlots.add(_normalizeTime(vp['time'].toString()));
                } else if (vp is Map && vp['hour'] != null && vp['hour'].toString().isNotEmpty) {
                  definedSlots.add(_normalizeTime(vp['hour'].toString()));
                }
              }
            }
            
            // Intersect backend available slots with defined slots
            List<String> actualSlots = [];
            if (definedSlots.isNotEmpty) {
              actualSlots = definedSlots.where((slot) => backendAvailable.contains(slot)).toList();
            } else {
              // If no defined slots, use typical daytime slots that are available
              final typicalSlots = ['8:00 AM', '10:00 AM', '1:00 PM', '4:00 PM'];
              actualSlots = typicalSlots.where((slot) => backendAvailable.contains(slot)).toList();
            }

            return {
              'id': s.id.toString(),
              'name': s.name,
              'address': addr,
              'distance': '${(1.8 + (idx * 0.7)).toStringAsFixed(1)} km away',
              'rating': (4.8 + (idx % 2) * 0.1).toStringAsFixed(1),
              'price': rawPrice,
              'image': imageUrl,
              'slots': actualSlots.take(4).toList(),
              'latitude': s.latitude,
              'longitude': s.longitude,
              'selectedSlot': actualSlots.isNotEmpty ? actualSlots.first : '',
              'facilities': s.facilities,
              'base_price': s.basePrice,
              'hourly_prices': s.hourlyPrices,
              'serviceObj': s,
            };
          }).toList();
        });
      }
    } catch (e) {
      print('Error fetching courts: $e');
    }
  }

  Future<void> _fetchUnreadNotifications(String email) async {
    final notifications = await _apiService.fetchNotifications(email);
    int unread = notifications.where((n) => n['is_read'] != true).length;
    setState(() {
      _unreadCount = unread;
    });
  }

  Future<void> _fetchUnreadMessages(String email) async {
    final count = await _apiService.fetchUnreadMessagesCount(email);
    setState(() {
      _unreadMessageCount = count;
    });
  }

  // Applies a raw bookings list to state (used for both cache and live data)
  void _applyBookings(List<dynamic> bookings) {
    final now = DateTime.now();
    final upcoming = [];
    final past = [];

    for (var b in bookings) {
      if (b['status'] == 'cancelled') continue;
      try {
        String dateString = b['appointment_date'].toString().substring(0, 10);
        final timeStr = b['appointment_time'];
        String timeString = timeStr.toString().trim();
        int hour = int.parse(timeString.split(':')[0]);
        int minute = int.parse(timeString.split(':')[1].substring(0, 2));
        bool isPM = timeString.toUpperCase().contains('PM');
        if (isPM && hour < 12) hour += 12;
        if (!isPM && hour == 12) hour = 0;
        final dt = DateTime.parse('${dateString} ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00');
        if (dt.isAfter(now)) {
          upcoming.add(b);
        } else {
          past.add(b);
        }
      } catch (e) {
        upcoming.add(b);
      }
    }

    if (mounted) {
      setState(() {
        _upcomingBookings = upcoming.reversed.toList();
        _pastBookings = past;
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchBookings(String email) async {
    print('Fetching bookings for email: $email');
    final bookings = await _apiService.fetchUserBookings(email);

    // If null, it means a network/server error — keep existing (cached) data
    if (bookings == null) {
      print('fetchUserBookings returned null (server error), keeping existing data');
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    print('Fetched ${bookings.length} raw bookings');

    // ── Save to local cache so next refresh is instant ──
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_bookings_$email', json.encode(bookings));
    } catch (_) {}

    _applyBookings(bookings);
  }

  String _getMonthAbbr(int month) {
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return months[(month - 1) % 12];
  }

  String _getWeekdayAbbr(int weekday) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[(weekday - 1) % 7];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFAFAFA),
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(_userName, style: TextStyle(fontWeight: FontWeight.bold)),
              accountEmail: Text(_userEmail),
              currentAccountPicture: CircleAvatar(
                backgroundColor: AppColors.accentLime,
                child: Text(_userName.isNotEmpty ? _userName[0].toUpperCase() : 'U', style: TextStyle(color: AppColors.softWhite, fontSize: 24, fontWeight: FontWeight.bold)),
              ),
              decoration: BoxDecoration(color: AppColors.richBlack),
            ),
            ListTile(
              leading: Icon(Icons.home),
              title: Text('Home'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedNavIndex = 0);
              },
            ),
            ListTile(
              leading: CustomPaddleIcon(),
              title: Text('Book a Court'),
              onTap: () {
                Navigator.pop(context);
                _navigateToBookingScreen();
              },
            ),
            ListTile(
              leading: Icon(Icons.bolt, color: AppColors.primaryGreen),
              title: Text('Booking Assistant', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => BookingAssistantScreen(userEmail: _userEmail)));
              },
            ),
            ListTile(
              leading: Icon(Icons.person),
              title: Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen())).then((_) => _loadUserData());
              },
            ),
            ListTile(
              leading: Icon(Icons.group),
              title: Text('Manage Open Plays'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ManageOpenPlaysScreen(userEmail: _userEmail),
                ));
              },
            ),
            ListTile(
              leading: Icon(Icons.sports_tennis),
              title: Text('Open Challenges'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => OpenChallengesScreen(),
                )).then((_) => _loadUserData());
              },
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Manage Challenges'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ManageChallengesScreen(),
                )).then((_) => _loadUserData());
              },
            ),
          ],
        ),
      ),
      body: _isLoading 
          ? Center(child: CircularProgressIndicator(color: AppColors.accentLime)) 
          : Stack(
              children: [
                if (_selectedNavIndex == 0)
                  Container(
                    height: 360,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        stops: [0.0, 0.4, 0.7, 1.0],
                        colors: AppColors.brandingGradient,
                      ),
                    ),
                  ),
                _buildBodyContent(),
              ],
            ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final bool isMain = _selectedNavIndex == 0;
    final Color iconColor = isMain ? AppColors.softWhite : AppColors.richBlack;

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: Builder(
        builder: (context) => IconButton(
          icon: Icon(Icons.menu, color: iconColor, size: 26),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      centerTitle: false,
      title: isMain ? Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hello, ${_userName.split(' ').first}!',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.5, color: AppColors.softWhite),
          ),
          Text(
            "Let's book your court.",
            style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.softWhite.withOpacity(0.8)),
          ),
        ],
      ) : null,
      actions: [
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.chat_bubble_outline, color: iconColor, size: 24),
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => InboxScreen()));
                _fetchUnreadMessages(_userEmail);
              },
            ),
            if (_unreadMessageCount > 0)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                  child: Text('$_unreadMessageCount', style: TextStyle(color: AppColors.softWhite, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.notifications_outlined, color: iconColor, size: 26),
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsScreen()));
                _fetchUnreadNotifications(_userEmail);
              },
            ),
            if (_unreadCount > 0)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.accentLime, shape: BoxShape.circle),
                  child: Text('$_unreadCount', style: TextStyle(color: AppColors.softWhite, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
        SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBodyContent() {
    if (_selectedNavIndex == 1) {
      // Courts tab
      return _buildCourtsTabView();
    } else if (_selectedNavIndex == 2) {
      // Bookings tab
      return _buildBookingsTabView();
    } else if (_selectedNavIndex == 3) {
      // Profile tab
      return ProfileScreen();
    }

    // Home feed tab (Index 0)
    final firstName = _userName.split(' ').first;
    final allCourts = _courtsList.isNotEmpty ? _courtsList : _sampleCourts;
    
    // Group courts by venue
    final groupedVenues = _getGroupedVenues(allCourts);

    // Filter grouped venues
    final filteredVenues = groupedVenues.where((v) {
      final vName = (v['venueName'] ?? '').toString().toLowerCase();
      final address = (v['address'] ?? '').toString().toLowerCase();
      final price = double.tryParse((v['basePrice'] ?? '9999').toString()) ?? 9999;
      final rating = double.tryParse((v['rating'] ?? '0').toString()) ?? 0;
      final sports = (v['sports'] as List<dynamic>?)?.map((s) => s.toString()).toList() ?? [];

      final matchesSearch = _searchQuery.isEmpty || vName.contains(_searchQuery) || address.contains(_searchQuery);
      final matchesPrice = price <= _filterMaxPrice;
      final matchesRating = rating >= _filterMinRating;
      
      bool matchesCategory = true;
      if (_selectedSportCategory == 'Pickleball') {
        matchesCategory = sports.contains('Pickleball') || vName.contains('pickle') || address.contains('pickle');
      } else if (_selectedSportCategory == 'Tennis') {
        matchesCategory = sports.contains('Tennis') || vName.contains('tennis') || address.contains('tennis');
      }

      return matchesSearch && matchesPrice && matchesRating && matchesCategory;
    }).toList();

    return Column(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 100),

          // My Next Booking Card
          _buildNextBookingCard(),

          SizedBox(height: 24),
        ],
      ),
      Expanded(
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Color(0xFFFAFAFA),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 24),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                  color: AppColors.softWhite,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.richBlack.withOpacity(0.02),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search venues, courts or locations',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                    suffixIcon: Stack(
                      alignment: Alignment.center,
                      children: [
                        IconButton(
                          icon: Icon(Icons.tune, color: _activeFilterCount > 0 ? Color(0xFF8E24AA) : AppColors.richBlack),
                          onPressed: () => _showFilterSheet(),
                        ),
                        if (_activeFilterCount > 0)
                          Positioned(
                            top: 8, right: 8,
                            child: Container(
                              width: 16, height: 16,
                              decoration: const BoxDecoration(color: Color(0xFFD81B60), shape: BoxShape.circle),
                              child: Center(
                                child: Text('$_activeFilterCount', style: const TextStyle(color: AppColors.softWhite, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                      ],
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
              ),
              ),

              SizedBox(height: 16),

              // Sport Category Selector Bar (SEE ALL, Pickleball, Tennis)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildSportCategoryChip('ALL', '🎾 SEE ALL'),
                      SizedBox(width: 8),
                      _buildSportCategoryChip('Pickleball', '🏓 Pickleball'),
                      SizedBox(width: 8),
                      _buildSportCategoryChip('Tennis', '🎾 Tennis'),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nearby Venues Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Nearby Venues',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.5, color: AppColors.deepTeal),
                      ),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _selectedNavIndex = 1;
                          });
                        },
                        child: Row(
                          children: [
                            Text(
                              'See All ',
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.richBlack),
                            ),
                            Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.richBlack),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 16),

                // Nearby Venues Horizontal List
                SizedBox(
                  height: 250,
                  child: filteredVenues.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                              SizedBox(height: 8),
                              Text('No venues found for "$_searchQuery"',
                                  style: TextStyle(fontFamily: 'Poppins', color: Colors.grey.shade500, fontSize: 14)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          scrollDirection: Axis.horizontal,
                          itemCount: filteredVenues.length,
                          separatorBuilder: (context, index) => SizedBox(width: 16),
                          itemBuilder: (context, index) {
                            final venue = filteredVenues[index];
                            final String venueId = venue['venueKey'] ?? index.toString();
                            final bool isFav = _favoriteCourts.contains(venueId);
                            return _buildVenueCard(venue, venueId, isFav);
                          },
                        ),
                ),

          SizedBox(height: 24),

          // Open Plays Section
          _buildOpenPlaysSection(),
          
          SizedBox(height: 24),
          _buildOpenChallengesSection(),
          
          SizedBox(height: 24),
          _buildPasaloCourtsSection(),
          
          if (_outgoingPasaloRequests.isNotEmpty) ...[
            SizedBox(height: 24),
            _buildMyPasaloRequestsSection(),
          ],
          
          SizedBox(height: 48),
          Center(
            child: Column(
              children: [
                Text('Developed by: Roger A. Tonacao', style: TextStyle(fontFamily: 'Poppins', color: Colors.grey.shade400, fontSize: 12, fontWeight: FontWeight.w500)),
                SizedBox(height: 4),
                GestureDetector(
                  onTap: () async {
                    final uri = Uri.parse('https://www.rogertonacao.com');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                  child: Text('www.rogertonacao.com', style: TextStyle(fontFamily: 'Poppins', color: AppColors.primaryGreen, fontSize: 12, fontWeight: FontWeight.w500, decoration: TextDecoration.underline)),
                ),
                SizedBox(height: 4),
                Text('Picklebook © ${DateTime.now().year}', style: TextStyle(fontFamily: 'Poppins', color: Colors.grey.shade400, fontSize: 10)),
              ],
            ),
          ),
          SizedBox(height: 48),
              ],
            ),
          ),
        ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOpenPlaysSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'Active Open Plays',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.5, color: AppColors.deepTeal),
              ),
              if (_openPlays.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AllOpenPlaysScreen(
                          openPlays: _openPlays,
                          onJoinPlay: _showJoinOpenPlayDialog,
                          onViewJoiners: _showJoinersListBottomSheet,
                        ),
                      ),
                    );
                  },
                  child: Text('See All', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
            ],
          ),
        ),
        SizedBox(height: 16),
        if (_openPlays.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                CustomPaddleIcon(color: Colors.grey.shade400),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'No active open plays right now. Host a session and invite others to join!',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          )
        else
          SizedBox(
            height: 125,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              scrollDirection: Axis.horizontal,
              itemCount: _openPlays.length,
              separatorBuilder: (context, index) => SizedBox(width: 16),
              itemBuilder: (context, index) {
                final play = _openPlays[index];
                final bool isFull = (play['spots_left'] ?? 0) <= 0;
                final String rawTimeStr = _normalizeTime(play['preferred_time'] ?? '');
                final String timeStr = rawTimeStr.replaceAll(':00', '').replaceAll(' AM', 'AM').replaceAll(' PM', 'PM');
                String month = '';
                String day = '';
                try {
                  final date = DateTime.parse(play['preferred_date']?.split('T')[0] ?? '');
                  const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
                  month = months[date.month - 1];
                  day = date.day.toString();
                } catch(e) {
                  month = 'TBA';
                  day = '-';
                }
                
                final content = Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: MediaQuery.of(context).size.width - 48,
                      margin: EdgeInsets.only(top: 6, left: 6, bottom: 6),
                      decoration: BoxDecoration(
                        color: AppColors.softWhite,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: AppColors.richBlack.withOpacity(0.08), blurRadius: 10, offset: Offset(0, 4)),
                        ],
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Left side: Date Block
                          Container(
                            width: 72,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: AppColors.brandingGradient,
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(month, style: TextStyle(color: AppColors.softWhite.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                Text(day, style: TextStyle(color: AppColors.softWhite, fontSize: 26, fontWeight: FontWeight.w900, height: 1.1)),
                                SizedBox(height: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.richBlack.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(timeStr, style: TextStyle(color: AppColors.softWhite, fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                          
                          // Right side: Details
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(play['service_type'] ?? 'Court', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.deepTeal), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            SizedBox(height: 2),
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: Container(
                                                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                decoration: BoxDecoration(color: AppColors.primaryGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                                child: Text(play['open_play_type']?.toString().toUpperCase() ?? 'DOUBLES', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
                                              ),
                                            ),
                                            SizedBox(height: 2),
                                            Text('Host: ${play['host_name'] ?? 'Unknown'}', style: TextStyle(color: AppColors.stoneGray, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            SizedBox(height: 2),
                                            Text(play['address'] ?? 'Cayang', style: TextStyle(color: AppColors.stoneGray, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Icon(Icons.person, size: 16, color: Colors.greenAccent.withOpacity(0.5)),
                                              SizedBox(height: 2),
                                              Builder(
                                                builder: (context) {
                                                  int maxP = int.tryParse(play['open_play_max_players']?.toString() ?? '4') ?? 4;
                                                  int spotsL = int.tryParse(play['spots_left']?.toString() ?? '0') ?? 0;
                                                  int joinedP = maxP - spotsL;
                                                  if (joinedP < 0) joinedP = 0;
                                                  return Container(
                                                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: isFull ? Colors.red.shade50 : AppColors.primaryGreen.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      isFull ? 'FULL' : '$joinedP/$maxP',
                                                      style: TextStyle(color: isFull ? Colors.red.shade700 : AppColors.primaryGreen, fontSize: 9, fontWeight: FontWeight.bold),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 4),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.location_on, size: 10, color: Colors.red),
                                              SizedBox(width: 2),
                                              Text(_getDistanceString(play['latitude'], play['longitude'], play['distance'] ?? '2.4 km away'), style: TextStyle(color: Colors.grey.shade600, fontSize: 9)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Spacer(),
                                  Row(
                                    children: [
                                      Text(
                                        'P${play['open_play_price']}',
                                        style: TextStyle(fontFamily: 'Poppins', color: AppColors.deepTeal, fontSize: 16, fontWeight: FontWeight.w900),
                                      ),
                                      Spacer(),
                                      GestureDetector(
                                        onTap: () {
                                          final String playId = play['id'].toString().split(',').first;
                                          final String url = '${Uri.base.toString().split('?')[0]}?openplay=$playId';
                                          Clipboard.setData(ClipboardData(text: url));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Share link copied to clipboard!'), backgroundColor: AppColors.primaryGreen, duration: Duration(seconds: 3)),
                                          );
                                        },
                                        child: Container(
                                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                                          child: Row(
                                            children: [
                                              Icon(Icons.share, color: Colors.grey.shade600, size: 12),
                                              SizedBox(width: 4),
                                              Text('Share', style: TextStyle(color: Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Badge
                    if (!isFull)
                      Positioned(
                        top: 0,
                        left: 0,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accentLime,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: AppColors.richBlack.withOpacity(0.1), blurRadius: 4, offset: Offset(0, 2))],
                          ),
                          child: Text('NEW', style: TextStyle(color: AppColors.richBlack, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        ),
                      ),
                    if (isFull)
                      Positioned(
                        top: 0,
                        left: 0,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.stoneGray,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: AppColors.richBlack.withOpacity(0.1), blurRadius: 4, offset: Offset(0, 2)),
                            ],
                          ),
                          child: Text('FULL', style: TextStyle(color: AppColors.softWhite, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        ),
                      ),
                  ],
                );
                
                return GestureDetector(
                  onTap: () {
                    _showJoinersListBottomSheet(play);
                  },
                  child: content,
                );
              },
            ),
          ),
      ],
    );
  }

  void _showJoinOpenPlayDialog(Map<String, dynamic> play) {
    TextEditingController refController = TextEditingController();
    bool isSubmitting = false;
    int guestCount = 0;
    double price = double.tryParse(play['open_play_price']?.toString() ?? '0') ?? 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog.fullscreen(
              child: Scaffold(
                appBar: AppBar(
                  title: Text('Join Open Play', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 18)),
                  leading: IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(Icons.share, color: AppColors.richBlack),
                      onPressed: () {
                        final String playId = play['id'].toString().split(',').first;
                        final String url = '${Uri.base.toString().split('?')[0]}?openplay=$playId';
                        Clipboard.setData(ClipboardData(text: url));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Share link copied to clipboard!'),
                            backgroundColor: AppColors.primaryGreen,
                            duration: Duration(seconds: 3),
                          ),
                        );
                      },
                    ),
                  ],
                  backgroundColor: AppColors.softWhite,
                  elevation: 0,
                  foregroundColor: AppColors.richBlack,
                ),
                body: SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Host: ${play['host_name']}', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Text('${play['service_type']}', style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.primaryGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                              child: Text(play['open_play_type']?.toString().toUpperCase() ?? 'DOUBLES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Text('Price: P${(price * (1 + guestCount)).toStringAsFixed(2)}', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold, fontSize: 20)),
                        SizedBox(height: 24),
                        Text('Bring Guests (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        SizedBox(height: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: guestCount,
                              isExpanded: true,
                              items: [
                                DropdownMenuItem(value: 0, child: Text('Just me (+0)')),
                                DropdownMenuItem(value: 1, child: Text('+1 Guest')),
                                DropdownMenuItem(value: 2, child: Text('+2 Guests')),
                                DropdownMenuItem(value: 3, child: Text('+3 Guests')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setStateDialog(() { guestCount = val; });
                                }
                              },
                            ),
                          ),
                        ),
                        SizedBox(height: 24),

                        if (play['open_play_instructions'] != null && play['open_play_instructions'].toString().isNotEmpty) ...[
                          Text('Instructions from Host', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(play['open_play_instructions'], style: TextStyle(fontSize: 14)),
                          ),
                          SizedBox(height: 24),
                        ],

                        if (play['open_play_payment_details'] != null && play['open_play_payment_details'].toString().isNotEmpty) ...[
                          Text('Payment Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(play['open_play_payment_details'], style: TextStyle(fontSize: 14)),
                          ),
                          SizedBox(height: 24),
                        ],

                        Text('Payment Reference Number:', style: TextStyle(fontSize: 14, color: Colors.grey.shade800, fontWeight: FontWeight.w600)),
                        SizedBox(height: 8),
                        TextField(
                          controller: refController,
                          onChanged: (val) {
                            setStateDialog(() {});
                          },
                          decoration: InputDecoration(
                            hintText: 'Enter reference number',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                bottomNavigationBar: Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.softWhite,
                    boxShadow: [
                      BoxShadow(color: AppColors.richBlack.withOpacity(0.05), blurRadius: 10, offset: Offset(0, -5))
                    ]
                  ),
                  child: isSubmitting
                      ? Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: refController.text.trim().isEmpty ? null : () async {
                            setStateDialog(() { isSubmitting = true; });
                            
                            final result = await _apiService.joinOpenPlay(
                              play['id'], 
                              _userEmail, 
                              refController.text.trim(),
                              guestCount
                            );
                            
                            setStateDialog(() { isSubmitting = false; });
                            
                            Navigator.pop(context); // Close dialog

                            if (result['success'] == true) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Successfully joined!'), backgroundColor: Colors.green),
                              );
                              _fetchOpenPlays(); // refresh
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(result['message'] ?? 'Failed to join'), backgroundColor: Colors.red),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: AppColors.softWhite,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Confirm Join', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                ),
              )
            );
          }
        );
      }
    );
  }

  void _showJoinersListBottomSheet(Map<String, dynamic> play) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: AppColors.softWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.group, color: AppColors.primaryGreen),
                        SizedBox(width: 8),
                        Text('Joiners', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
                      ],
                    ),
                    Row(
                      children: [
                        if (play['email'] != null && play['email'] != _userEmail)
                          TextButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    userEmail: _userEmail,
                                    partnerEmail: play['email'],
                                    partnerName: play['host_name'] ?? 'Host',
                                  ),
                                ),
                              );
                            },
                            icon: Icon(Icons.chat_bubble_outline, size: 16),
                            label: Text('Message Host'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primaryGreen,
                              padding: EdgeInsets.symmetric(horizontal: 12),
                            ),
                          ),
                        IconButton(
                          icon: Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    )
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _apiService.fetchOpenPlayParticipants(play['id'].toString()),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(child: Text('No joiners yet.'));
                    }
                    final participants = snapshot.data!;
                    return ListView.builder(
                      itemCount: participants.length + 1,
                      itemBuilder: (context, index) {
                        if (index == participants.length) {
                          if ((play['open_play_instructions'] != null && play['open_play_instructions'].toString().isNotEmpty) || (play['openPlayInstructions'] != null && play['openPlayInstructions'].toString().isNotEmpty)) {
                            return Padding(
                              padding: EdgeInsets.fromLTRB(24, 16, 24, 16),
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.only(left: 16),
                                decoration: BoxDecoration(
                                  border: Border(left: BorderSide(color: Colors.grey.shade300, width: 2)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Host Notes & Policies', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryGreen)),
                                    SizedBox(height: 4),
                                    Text(
                                      (play['open_play_instructions'] ?? play['openPlayInstructions'] ?? '').toString(),
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                    ),
                                    if ((play['open_play_payment_details'] != null && play['open_play_payment_details'].toString().isNotEmpty) || (play['openPlayPaymentDetails'] != null && play['openPlayPaymentDetails'].toString().isNotEmpty))
                                      Padding(
                                        padding: EdgeInsets.only(top: 8),
                                        child: Text(
                                          'Payment: ${(play['open_play_payment_details'] ?? play['openPlayPaymentDetails'] ?? '').toString()}',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }
                          return SizedBox.shrink();
                        }

                        final p = participants[index];
                        final String name = p['full_name'] ?? 'Unknown User';
                        final String status = p['status'] ?? 'pending';
                        final int guestCount = int.tryParse(p['guest_count']?.toString() ?? '0') ?? 0;
                        final String guestText = guestCount > 0 ? ' (+$guestCount Guests)' : '';
                        
                        return Column(
                          children: [
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primaryGreen.withOpacity(0.1),
                                child: Icon(Icons.person, color: AppColors.primaryGreen),
                              ),
                              title: Text('$name$guestText', style: TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(status.toUpperCase(), style: TextStyle(
                                color: status == 'approved' ? Colors.green : (status == 'rejected' ? Colors.red : Colors.orange),
                                fontWeight: FontWeight.bold,
                                fontSize: 12
                              )),
                            ),
                            if (index < participants.length - 1) Divider(),
                          ],
                        );
                      },
                    );
                  }
                ),
              ),
              if (play['has_joined'] != true)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(24, 16, 24, 42),
                  decoration: BoxDecoration(
                    color: AppColors.softWhite,
                    border: Border(top: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showJoinOpenPlayDialog(play);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: AppColors.softWhite,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: Text('Request Join', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                )
            ],
          )
        );
      }
    );
  }

  String _getDistanceString(dynamic lat, dynamic lng, String fallbackDistance) {
    if (_currentPosition == null || lat == null || lng == null) return fallbackDistance;
    final double? cLat = double.tryParse(lat.toString());
    final double? cLng = double.tryParse(lng.toString());
    if (cLat == null || cLng == null) return fallbackDistance;
    
    double distanceInMeters = Geolocator.distanceBetween(
      _currentPosition!.latitude, 
      _currentPosition!.longitude, 
      cLat, 
      cLng
    );
    
    return '${(distanceInMeters / 1000).toStringAsFixed(1)} km away';
  }

  String _getPriceDisplay(Map<String, dynamic> court) {
    String baseFallback = court['price']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? 'N/A';
    String dayRate = baseFallback;
    String nightRate = baseFallback;

    // The backend maps c.hourly_prices to variable_prices
    final rawHourly = court['serviceObj']?.variablePrices;
    if (rawHourly != null) {
      List<dynamic> hourlyList = [];
      if (rawHourly is List) {
        hourlyList = rawHourly;
      } else if (rawHourly is String) {
        try {
          hourlyList = json.decode(rawHourly);
        } catch (_) {}
      }
      
      for (var item in hourlyList) {
        if (item is Map && item['time'] != null && item['price'] != null) {
          final String timeStr = item['time'].toString();
          final int hour = int.tryParse(timeStr.split(':')[0]) ?? -1;
          if (hour == 6) {
            dayRate = item['price'].toString();
          } else if (hour == 18) {
            nightRate = item['price'].toString();
          }
        }
      }
    }
    
    // Convert float string like "300.0" to "300" if possible to keep it clean
    dayRate = dayRate.replaceAll(RegExp(r'\.0+$'), '').replaceAll(RegExp(r'\.00$'), '');
    nightRate = nightRate.replaceAll(RegExp(r'\.0+$'), '').replaceAll(RegExp(r'\.00$'), '');
    
    if (dayRate == nightRate) {
      return 'P$dayRate/hr';
    }
    return 'Day: P$dayRate | Night: P$nightRate';
  }

  Widget _buildOpenChallengesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'Active Open Challenges',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.5, color: AppColors.deepTeal),
              ),
              if (_openChallenges.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OpenChallengesScreen(),
                      ),
                    ).then((_) => _loadUserData());
                  },
                  child: Text('See All', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
            ],
          ),
        ),
        SizedBox(height: 16),
        if (_openChallenges.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                CustomPaddleIcon(color: Colors.grey.shade400),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'No active open challenges right now. Post a challenge and wait for opponents!',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          )
        else
          SizedBox(
            height: 200,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              scrollDirection: Axis.horizontal,
              itemCount: _openChallenges.length,
              separatorBuilder: (context, index) => SizedBox(width: 16),
              itemBuilder: (context, index) {
                final challenge = _openChallenges[index];
                
                final String rawTimeStr = _normalizeTime(challenge['preferred_time'] ?? '');
                final String timeStr = rawTimeStr.replaceAll(':00', '').replaceAll(' AM', 'AM').replaceAll(' PM', 'PM');
                String month = '';
                String day = '';
                try {
                  final date = DateTime.parse(challenge['preferred_date']?.split('T')[0] ?? '');
                  const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
                  month = months[date.month - 1];
                  day = date.day.toString();
                } catch(e) {
                  month = 'TBA';
                  day = '-';
                }
                
                final isDoubles = challenge['challenge_type'] == 'doubles';
                final hostDisplay = isDoubles && challenge['host_tandem_name'] != null && challenge['host_tandem_name'].isNotEmpty
                    ? challenge['host_tandem_name']
                    : (challenge['host_name'] ?? 'Unknown');
                
                final courtName = challenge['service_type'] ?? 'Unknown Court';
                final courtData = _courtsList.isNotEmpty 
                    ? _courtsList.cast<Map<String, dynamic>?>().firstWhere((c) => c != null && c['name'] == courtName, orElse: () => null) 
                    : null;
                final address = courtData != null && courtData['address'] != null && courtData['address'].toString().isNotEmpty 
                    ? courtData['address'] 
                    : 'Cayang, Bogo';

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OpenChallengesScreen(),
                      ),
                    ).then((_) => _loadUserData());
                  },
                  child: Container(
                    width: MediaQuery.of(context).size.width - 48,
                    margin: EdgeInsets.only(top: 6, left: 6, bottom: 6),
                    decoration: BoxDecoration(
                      color: AppColors.softWhite,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: AppColors.richBlack.withOpacity(0.08), blurRadius: 10, offset: Offset(0, 4)),
                      ],
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Left side: Date Block
                        Container(
                          width: 72,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.deepTeal, AppColors.primaryGreen],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(month, style: TextStyle(color: AppColors.softWhite.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1)),
                              Text(day, style: TextStyle(color: AppColors.softWhite, fontSize: 26, fontWeight: FontWeight.w900, height: 1.1)),
                              SizedBox(height: 8),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.richBlack.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(timeStr, style: TextStyle(color: AppColors.softWhite, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                        
                        // Right side: Details
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    // Host Side
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          isDoubles
                                              ? SizedBox(
                                                  height: 32,
                                                  width: 50,
                                                  child: Stack(
                                                    alignment: Alignment.center,
                                                    children: [
                                                      Positioned(
                                                        left: 0,
                                                        child: CircleAvatar(
                                                          radius: 16,
                                                          backgroundColor: Colors.grey.shade300,
                                                          child: Icon(Icons.person, color: Colors.white, size: 18),
                                                        ),
                                                      ),
                                                      Positioned(
                                                        right: 0,
                                                        child: CircleAvatar(
                                                          radius: 16,
                                                          backgroundColor: Colors.grey.shade400,
                                                          child: Icon(Icons.person, color: Colors.white, size: 18),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                )
                                              : CircleAvatar(
                                                  radius: 18,
                                                  backgroundColor: Colors.grey.shade300,
                                                  child: Icon(Icons.person, color: Colors.white, size: 20),
                                                ),
                                          SizedBox(height: 4),
                                          Text(
                                            hostDisplay,
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.richBlack),
                                            maxLines: 2,
                                            textAlign: TextAlign.center,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    // VS
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: Text('VS', style: TextStyle(color: AppColors.accentLime, fontWeight: FontWeight.w900, fontSize: 16, fontStyle: FontStyle.italic)),
                                    ),
                                    // Challenger Side
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          isDoubles
                                              ? SizedBox(
                                                  height: 32,
                                                  width: 50,
                                                  child: Stack(
                                                    alignment: Alignment.center,
                                                    children: [
                                                      Positioned(
                                                        left: 0,
                                                        child: CircleAvatar(
                                                          radius: 16,
                                                          backgroundColor: challenge['accepted_challenger_name'] != null ? Colors.grey.shade300 : AppColors.primaryGreen.withOpacity(0.1),
                                                          child: Icon(challenge['accepted_challenger_name'] != null ? Icons.person : Icons.help_outline, color: challenge['accepted_challenger_name'] != null ? Colors.white : AppColors.primaryGreen, size: 18),
                                                        ),
                                                      ),
                                                      Positioned(
                                                        right: 0,
                                                        child: CircleAvatar(
                                                          radius: 16,
                                                          backgroundColor: challenge['accepted_challenger_name'] != null ? Colors.grey.shade400 : AppColors.primaryGreen.withOpacity(0.2),
                                                          child: Icon(challenge['accepted_challenger_name'] != null ? Icons.person : Icons.help_outline, color: challenge['accepted_challenger_name'] != null ? Colors.white : AppColors.primaryGreen, size: 18),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                )
                                              : CircleAvatar(
                                                  radius: 18,
                                                  backgroundColor: challenge['accepted_challenger_name'] != null ? Colors.grey.shade300 : AppColors.primaryGreen.withOpacity(0.1),
                                                  child: Icon(challenge['accepted_challenger_name'] != null ? Icons.person : Icons.help_outline, color: challenge['accepted_challenger_name'] != null ? Colors.white : AppColors.primaryGreen, size: 20),
                                                ),
                                          SizedBox(height: 4),
                                          Text(
                                            challenge['accepted_challenger_name'] != null 
                                                ? challenge['accepted_challenger_name']
                                                : 'Accepting\nChallengers',
                                            style: TextStyle(
                                              fontSize: challenge['accepted_challenger_name'] != null ? 12 : 11, 
                                              fontWeight: challenge['accepted_challenger_name'] != null ? FontWeight.bold : FontWeight.normal,
                                              fontStyle: challenge['accepted_challenger_name'] != null ? FontStyle.normal : FontStyle.italic, 
                                              color: challenge['accepted_challenger_name'] != null ? AppColors.richBlack : Colors.grey.shade600, 
                                              height: 1.1
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade200)
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.sports_tennis, size: 12, color: AppColors.primaryGreen),
                                          SizedBox(width: 4),
                                          Expanded(child: Text(courtName, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.richBlack), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                        ]
                                      ),
                                      SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(Icons.location_on, size: 12, color: Colors.grey.shade500),
                                          SizedBox(width: 4),
                                          Expanded(child: Text(address, style: TextStyle(fontSize: 10, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                        ]
                                      )
                                    ]
                                  )
                                ),
                                Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: SizedBox(
                                      width: double.infinity,
                                      height: 28,
                                      child: ElevatedButton.icon(
                                        icon: Icon(Icons.videocam, size: 14),
                                        label: Text(_userEmail == challenge['host_email'] ? 'Start Live Stream' : 'Watch Live', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.redAccent,
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.zero,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))
                                        ),
                                        onPressed: () {
                                          Navigator.push(context, MaterialPageRoute(builder: (_) => LiveBroadcastScreen(
                                            channelName: 'match_${challenge['id']}',
                                            isBroadcaster: _userEmail == challenge['host_email'],
                                            hostName: hostDisplay,
                                            challengerName: challenge['accepted_challenger_name'] ?? 'Challenger',
                                          )));
                                        },
                                      )
                                    )
                                  )
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildCourtCard(Map<String, dynamic> court, String courtId, bool isFav) {
    return Container(
      width: 170,
      decoration: BoxDecoration(
        color: AppColors.softWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: AppColors.richBlack.withOpacity(0.05), blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () {
          _navigateToBookingScreen(initialServiceName: court['name'], skipServiceSelection: true);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Image Header
            Container(
              width: double.infinity,
              height: 100,
              padding: EdgeInsets.fromLTRB(12, 12, 12, 12),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen,
                image: court['image'] != null && court['image'].toString().isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(court['image']),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.45), BlendMode.darken),
                      )
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CustomPaddleIcon(color: AppColors.softWhite, size: 14),
                          SizedBox(width: 4),
                          Text(court['rating'] ?? '4.8', style: TextStyle(color: AppColors.softWhite, fontSize: 11, fontWeight: FontWeight.bold)),
                          Icon(Icons.star, color: Colors.amber, size: 11),
                        ],
                      ),
                      InkWell(
                        onTap: () {
                          setState(() {
                            if (isFav) {
                              _favoriteCourts.remove(courtId);
                            } else {
                              _favoriteCourts.add(courtId);
                            }
                          });
                        },
                        child: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          color: isFav ? Colors.red : AppColors.softWhite,
                          size: 14,
                        ),
                      )
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      if (court['logo_url'] != null && court['logo_url'].toString().trim().isNotEmpty) ...[
                        Container(
                          width: 22,
                          height: 22,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                          child: ClipOval(
                            child: Image.network(
                              court['logo_url'].toString().trim(),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(Icons.business, size: 12, color: AppColors.primaryGreen),
                            ),
                          ),
                        ),
                      ] else if (court['logo'] != null && court['logo'].toString().trim().isNotEmpty) ...[
                        Container(
                          width: 22,
                          height: 22,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                          child: ClipOval(
                            child: Image.network(
                              court['logo'].toString().trim(),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(Icons.business, size: 12, color: AppColors.primaryGreen),
                            ),
                          ),
                        ),
                      ],
                      Expanded(
                        child: Text(
                          court['name'] ?? 'Court',
                          style: TextStyle(color: AppColors.softWhite, fontSize: 12, fontWeight: FontWeight.bold),
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // 2. Highlight Strip (Price)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: Color(0xFFE8F5E9),
              child: Text(
                _getPriceDisplay(court),
                style: TextStyle(color: AppColors.primaryGreen, fontSize: 12, fontWeight: FontWeight.bold),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
            ),
            
            // 3. White Body
            Expanded(
              child: Container(
                padding: EdgeInsets.all(10),
                color: AppColors.softWhite,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      court['address'] ?? 'Cayang',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.richBlack),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                    ),

                    Spacer(),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 12, color: Colors.red),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _getDistanceString(court['latitude'], court['longitude'], court['distance'] ?? '2.4 km away'),
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 10),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (court['latitude'] != null && court['longitude'] != null) ...[
                          SizedBox(width: 4),
                          InkWell(
                            onTap: () {
                              if (_currentPosition != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MapRouteScreen(
                                      startLocation: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                                      endLocation: LatLng(
                                        double.parse(court['latitude'].toString()),
                                        double.parse(court['longitude'].toString())
                                      ),
                                      destinationName: court['name'] ?? 'Court',
                                    ),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please enable location services first')));
                                _determinePosition();
                              }
                            },
                            child: Container(
                              height: 24,
                              width: 24,
                              decoration: BoxDecoration(
                                color: Color(0xFFE3F2FD),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Center(
                                child: Icon(Icons.directions, size: 14, color: Color(0xFF1976D2)),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          _navigateToBookingScreen(initialServiceName: court['name'], skipServiceSelection: true);
                        },
                        child: const Text('Book'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageOwnerSheet(BuildContext context, String courtName) {
    final TextEditingController _msgCtrl = TextEditingController();
    bool _isSending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.softWhite,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                SizedBox(height: 24),

                // Header
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primaryGreen, size: 22),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Message Court Owner', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(courtName, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.grey.shade600),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),

                SizedBox(height: 24),

                // Message Field
                TextField(
                  controller: _msgCtrl,
                  maxLines: 4,
                  minLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Ask about availability, pricing, facilities...',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primaryGreen, width: 2),
                    ),
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),

                SizedBox(height: 16),

                // Send Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSending
                        ? null
                        : () async {
                            final msg = _msgCtrl.text.trim();
                            if (msg.isEmpty) return;
                            setSheetState(() => _isSending = true);

                            try {
                              final ownerEmail = await _apiService.getOwnerEmailByCourt(courtName);
                              
                              // Send the message via new message API
                              await _apiService.sendMessage(
                                _userEmail,
                                ownerEmail,
                                courtName,
                                msg,
                              );
                              
                              // Keep the notification as well
                              await _apiService.sendNotification(
                                ownerEmail,
                                _userEmail,
                                'ðŸ’¬ Message from ${_userName.split(" ").first} about $courtName',
                                msg,
                              );
                              
                              Navigator.pop(ctx);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    userEmail: _userEmail,
                                    partnerEmail: ownerEmail,
                                    partnerName: 'Court Owner', // Fallback, would ideally be the owner's actual name
                                  ),
                                ),
                              );
                            } catch (e) {
                              setSheetState(() => _isSending = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to send message.'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: AppColors.softWhite,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isSending
                        ? SizedBox(width: 24, height: 20, child: CircularProgressIndicator(color: AppColors.softWhite, strokeWidth: 2))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.send_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('Send Message', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 15)),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFilterSheet() {
    double tempMaxPrice = _filterMaxPrice;
    double tempMinRating = _filterMinRating;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.softWhite,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 37),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Filter Courts', style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.richBlack)),
                      TextButton(
                        onPressed: () => setSheetState(() { tempMaxPrice = 1000; tempMinRating = 0; }),
                        child: const Text('Reset', style: TextStyle(fontFamily: 'Poppins', color: Color(0xFF8E24AA), fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Price range
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Max Price per hour', style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.richBlack)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFF3E5F5), borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          tempMaxPrice >= 1000 ? 'Any' : 'P${tempMaxPrice.toInt()}',
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF8E24AA)),
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFF8E24AA),
                      thumbColor: const Color(0xFF8E24AA),
                      overlayColor: const Color(0x298E24AA),
                      inactiveTrackColor: Colors.grey.shade200,
                      trackHeight: 4,
                    ),
                    child: Slider(
                      value: tempMaxPrice,
                      min: 100,
                      max: 1000,
                      divisions: 18,
                      onChanged: (v) => setSheetState(() => tempMaxPrice = v),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('P100', style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Colors.grey.shade500)),
                      Text('P1000+', style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Minimum rating
                  const Text('Minimum Rating', style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.richBlack)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [0.0, 1.0, 2.0, 3.0, 4.0, 4.5].map((rating) {
                      final bool selected = tempMinRating == rating;
                      return GestureDetector(
                        onTap: () => setSheetState(() => tempMinRating = rating),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected ? const Color(0xFF8E24AA) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: selected ? const Color(0xFF8E24AA) : Colors.grey.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded, size: 14, color: selected ? AppColors.softWhite : Colors.amber),
                              const SizedBox(width: 3),
                              Text(
                                rating == 0 ? 'Any' : '${rating}+',
                                style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: selected ? AppColors.softWhite : AppColors.richBlack),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),
                  // Apply button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _filterMaxPrice = tempMaxPrice;
                          _filterMinRating = tempMinRating;
                        });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8E24AA),
                        foregroundColor: AppColors.softWhite,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text('Apply Filters', style: TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNextBookingCard() {
    if (_upcomingBookings.isEmpty) {
      return Container(
        height: 185,
        child: Center(
          child: Text('No upcoming bookings', style: TextStyle(color: Colors.grey)),
        )
      );
    }

    return _NextBookingCarousel(
      bookings: _upcomingBookings, 
      onView: _showBookingDetailDialog, 
      onGetDirection: _handleGetDirection, 
      onPasalo: _showPostPasaloDialog,
      getWeekday: _getWeekdayAbbr, 
      getMonth: _getMonthAbbr
    );
  }

  Future<void> _handleGetDirection(dynamic booking) async {
    if (_currentPosition == null) {
      await _determinePosition();
    }
    
    if (_currentPosition != null && booking['court_lat'] != null && booking['court_lng'] != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MapRouteScreen(
            startLocation: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            endLocation: LatLng(
              double.parse(booking['court_lat'].toString()),
              double.parse(booking['court_lng'].toString())
            ),
            destinationName: booking['service_type'] ?? 'Court',
          ),
        ),
      );
    } else if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please enable location services and try again.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Court location data unavailable.')));
    }
  }

  void _showBookingDetailDialog(dynamic booking) {
    bool isAssume = booking['is_assume'] == true || booking['is_assume'] == 'true' || booking['is_assume'] == 1 || booking['is_assume'] == '1';
    String bStatus = (booking['status'] ?? '').toString().trim().toLowerCase();
    bool showPasalo = !isAssume && bStatus != 'cancelled' && bStatus != 'completed';

    String formattedDate = booking['appointment_date'] ?? 'N/A';
    try {
      if (formattedDate.isNotEmpty && formattedDate != 'N/A') {
        final parsed = DateTime.parse(formattedDate).toLocal();
        formattedDate = '${_getWeekdayAbbr(parsed.weekday)}, ${_getMonthAbbr(parsed.month)} ${parsed.day}, ${parsed.year}';
      }
    } catch (_) {}

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(booking['service_type'] ?? 'Booking Detail', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (booking['id'] != null) ...[
              Text('Booking #${booking['id']}', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
            ],
            Text('Date: $formattedDate'),
            SizedBox(height: 8),
            Text('Time: ${booking['appointment_time'] ?? 'N/A'}'),
            SizedBox(height: 8),
            Text('Location: ${booking['court_address'] ?? 'N/A'}'),
            SizedBox(height: 8),
            Text('Amount: P${booking['total_amount'] ?? booking['amount'] ?? '0'}'),
            SizedBox(height: 8),
            Text('Status: ${(booking['status'] ?? 'Confirmed').toString().replaceAll('confirmed', 'Confirmed').replaceAll('pending', 'Pending')}', style: TextStyle(color: AppColors.accentLime, fontWeight: FontWeight.bold)),
            if (isAssume) ...[
              SizedBox(height: 8),
              Text('Pasalo Price: P${booking['assume_price'] ?? '0'}', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
            ],
          ],
        ),
        actions: [
          if (booking['is_open_play']?.toString() == 'true' || booking['is_open_play'] == true || booking['is_open_play'] == 1)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showEditOpenPlayDialog(booking);
              },
              child: Text('Edit Open Play', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
            ),
          if (showPasalo)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(context);
                _showPostPasaloDialog(booking);
              },
              child: Text('POST FOR PASALO', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          if (isAssume)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(context);
                _showPasaloRequestsDialog(booking);
              },
              child: Text('VIEW PASALO REQUESTS', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: AppColors.richBlack)),
          ),
        ],
      ),
    );
  }

  void _showPasaloRequestsDialog(dynamic booking) async {
    final requests = await _apiService.fetchPasaloRequests(booking['id'].toString());
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setStateSB) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Pasalo Requests', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('Players requesting to assume this court booking.'),
                  SizedBox(height: 16),
                  Expanded(
                    child: requests.isEmpty 
                      ? Center(child: Text('No requests yet.', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          itemCount: requests.length,
                          itemBuilder: (context, index) {
                            final req = requests[index];
                            final bool hasAcceptedOrPaid = requests.any((r) => r['status'] == 'accepted' || r['status'] == 'payment_sent');
                            
                            Widget? trailingButton;
                            if (req['status'] == 'pending' && !hasAcceptedOrPaid) {
                              trailingButton = ElevatedButton(
                                onPressed: () async {
                                  final success = await _apiService.acceptPasaloRequest(req['id'].toString());
                                  if (success) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Player accepted! Waiting for them to send payment.'), backgroundColor: AppColors.primaryGreen));
                                    _fetchBookings(_userEmail);
                                    _fetchPasaloCourts();
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to accept request.'), backgroundColor: Colors.red));
                                  }
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
                                child: Text('Accept'),
                              );
                            } else if (req['status'] == 'accepted') {
                              trailingButton = ElevatedButton(
                                onPressed: () async {
                                  final success = await _apiService.cancelPasaloAcceptance(req['id'].toString());
                                  if (success) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Acceptance cancelled. Court is back on the Pasalo board.'), backgroundColor: Colors.orange));
                                    _fetchBookings(_userEmail);
                                    _fetchPasaloCourts();
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to cancel.'), backgroundColor: Colors.red));
                                  }
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                child: Text('Cancel'),
                              );
                            } else if (req['status'] == 'payment_sent') {
                              trailingButton = ElevatedButton(
                                onPressed: () async {
                                  final success = await _apiService.approvePasaloRequest(req['id'].toString());
                                  if (success) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment verified! Court transferred.'), backgroundColor: AppColors.primaryGreen));
                                    _fetchBookings(_userEmail);
                                    _fetchPasaloCourts();
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to verify transfer.'), backgroundColor: Colors.red));
                                  }
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                                child: Text('Verify & Transfer'),
                              );
                            }

                            return Card(
                              child: ListTile(
                                title: Text(req['requester_name'] ?? 'Unknown'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Phone: ${req['requester_phone'] ?? 'N/A'}'),
                                    Text('Status: ${req['status']}', style: TextStyle(fontWeight: FontWeight.bold, color: req['status'] == 'pending' ? Colors.orange : (req['status'] == 'accepted' ? Colors.blue : Colors.green))),
                                  ],
                                ),
                                trailing: trailingButton,
                                onTap: () {
                                  if (req['proof_of_payment'] != null) {
                                    showDialog(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: Text('Proof of Payment'),
                                        content: Image.memory(base64Decode(req['proof_of_payment'])),
                                        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('Close'))],
                                      )
                                    );
                                  } else if (req['status'] == 'payment_sent') {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No receipt uploaded.')));
                                  }
                                },
                              ),
                            );
                          },
                        ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Close'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showPostPasaloDialog(dynamic booking) {
    final priceCtrl = TextEditingController(text: booking['total_amount']?.toString() ?? booking['amount']?.toString() ?? '0');
    final notesCtrl = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setStateSB) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Post Court for Pasalo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('Allow another player to assume this booking. Enter the price and payment details.'),
                  SizedBox(height: 24),
                  TextField(
                    controller: priceCtrl,
                    decoration: InputDecoration(labelText: 'Pasalo Price (P)', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: notesCtrl,
                    decoration: InputDecoration(labelText: 'Payment Instructions (e.g. GCash number)', border: OutlineInputBorder()),
                    maxLines: 3,
                  ),
                  SizedBox(height: 24),
                  if (isSubmitting)
                    Center(child: CircularProgressIndicator())
                  else
                    ElevatedButton(
                      onPressed: () async {
                        setStateSB(() => isSubmitting = true);
                        final success = await _apiService.postForPasalo(
                          booking['id'].toString(), 
                          priceCtrl.text, 
                          notesCtrl.text
                        );
                        if (mounted) {
                          if (success) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Posted for Pasalo successfully!'), backgroundColor: AppColors.primaryGreen));
                            _fetchBookings(_userEmail);
                            _fetchPasaloCourts();
                          } else {
                            setStateSB(() => isSubmitting = false);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to post.'), backgroundColor: Colors.red));
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 16)),
                      child: Text('Confirm Post', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showEditOpenPlayDialog(dynamic booking) {
    String type = booking['open_play_type']?.toString().toUpperCase() ?? 'DOUBLES';
    final maxPlayersCtrl = TextEditingController(text: booking['open_play_max_players']?.toString() ?? '4');
    final priceCtrl = TextEditingController(text: booking['open_play_price']?.toString() ?? '0');
    final instructionsCtrl = TextEditingController(text: booking['open_play_instructions']?.toString() ?? '');
    final paymentCtrl = TextEditingController(text: booking['open_play_payment_details']?.toString() ?? '');
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setStateSB) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Edit Open Play', style: TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.bold)),
                      IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text('Format Type', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Row(
                    children: ['SINGLES', 'DOUBLES', 'SOCIAL'].map((t) {
                      final isSelected = type == t;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: t == 'SOCIAL' ? 0 : 8.0),
                          child: InkWell(
                            onTap: () {
                              setStateSB(() {
                                type = t;
                                if (t == 'SINGLES') maxPlayersCtrl.text = '2';
                                else if (t == 'DOUBLES') maxPlayersCtrl.text = '4';
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primaryGreen : Colors.white,
                                border: Border.all(color: isSelected ? AppColors.primaryGreen : Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(t, style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: maxPlayersCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: 'Max Players', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: priceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: 'Price (P)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: instructionsCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(labelText: 'Instructions (Optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: paymentCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(labelText: 'Payment Details (Optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: isSaving ? null : () async {
                        setStateSB(() => isSaving = true);
                        final success = await _apiService.updateOpenPlay(booking['id'], {
                          'openPlayType': type,
                          'openPlayMaxPlayers': int.tryParse(maxPlayersCtrl.text) ?? 4,
                          'openPlayPrice': double.tryParse(priceCtrl.text) ?? 0.0,
                          'openPlayInstructions': instructionsCtrl.text,
                          'openPlayPaymentDetails': paymentCtrl.text,
                        });
                        
                        if (mounted) {
                          setStateSB(() => isSaving = false);
                          if (success) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Updated successfully!'), backgroundColor: AppColors.primaryGreen));
                            _fetchBookings(_userEmail); // Refresh bookings
                            _fetchOpenPlays(); // Refresh open plays
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update.'), backgroundColor: Colors.red));
                          }
                        }
                      },
                      child: isSaving ? CircularProgressIndicator(color: Colors.white) : Text('Save Changes', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCourtsTabView() {
    final allCourts = _courtsList.isNotEmpty ? _courtsList : _sampleCourts;
    return Transform.translate(
      offset: const Offset(0, -100),
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text('All Courts', style: TextStyle(fontFamily: 'Poppins', fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            ),
            SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: allCourts.length,
              separatorBuilder: (context, index) => Divider(
                indent: 72,
                height: 1,
                thickness: 0.5,
                color: Colors.grey.shade300,
              ),
              itemBuilder: (context, index) {
                final court = allCourts[index];
                
                Widget trailingWidget = Text('P${court['price']}/hr', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.richBlack));
                
                if (court['variable_prices'] != null && court['variable_prices'] is List && (court['variable_prices'] as List).isNotEmpty) {
                  final vp = court['variable_prices'] as List;
                  // Try finding 12:00 for day, 18:00 for night
                  var dayPriceObj = vp.firstWhere((p) => p['time'] == '12:00', orElse: () => null);
                  var nightPriceObj = vp.firstWhere((p) => p['time'] == '18:00', orElse: () => null);
                  if (dayPriceObj != null && nightPriceObj != null) {
                    final dayP = dayPriceObj['price'];
                    final nightP = nightPriceObj['price'];
                    if (dayP != nightP) {
                      trailingWidget = Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Day: P$dayP/hr', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.richBlack)),
                          Text('Night: P$nightP/hr', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.richBlack)),
                        ],
                      );
                    }
                  }
                }

                return ListTile(
                  tileColor: Colors.grey.shade50,
                  contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  leading: Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: CustomPaddleIcon(color: AppColors.deepTeal, size: 22),
                  ),
                  title: Text(court['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey.shade800)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 12, color: Colors.grey.shade600),
                          SizedBox(width: 4),
                          Expanded(child: Text(court['address'] ?? 'Cayang, Bogo, Cebu', style: TextStyle(color: Colors.grey.shade600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                      if (court['facilities'] != null && court['facilities'] is List && (court['facilities'] as List).isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: (court['facilities'] as List).map<Widget>((f) {
                              return Container(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGreen.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(f.toString(), style: TextStyle(fontSize: 9, color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                  trailing: trailingWidget,
                  onTap: () {
                    _navigateToBookingScreen(initialServiceName: court['name'], skipServiceSelection: true);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCancelBooking(int bookingId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel Booking'),
        content: Text('Are you sure you want to cancel this booking? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Keep', style: TextStyle(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Cancel Booking', style: TextStyle(color: AppColors.softWhite, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _apiService.cancelUserBooking(bookingId, _userEmail);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Booking cancelled successfully'), backgroundColor: Colors.green),
        );
        _fetchBookings(_userEmail);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel booking'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildBookingsTabView() {
    return DefaultTabController(
      length: 2,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(height: 6),
            TabBar(
            indicatorColor: AppColors.accentLime,
            labelColor: AppColors.accentLime,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'Upcoming (${_upcomingBookings.length})'),
              Tab(text: 'Past (${_pastBookings.length})'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildBookingList(_upcomingBookings, isUpcoming: true),
                _buildBookingList(_pastBookings, isUpcoming: false),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildBookingList(List<dynamic> bookings, {required bool isUpcoming}) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 48, color: Colors.grey.shade300),
            SizedBox(height: 16),
            Text(
              isUpcoming ? 'No upcoming bookings' : 'No past bookings',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.symmetric(vertical: 16),
      itemCount: bookings.length,
      separatorBuilder: (context, index) => Divider(
        indent: 46,
        height: 1,
        thickness: 0.5,
        color: Colors.grey.shade300,
      ),
      itemBuilder: (context, index) {
        final b = bookings[index];
        return Container(
          color: Colors.grey.shade50,
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: CustomPaddleIcon(color: AppColors.deepTeal, size: 22),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b['service_type'] ?? 'Pickleball Court', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey.shade800)),
                    SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        String displayDate = b['appointment_date'] ?? '';
                        try {
                          if (displayDate.isNotEmpty) {
                            final parsedUtc = DateTime.parse(displayDate);
                            final local = parsedUtc.toLocal();
                            displayDate = '${_getMonthAbbr(local.month)} ${local.day}';
                          }
                        } catch (_) {}
                        return Text('$displayDate at ${b['appointment_time'] ?? ''}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13));
                      }
                    ),
                    if (b['court_address'] != null && b['court_address'].toString().isNotEmpty) ...[
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 12, color: Colors.grey.shade500),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              b['court_address'],
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('P${b['total_amount'] ?? b['amount'] ?? '0'}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.richBlack)),
                  if (isUpcoming && b['id'] != null)
                    Builder(builder: (context) {
                      bool isOpenPlay = b['is_open_play'] == true || b['is_open_play'] == 'true' || b['is_open_play'] == 1 || b['is_open_play'] == '1';
                      bool isAssume = b['is_assume'] == true || b['is_assume'] == 'true' || b['is_assume'] == 1 || b['is_assume'] == '1';
                      bool isOpenChallenge = b['is_open_challenge'] == true || b['is_open_challenge'] == 'true' || b['is_open_challenge'] == 1 || b['is_open_challenge'] == '1';
                      
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isOpenPlay && !isAssume && !isOpenChallenge && b['status'] != 'cancelled' && b['status'] != 'completed')
                            TextButton(
                              onPressed: () => _showPostPasaloDialog(b),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.only(right: 8),
                                minimumSize: Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text('Pasalo', style: TextStyle(color: Colors.deepOrange.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          if (isAssume)
                            TextButton(
                              onPressed: () => _showPasaloRequestsDialog(b),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.only(right: 8),
                                minimumSize: Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text('Pasalo Requests', style: TextStyle(color: Colors.deepOrange.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          TextButton(
                            onPressed: () => _confirmCancelBooking(b['id']),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text('Cancel', style: TextStyle(color: Colors.red, fontSize: 12)),
                          ),
                        ],
                      );
                    }),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.softWhite,
        border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedNavIndex,
        onTap: (index) {
          setState(() {
            _selectedNavIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.softWhite,
        selectedItemColor: AppColors.primaryGreen,
        unselectedItemColor: Colors.grey.shade400,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
        elevation: 0,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Courts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_rounded),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildMyPasaloRequestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'My Pasalo Requests',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.5, color: AppColors.deepTeal),
          ),
        ),
        SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 24),
          itemCount: _outgoingPasaloRequests.length,
          separatorBuilder: (context, index) => SizedBox(height: 12),
          itemBuilder: (context, index) {
            final req = _outgoingPasaloRequests[index];
            final date = req['preferred_date']?.split('T')[0] ?? '';
            final time = _normalizeTime(req['preferred_time'] ?? '');
            
            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(req['court_name'] ?? 'Court', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.deepTeal)),
                    SizedBox(height: 4),
                    Text('$date at $time', style: TextStyle(color: Colors.grey.shade600)),
                    Text('Owner: ${req['owner_name']} | Price: P${req['assume_price'] ?? '0'}', style: TextStyle(color: Colors.grey.shade800)),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Text('Status: ', style: TextStyle(color: Colors.grey.shade700)),
                        Text(
                          req['status'] == 'pending' ? 'Pending Approval' : 
                          (req['status'] == 'accepted' ? 'Accepted - Payment Required' : 
                          (req['status'] == 'payment_sent' ? 'Payment Uploaded - Verifying' : req['status'])),
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            color: req['status'] == 'pending' ? Colors.orange : 
                                   (req['status'] == 'accepted' ? Colors.red : AppColors.primaryGreen)
                          ),
                        ),
                      ],
                    ),
                    if (req['status'] == 'accepted') ...[
                      SizedBox(height: 16),
                      Text('Payment Details:', style: TextStyle(fontWeight: FontWeight.bold)),
                      if (req['gcash_number'] != null && req['gcash_number'].isNotEmpty) Text('GCash: ${req['gcash_number']}'),
                      if (req['bank_account'] != null && req['bank_account'].isNotEmpty) Text('Bank: ${req['bank_account']} (${req['bank_account_name']})'),
                      SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _showUploadPaymentDialog(req),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
                          child: Text('Upload Proof of Payment'),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showUploadPaymentDialog(dynamic req) {
    String? base64Image;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setStateSB) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Upload Payment', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 16),
                  Text('Please send the exact amount and upload a clear screenshot of the receipt.'),
                  SizedBox(height: 16),
                  
                  GestureDetector(
                    onTap: () async {
                      final ImagePicker _picker = ImagePicker();
                      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
                      if (image != null) {
                        final bytes = await image.readAsBytes();
                        setStateSB(() {
                          base64Image = base64Encode(bytes);
                        });
                      }
                    },
                    child: Container(
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: base64Image != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(base64Decode(base64Image!), fit: BoxFit.cover),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.upload_file, size: 40, color: Colors.grey.shade400),
                                SizedBox(height: 8),
                                Text('Tap to upload receipt', style: TextStyle(color: Colors.grey.shade600)),
                              ],
                            ),
                    ),
                  ),
                  
                  SizedBox(height: 24),
                  if (isSubmitting)
                    Center(child: CircularProgressIndicator())
                  else
                    ElevatedButton(
                      onPressed: () async {
                        if (base64Image == null) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please upload a proof of payment')));
                          return;
                        }
                        
                        setStateSB(() => isSubmitting = true);
                        final success = await _apiService.uploadPasaloPayment(req['id'].toString(), base64Image!);
                        
                        if (mounted) {
                          if (success) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Receipt uploaded successfully!'), backgroundColor: AppColors.primaryGreen));
                            _fetchOutgoingPasaloRequests();
                          } else {
                            setStateSB(() => isSubmitting = false);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload receipt'), backgroundColor: Colors.red));
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 16)),
                      child: Text('Submit Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPasaloCourtsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'Pasalo Courts',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.5, color: AppColors.deepTeal),
              ),
              if (_pasaloCourts.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PasaloCourtsScreen(),
                      ),
                    );
                  },
                  child: Text('See All', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
            ],
          ),
        ),
        SizedBox(height: 16),
        if (_pasaloCourts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                CustomPaddleIcon(color: Colors.grey.shade400),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'No pasalo courts available right now.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          )
        else
          SizedBox(
            height: 190,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              scrollDirection: Axis.horizontal,
              itemCount: _pasaloCourts.length,
              separatorBuilder: (context, index) => SizedBox(width: 16),
              itemBuilder: (context, index) {
                final pasalo = _pasaloCourts[index];
                
                final String rawTimeStr = _normalizeTime(pasalo['preferred_time'] ?? '');
                final String timeStr = rawTimeStr.replaceAll(':00', '').replaceAll(' AM', 'AM').replaceAll(' PM', 'PM');
                String month = '';
                String day = '';
                try {
                  final date = DateTime.parse(pasalo['preferred_date']?.split('T')[0] ?? '');
                  const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
                  month = months[date.month - 1];
                  day = date.day.toString();
                } catch(e) {
                  month = 'TBA';
                  day = '-';
                }
                
                final content = Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: MediaQuery.of(context).size.width - 48,
                      margin: EdgeInsets.only(top: 6, left: 6, bottom: 6),
                      decoration: BoxDecoration(
                        color: AppColors.softWhite,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: AppColors.richBlack.withOpacity(0.08), blurRadius: 10, offset: Offset(0, 4)),
                        ],
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Left side: Date Block
                          Container(
                            width: 72,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.orange.shade400, Colors.deepOrange],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(month, style: TextStyle(color: AppColors.softWhite.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                Text(day, style: TextStyle(color: AppColors.softWhite, fontSize: 26, fontWeight: FontWeight.w900, height: 1.1)),
                                SizedBox(height: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.richBlack.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(timeStr, style: TextStyle(color: AppColors.softWhite, fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                          
                          // Right side: Details
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(pasalo['court_name'] ?? 'Court', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.deepTeal), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            SizedBox(height: 2),
                                            Text('Owner: ${pasalo['current_owner_name'] ?? 'Unknown'}', style: TextStyle(color: AppColors.stoneGray, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            SizedBox(height: 2),
                                            Row(
                                              children: [
                                                Icon(Icons.location_on, size: 10, color: Colors.grey),
                                                SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    pasalo['court_address'] != null && pasalo['court_address'].isNotEmpty ? pasalo['court_address'] : 'Address not provided',
                                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  )
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 2),
                                            Text('Price: P${pasalo['assume_price'] ?? '0'}', style: TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  Spacer(),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 32,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => PasaloCourtsScreen(),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                        padding: EdgeInsets.zero,
                                      ),
                                      child: Text('Assume', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PasaloCourtsScreen(),
                      ),
                    );
                  },
                  child: content,
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSportCategoryChip(String catKey, String label) {
    final bool isSelected = _selectedSportCategory == catKey;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? AppColors.softWhite : AppColors.richBlack,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primaryGreen,
      backgroundColor: Colors.white,
      elevation: isSelected ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? AppColors.primaryGreen : Colors.grey.shade300),
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedSportCategory = catKey;
          });
        }
      },
    );
  }

  Widget _buildVenueCard(Map<String, dynamic> venue, String venueId, bool isFav) {
    final List<dynamic> courts = venue['courts'] ?? [];
    final List<dynamic> sports = venue['sports'] ?? ['Pickleball'];

    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: AppColors.softWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: AppColors.richBlack.withOpacity(0.05), blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () {
          _showVenueBookingModal(context, venue);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Image Header
            Container(
              width: double.infinity,
              height: 100,
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen,
                image: venue['image'] != null && venue['image'].toString().isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(venue['image']),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken),
                      )
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CustomPaddleIcon(color: AppColors.softWhite, size: 14),
                          SizedBox(width: 4),
                          Text(venue['rating'] ?? '4.8', style: TextStyle(color: AppColors.softWhite, fontSize: 11, fontWeight: FontWeight.bold)),
                          Icon(Icons.star, color: Colors.amber, size: 11),
                        ],
                      ),
                      InkWell(
                        onTap: () {
                          setState(() {
                            if (isFav) {
                              _favoriteCourts.remove(venueId);
                            } else {
                              _favoriteCourts.add(venueId);
                            }
                          });
                        },
                        child: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          color: isFav ? Colors.red : AppColors.softWhite,
                          size: 14,
                        ),
                      )
                    ],
                  ),
                  Row(
                    children: [
                      if (venue['logo_url'] != null && venue['logo_url'].toString().trim().isNotEmpty) ...[
                        Container(
                          width: 22,
                          height: 22,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                          child: ClipOval(
                            child: Image.network(
                              venue['logo_url'].toString().trim(),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(Icons.business, size: 12, color: AppColors.primaryGreen),
                            ),
                          ),
                        ),
                      ],
                      Expanded(
                        child: Text(
                          venue['venueName'] ?? 'Venue',
                          style: TextStyle(color: AppColors.softWhite, fontSize: 12, fontWeight: FontWeight.bold),
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // 2. Highlight Strip (Court Count & Price)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              color: Color(0xFFE8F5E9),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${courts.length} ${courts.length == 1 ? 'Court' : 'Courts'} Available',
                    style: TextStyle(color: AppColors.primaryGreen, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'From P${venue['basePrice']}/hr',
                    style: TextStyle(color: AppColors.primaryGreen, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            
            // 3. White Body
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      venue['address'] ?? 'Cayang, Bogo',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.richBlack),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      children: sports.map<Widget>((sp) {
                        return Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                          child: Text(
                            sp == 'Pickleball' ? '🏓 Pickleball' : '🎾 Tennis',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.deepTeal),
                          ),
                        );
                      }).toList(),
                    ),
                    Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 32,
                      child: ElevatedButton(
                        onPressed: () {
                          _showVenueBookingModal(context, venue);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text('Book Court', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVenueBookingModal(BuildContext context, Map<String, dynamic> venue) {
    final List<dynamic> allVenueCourts = venue['courts'] ?? [];
    String modalSportCategory = 'ALL';
    Map<String, Map<String, dynamic>> selectedSlotsMap = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            // Filter courts by modal sport category
            final List<dynamic> filteredModalCourts = allVenueCourts.where((c) {
              if (modalSportCategory == 'ALL') return true;
              final name = (c['name'] ?? '').toString().toLowerCase();
              final desc = (c['description'] ?? '').toString().toLowerCase();
              if (modalSportCategory == 'Tennis') {
                return name.contains('tennis') || desc.contains('tennis');
              }
              if (modalSportCategory == 'Pickleball') {
                return name.contains('pickle') || desc.contains('pickle') || !name.contains('tennis');
              }
              return true;
            }).toList();

            final displayCourts = filteredModalCourts.isNotEmpty ? filteredModalCourts : allVenueCourts;

            double totalPrice = selectedSlotsMap.values.fold(0.0, (sum, item) => sum + (double.tryParse(item['price'].toString()) ?? 300.0));
            int totalSelectedCount = selectedSlotsMap.length;

            return Container(
              decoration: BoxDecoration(
                color: AppColors.softWhite,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              height: MediaQuery.of(ctx).size.height * 0.88,
              padding: EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      if (venue['logo_url'] != null && venue['logo_url'].toString().trim().isNotEmpty) ...[
                        ClipOval(
                          child: Image.network(venue['logo_url'], width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.business, size: 28, color: AppColors.primaryGreen)),
                        ),
                        SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(venue['venueName'] ?? 'Venue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.richBlack)),
                            SizedBox(height: 2),
                            Text(venue['address'] ?? '', style: TextStyle(color: Colors.grey.shade600, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  SizedBox(height: 12),
                  
                  // Sport Category Chips inside Venue Modal
                  Row(
                    children: [
                      Text('Sport: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.richBlack)),
                      SizedBox(width: 4),
                      ChoiceChip(
                        label: Text('🎾 ALL', style: TextStyle(fontSize: 11, fontWeight: modalSportCategory == 'ALL' ? FontWeight.bold : FontWeight.normal, color: modalSportCategory == 'ALL' ? Colors.white : AppColors.richBlack)),
                        selected: modalSportCategory == 'ALL',
                        selectedColor: AppColors.primaryGreen,
                        backgroundColor: Colors.grey.shade100,
                        onSelected: (val) { if (val) setModalState(() => modalSportCategory = 'ALL'); },
                      ),
                      SizedBox(width: 6),
                      ChoiceChip(
                        label: Text('🏓 Pickleball', style: TextStyle(fontSize: 11, fontWeight: modalSportCategory == 'Pickleball' ? FontWeight.bold : FontWeight.normal, color: modalSportCategory == 'Pickleball' ? Colors.white : AppColors.richBlack)),
                        selected: modalSportCategory == 'Pickleball',
                        selectedColor: AppColors.primaryGreen,
                        backgroundColor: Colors.grey.shade100,
                        onSelected: (val) { if (val) setModalState(() => modalSportCategory = 'Pickleball'); },
                      ),
                      SizedBox(width: 6),
                      ChoiceChip(
                        label: Text('🎾 Tennis', style: TextStyle(fontSize: 11, fontWeight: modalSportCategory == 'Tennis' ? FontWeight.bold : FontWeight.normal, color: modalSportCategory == 'Tennis' ? Colors.white : AppColors.richBlack)),
                        selected: modalSportCategory == 'Tennis',
                        selectedColor: AppColors.primaryGreen,
                        backgroundColor: Colors.grey.shade100,
                        onSelected: (val) { if (val) setModalState(() => modalSportCategory = 'Tennis'); },
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 12),
                  Divider(height: 1),
                  SizedBox(height: 12),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Side-by-Side Courts & Timeslots', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.deepTeal)),
                      Text('Tap to select multiple', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                    ],
                  ),
                  SizedBox(height: 10),

                  // Side-by-Side Courts Columns View
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: displayCourts.map<Widget>((court) {
                                final courtName = court['name'] ?? 'Court';
                                final courtPrice = court['price'] ?? venue['basePrice'] ?? '300';
                                final List<dynamic> rawSlots = court['slots'] ?? ['8:00 AM', '9:00 AM', '10:00 AM', '11:00 AM', '1:00 PM', '2:00 PM', '3:00 PM', '4:00 PM', '5:00 PM'];

                                return Container(
                                  width: 140,
                                  margin: EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppColors.primaryGreen.withOpacity(0.3)),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: Offset(0, 3)),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      // Court Header Column
                                      Container(
                                        width: double.infinity,
                                        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryGreen,
                                          borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                                        ),
                                        child: Column(
                                          children: [
                                            Text(
                                              courtName,
                                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              'P$courtPrice/hr',
                                              style: TextStyle(color: AppColors.accentLime, fontSize: 11, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      // Timeslot Buttons Under Court
                                      Padding(
                                        padding: EdgeInsets.all(8),
                                        child: Column(
                                          children: rawSlots.map<Widget>((s) {
                                            final slotStr = s.toString();
                                            final slotKey = '${courtName}_$slotStr';
                                            final bool isSelected = selectedSlotsMap.containsKey(slotKey);

                                            return Container(
                                              margin: EdgeInsets.only(bottom: 6),
                                              width: double.infinity,
                                              child: InkWell(
                                                onTap: () {
                                                  setModalState(() {
                                                    if (isSelected) {
                                                      selectedSlotsMap.remove(slotKey);
                                                    } else {
                                                      selectedSlotsMap[slotKey] = {
                                                        'court': courtName,
                                                        'time': slotStr,
                                                        'price': courtPrice,
                                                      };
                                                    }
                                                  });
                                                },
                                                borderRadius: BorderRadius.circular(8),
                                                child: Container(
                                                  padding: EdgeInsets.symmetric(vertical: 8),
                                                  decoration: BoxDecoration(
                                                    color: isSelected ? AppColors.primaryGreen : Colors.grey.shade100,
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: isSelected ? AppColors.primaryGreen : Colors.grey.shade300),
                                                    boxShadow: isSelected ? [BoxShadow(color: AppColors.primaryGreen.withOpacity(0.3), blurRadius: 4)] : [],
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      if (isSelected) ...[
                                                        Icon(Icons.check_circle, size: 12, color: Colors.white),
                                                        SizedBox(width: 4),
                                                      ],
                                                      Text(
                                                        slotStr,
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                                          color: isSelected ? Colors.white : AppColors.richBlack,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          SizedBox(height: 20),
                          if (venue['aboutVenue'] != null && venue['aboutVenue'].toString().trim().isNotEmpty) ...[
                            Text('About Venue', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.richBlack)),
                            SizedBox(height: 6),
                            Text(venue['aboutVenue'].toString(), style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                            SizedBox(height: 16),
                          ],
                          if (venue['bookingPolicy'] != null && venue['bookingPolicy'].toString().trim().isNotEmpty) ...[
                            Text('Booking Policy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.richBlack)),
                            SizedBox(height: 6),
                            Text(venue['bookingPolicy'].toString(), style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                            SizedBox(height: 16),
                          ],
                          if (venue['faq'] != null && venue['faq'].toString().trim().isNotEmpty) ...[
                            Text('Frequently Asked Questions (FAQ)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.richBlack)),
                            SizedBox(height: 6),
                            Text(venue['faq'].toString(), style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                            SizedBox(height: 16),
                          ],
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  // Selection Summary & Primary Booking Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: totalSelectedCount == 0 ? null : () {
                        Navigator.pop(ctx);
                        final firstItem = selectedSlotsMap.values.first;
                        _navigateToBookingScreen(
                          initialServiceName: firstItem['court'],
                          skipServiceSelection: true,
                          initialTime: firstItem['time'],
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        totalSelectedCount == 0
                            ? 'Select Timeslot(s) to Rent'
                            : 'Book $totalSelectedCount ${totalSelectedCount == 1 ? 'Slot' : 'Slots'} — Total P${totalPrice.toInt()}',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _NextBookingCarousel extends StatefulWidget {
  final List<dynamic> bookings;
  final Function(dynamic) onView;
  final Function(dynamic) onGetDirection;
  final Function(dynamic) onPasalo;
  final String Function(int) getWeekday;
  final String Function(int) getMonth;

  const _NextBookingCarousel({
    required this.bookings,
    required this.onView,
    required this.onGetDirection,
    required this.onPasalo,
    required this.getWeekday,
    required this.getMonth,
  });

  @override
  State<_NextBookingCarousel> createState() => _NextBookingCarouselState();
}

class _NextBookingCarouselState extends State<_NextBookingCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(() {
      final page = _pageController.page?.round() ?? 0;
      if (page != _currentPage) {
        setState(() => _currentPage = page);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 185,
      child: PageView.builder(
        controller: _pageController,
        itemCount: widget.bookings.length,
        itemBuilder: (context, index) {
          final booking = widget.bookings[index];
          String dateStr = '';

          try {
            if (booking['appointment_date'] != null) {
              final DateTime parsedUtc = DateTime.parse(booking['appointment_date'].toString());
              final DateTime local = parsedUtc.toLocal();
              dateStr = '${widget.getWeekday(local.weekday)}, ${widget.getMonth(local.month)} ${local.day}';
            }
          } catch (_) {}

          final int distance = (index - _currentPage).abs();

          final String rawStatus = (booking['status'] ?? 'confirmed').toString();
          final String displayStatus = rawStatus[0].toUpperCase() + rawStatus.substring(1);

          bool isOpenPlay = booking['is_open_play'] == true || booking['is_open_play'] == 'true' || booking['is_open_play'] == 1 || booking['is_open_play'] == '1';
          bool isAssume = booking['is_assume'] == true || booking['is_assume'] == 'true' || booking['is_assume'] == 1 || booking['is_assume'] == '1';
          bool isOpenChallenge = booking['is_open_challenge'] == true || booking['is_open_challenge'] == 'true' || booking['is_open_challenge'] == 1 || booking['is_open_challenge'] == '1';
          String bStatus = (booking['status'] ?? '').toString().toLowerCase();
          bool showPasalo = !isOpenPlay && !isAssume && !isOpenChallenge && bStatus != 'cancelled' && bStatus != 'completed';

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Stack(
              children: [
                // Card body
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),

                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.accentLime,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [

                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Top row: badge + ID
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.richBlack.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.calendar_today, size: 10, color: AppColors.richBlack),
                                          const SizedBox(width: 4),
                                          Text(isOpenPlay ? 'Open Play' : (isOpenChallenge ? 'Open Challenge' : 'My Booking'), style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.richBlack)),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        if (isAssume)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                            margin: const EdgeInsets.only(right: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.shade900,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Text('PASALO POSTED', style: TextStyle(fontFamily: 'Poppins', fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                                          ),
                                        if (booking['id'] != null)
                                          Text(
                                            '#${booking['id']}',
                                            style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.richBlack.withOpacity(0.7)),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                // Service name
                                Text(
                                  booking['service_type'] ?? 'Court Booking',
                                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.richBlack, letterSpacing: -0.3),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  booking['court_address'] ?? '',
                                  style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.richBlack.withOpacity(0.8)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                // Date & time
                                Row(
                                  children: [
                                    const Icon(Icons.event, size: 13, color: AppColors.richBlack),
                                    const SizedBox(width: 4),
                                    Text(dateStr, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.richBlack)),
                                    const SizedBox(width: 12),
                                    Icon(Icons.access_time, size: 13, color: AppColors.richBlack.withOpacity(0.70)),
                                    const SizedBox(width: 4),
                                    Text(
                                      booking['appointment_time'] ?? 'N/A',
                                      style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.richBlack.withOpacity(0.85)),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                // Buttons
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    GestureDetector(
                                      onTap: () => widget.onView(booking),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: AppColors.richBlack,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: const Text('View Details', style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.softWhite)),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () => widget.onGetDirection(booking),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.transparent,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: AppColors.richBlack.withOpacity(0.3)),
                                        ),
                                        child: const Text('Directions', style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.richBlack)),
                                      ),
                                    ),
                                    if (showPasalo) ...[
                                      const SizedBox(width: 6),
                                      GestureDetector(
                                        onTap: () => widget.onPasalo(booking),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.deepOrange.shade700,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: const Text('Pasalo', style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ), // closes inner Container
                ), // closes outer Container
              ],
            ),
          );
        },
      ),
    );
  }

}

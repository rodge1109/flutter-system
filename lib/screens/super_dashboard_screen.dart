import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'earnings_screen.dart';
import 'inbox_screen.dart';
import 'login_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';

class SuperDashboardScreen extends StatefulWidget {
  @override
  _SuperDashboardScreenState createState() => _SuperDashboardScreenState();
}

class _SuperDashboardScreenState extends State<SuperDashboardScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;

  List<dynamic> _allBookings = [];
  List<dynamic> _allCourts = [];
  
  // Navigation & Filter States
  String _currentTab = 'calendar'; // 'calendar', 'upcoming', 'courts'
  String _selectedVenueKey = 'ALL'; // 'ALL' or 'VenueName (owner_email)'
  String _selectedStatus = 'ALL';
  String _searchQuery = '';

  final TextEditingController _searchController = TextEditingController();

  // Calendar States
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Disabled Venues / Owners Tracking
  Set<String> _disabledVenues = {};
  Set<String> _disabledOwners = {};

  // Unread badges
  int _unreadMessageCount = 0;
  int _unreadCount = 0;
  String _userEmail = 'superadmin@system.com';
  String _userName = 'Super Admin';

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadUserData();
    _loadDisabledLists();
    _loadDashboardData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    if (userStr != null) {
      try {
        final userData = json.decode(userStr);
        setState(() {
          _userName = userData['name'] ?? userData['full_name'] ?? 'Super Admin';
          _userEmail = userData['email'] ?? 'superadmin@system.com';
        });
      } catch (_) {}
    }
  }

  Future<void> _loadDisabledLists() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _disabledVenues = (prefs.getStringList('deactivated_venues') ?? []).map((e) => e.toLowerCase()).toSet();
        _disabledOwners = (prefs.getStringList('deactivated_owners') ?? []).map((e) => e.toLowerCase()).toSet();
      });
    }
  }

  bool _isVenueCurrentlyActive(String venueName, String ownerEmail) {
    String vKey = venueName.trim().toLowerCase();
    String oKey = ownerEmail.trim().toLowerCase();
    if (_disabledVenues.contains(vKey) || (oKey.isNotEmpty && _disabledOwners.contains(oKey))) {
      return false;
    }
    return true;
  }

  Future<void> _handleToggleVenueActivation(String venueName, String ownerEmail, dynamic courtId, bool currentStatus) async {
    bool nextStatus = !currentStatus;
    bool success = await _apiService.toggleCourtActivation(courtId, venueName, ownerEmail, nextStatus);

    if (success) {
      await _loadDisabledLists();
      setState(() {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nextStatus
                  ? '🟢 $venueName has been ACTIVATED and is visible to users.'
                  : '🔴 $venueName is DEACTIVATED and hidden from users.',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
            ),
            backgroundColor: nextStatus ? AppColors.primaryGreen : Colors.redAccent,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    await _loadDisabledLists();
    
    // Load cached bookings if available
    final prefs = await SharedPreferences.getInstance();
    final cachedBookingsStr = prefs.getString('super_admin_cached_bookings');
    if (cachedBookingsStr != null) {
      try {
        final cached = json.decode(cachedBookingsStr);
        if (cached is List && cached.isNotEmpty) {
          _allBookings = cached;
          setState(() => _isLoading = false);
        }
      } catch (_) {}
    }

    try {
      final results = await Future.wait([
        _apiService.fetchSuperAdminBookings(),
        _apiService.fetchRawServices(),
      ]);

      final List fetchedBookings = results[0] as List;
      final List rawServices = results[1] as List;

      if (fetchedBookings.isNotEmpty) {
        _allBookings = fetchedBookings;
        await prefs.setString('super_admin_cached_bookings', json.encode(fetchedBookings));
      }
      
      _allCourts = rawServices;
    } catch (e) {
      print('Super Dashboard fetch error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Precise Venue Matching Helper (Differentiates multi-venue court owners)
  bool _isBookingForSelectedVenue(dynamic b) {
    if (_selectedVenueKey == 'ALL') return true;

    String venueName = (b['court_name'] ?? b['venue_name'] ?? b['service_type'] ?? '').toString().trim().toLowerCase();
    String ownerEmail = (b['owner_email'] ?? b['court_owner'] ?? b['owner'] ?? '').toString().trim().toLowerCase();

    String targetVenue = _selectedVenueKey;
    String targetEmail = '';
    if (_selectedVenueKey.contains('(') && _selectedVenueKey.endsWith(')')) {
      int openParen = _selectedVenueKey.lastIndexOf('(');
      targetVenue = _selectedVenueKey.substring(0, openParen).trim().toLowerCase();
      targetEmail = _selectedVenueKey.substring(openParen + 1, _selectedVenueKey.length - 1).trim().toLowerCase();
    } else {
      targetVenue = _selectedVenueKey.trim().toLowerCase();
    }

    // 1. If owner email is present and DOES NOT match target owner email, it is NOT a match
    if (targetEmail.isNotEmpty && ownerEmail.isNotEmpty && targetEmail != ownerEmail) {
      return false;
    }

    // 2. Exact or clean venue name match
    if (venueName.isNotEmpty && targetVenue.isNotEmpty) {
      String cleanVenueName = venueName.replaceAll(RegExp(r'\s*\([^)]*\)'), '').split('-')[0].trim();
      String cleanTargetVenue = targetVenue.replaceAll(RegExp(r'\s*\([^)]*\)'), '').split('-')[0].trim();

      if (venueName == targetVenue ||
          cleanVenueName == cleanTargetVenue ||
          venueName.contains(targetVenue) ||
          targetVenue.contains(venueName) ||
          cleanVenueName.contains(cleanTargetVenue) ||
          cleanTargetVenue.contains(cleanVenueName)) {
        return true;
      }
      return false;
    }

    // Fallback if booking venue name is empty but email matches
    if (venueName.isEmpty && targetEmail.isNotEmpty && ownerEmail == targetEmail) {
      return true;
    }

    return false;
  }

  // Filter Bookings by Selected Venue Dropdown, Status, and Search Query
  List<dynamic> _getFilteredBookings() {
    return _allBookings.where((b) {
      final status = (b['status'] ?? '').toString().toLowerCase();
      if (status == 'cancelled' || status == 'blocked' || status == 'rejected') return false;

      // Status Filter
      if (_selectedStatus != 'ALL') {
        String bStatus = (b['status'] ?? 'confirmed').toString().toUpperCase();
        if (bStatus != _selectedStatus) return false;
      }

      // Venue Dropdown Filter
      if (!_isBookingForSelectedVenue(b)) return false;

      // Search Query
      if (_searchQuery.trim().isNotEmpty) {
        String query = _searchQuery.toLowerCase().trim();
        String venue = (b['court_name'] ?? b['venue_name'] ?? b['service_type'] ?? '').toString().toLowerCase();
        String owner = (b['owner_email'] ?? b['court_owner'] ?? '').toString().toLowerCase();
        String customer = (b['player_name'] ?? b['full_name'] ?? b['user_email'] ?? '').toString().toLowerCase();
        String id = (b['id'] ?? '').toString().toLowerCase();

        if (!venue.contains(query) && !owner.contains(query) && !customer.contains(query) && !id.contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  // Filter Registered Courts for Venues Tab
  List<dynamic> _getFilteredCourts() {
    if (_selectedVenueKey == 'ALL') return _allCourts;
    
    return _allCourts.where((c) {
      String vName = (c['name'] ?? c['venue_name'] ?? '').toString().trim();
      String oEmail = (c['owner_email'] ?? c['ownerEmail'] ?? '').toString().trim();
      String key = '$vName (${oEmail.isNotEmpty ? oEmail : "rodge1109@yahoo.com"})';
      
      if (key == _selectedVenueKey) return true;
      
      if (_selectedVenueKey.contains('(') && _selectedVenueKey.endsWith(')')) {
        int openParen = _selectedVenueKey.lastIndexOf('(');
        String targetVenue = _selectedVenueKey.substring(0, openParen).trim().toLowerCase();
        String targetEmail = _selectedVenueKey.substring(openParen + 1, _selectedVenueKey.length - 1).trim().toLowerCase();
        
        String cleanVName = vName.replaceAll(RegExp(r'\s*\([^)]*\)'), '').split('-')[0].trim().toLowerCase();
        String cleanTargetVenue = targetVenue.replaceAll(RegExp(r'\s*\([^)]*\)'), '').split('-')[0].trim().toLowerCase();

        if (oEmail.isNotEmpty && oEmail.toLowerCase() == targetEmail && cleanVName == cleanTargetVenue) {
          return true;
        }
      }
      return false;
    }).toList();
  }

  // Group Bookings into Checkout Sessions for Platform Fee Calculation
  Map<String, double> _calculateFinancials() {
    List<dynamic> filtered = _getFilteredBookings();
    Map<String, Map<String, dynamic>> sessionMap = {};

    for (var b in filtered) {
      String player = (b['player_name'] ?? b['full_name'] ?? 'Player').toString().trim();
      String court = (b['court_name'] ?? b['venue_name'] ?? b['service_type'] ?? 'Court').toString().trim();
      String date = (b['preferred_date'] ?? b['appointment_date'] ?? b['date'] ?? '').toString().trim();
      String createdAt = (b['created_at'] ?? '').toString().trim();
      String createdMinute = createdAt.length >= 16 ? createdAt.substring(0, 16) : createdAt;

      String sessionKey = '${player}_${court}_${date}_$createdMinute';

      if (!sessionMap.containsKey(sessionKey)) {
        sessionMap[sessionKey] = {
          'courtAmount': 0.0,
          'time_list': <String>[],
        };
      }

      double slotAmount = 0;
      if (b['total_amount'] != null) {
        slotAmount = (b['total_amount'] is num) ? (b['total_amount'] as num).toDouble() : (double.tryParse(b['total_amount'].toString()) ?? 0);
      } else if (b['amount'] != null) {
        slotAmount = (b['amount'] is num) ? (b['amount'] as num).toDouble() : (double.tryParse(b['amount'].toString()) ?? 0);
      }

      sessionMap[sessionKey]!['courtAmount'] = (sessionMap[sessionKey]!['courtAmount'] as double) + slotAmount;

      String slotTime = (b['preferred_time'] ?? b['appointment_time'] ?? '').toString().trim();
      if (slotTime.isNotEmpty && !(sessionMap[sessionKey]!['time_list'] as List<String>).contains(slotTime)) {
        (sessionMap[sessionKey]!['time_list'] as List<String>).add(slotTime);
      }
    }

    double totalGross = 0;
    double totalAppFee = 0;
    double totalNetOwners = 0;

    for (var session in sessionMap.values) {
      List<String> times = List<String>.from(session['time_list']);
      int hours = times.isNotEmpty ? times.length : 1;

      // ₱15 per 5-hour checkout block rule
      double fee = (hours / 5.0).ceil() * 15.0;
      double courtAmount = (session['courtAmount'] as double);

      totalGross += courtAmount + fee;
      totalAppFee += fee;
      totalNetOwners += courtAmount;
    }

    return {
      'gross': totalGross,
      'appFee': totalAppFee,
      'net': totalNetOwners,
      'sessions': sessionMap.length.toDouble(),
    };
  }

  // Calendar Event Loader
  List<dynamic> _getBookingsForDay(DateTime day) {
    String dayString = DateFormat('yyyy-MM-dd').format(day);
    List<dynamic> filtered = _getFilteredBookings();

    return filtered.where((b) {
      String? dateStr = b['preferred_date'] ?? b['appointment_date'] ?? b['date'];
      if (dateStr == null) return false;
      try {
        String formatted = dateStr.toString().split('T')[0].trim();
        return formatted == dayString;
      } catch (_) {
        return false;
      }
    }).toList();
  }

  DateTime _parseTime(String timeString) {
    if (timeString.isEmpty) return DateTime(2000);
    try {
      int hour = int.parse(timeString.split(':')[0]);
      int minute = int.parse(timeString.split(':')[1].substring(0, 2));
      bool isPM = timeString.toUpperCase().contains('PM');
      
      if (isPM && hour < 12) hour += 12;
      if (!isPM && hour == 12) hour = 0;
      
      return DateTime(2000, 1, 1, hour, minute);
    } catch (_) {
      return DateTime(2000);
    }
  }

  String _formatDateCreated(dynamic dateInput) {
    if (dateInput == null || dateInput.toString().trim().isEmpty) return 'N/A';
    try {
      String raw = dateInput.toString().trim();
      raw = raw.replaceAll(RegExp(r'Z$', caseSensitive: false), '');
      final parsed = DateTime.parse(raw);
      return DateFormat('MMM d, yyyy • h:mm a').format(parsed);
    } catch (_) {
      return dateInput.toString();
    }
  }

  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.toLowerCase().split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final financials = _calculateFinancials();
    final double appFeeEarnings = financials['appFee']!;
    final List<dynamic> filteredBookings = _getFilteredBookings();
    final List<dynamic> filteredCourts = _getFilteredCourts();

    // Prepare Venue Dropdown Items
    Set<String> venueOptions = {'ALL'};
    for (var c in _allCourts) {
      String vName = (c['name'] ?? c['venue_name'] ?? 'Court Venue').toString().trim();
      String oEmail = (c['owner_email'] ?? c['ownerEmail'] ?? '').toString().trim();
      venueOptions.add('$vName (${oEmail.isNotEmpty ? oEmail : "rodge1109@yahoo.com"})');
    }

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        title: SizedBox(
          height: 32,
          child: Image.asset(
            'assets/logo_small.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            isAntiAlias: true,
          ),
        ),
        actions: [
          Badge(
            isLabelVisible: _unreadMessageCount > 0,
            label: Text(_unreadMessageCount.toString()),
            offset: const Offset(-8, 8),
            backgroundColor: Colors.redAccent,
            child: IconButton(
              icon: Icon(Icons.chat_bubble_outline, color: AppColors.richBlack, size: 24),
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => InboxScreen()));
              },
            ),
          ),
          Badge(
            isLabelVisible: _unreadCount > 0,
            label: Text(_unreadCount.toString()),
            offset: const Offset(-8, 8),
            child: IconButton(
              icon: Icon(Icons.notifications_outlined, color: AppColors.richBlack),
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsScreen()));
              },
            ),
          ),
          IconButton(
            icon: Icon(Icons.person_outline, color: AppColors.richBlack),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen()));
              _loadUserData();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: AppColors.richBlack))
        : RefreshIndicator(
            color: AppColors.primaryGreen,
            onRefresh: () => _loadDashboardData(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // Top Header & Earnings Card (Identical Layout to Court Owner Dashboard)
                  Padding(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + kToolbarHeight + 16.0, 
                      bottom: 12.0
                    ),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primaryGreen.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // User Name & Role Dropdown Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'Hi, ${_toTitleCase(_userName)}',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.richBlack,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryGreen.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(color: AppColors.primaryGreen, width: 1),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: 'super_admin',
                                              dropdownColor: Colors.white,
                                              icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primaryGreen, size: 16),
                                              isDense: true,
                                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryGreen, fontFamily: 'Poppins'),
                                              onChanged: (val) async {
                                                if (val == 'signout') {
                                                  final prefs = await SharedPreferences.getInstance();
                                                  await prefs.remove('user');
                                                  if (!mounted) return;
                                                  Navigator.of(context).pushAndRemoveUntil(
                                                    MaterialPageRoute(builder: (context) => LoginScreen()),
                                                    (Route<dynamic> route) => false,
                                                  );
                                                }
                                              },
                                              items: const [
                                                DropdownMenuItem(
                                                  value: 'super_admin',
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.admin_panel_settings_rounded, size: 12, color: AppColors.primaryGreen),
                                                      SizedBox(width: 3),
                                                      Text('Super Admin', style: TextStyle(color: AppColors.primaryGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                                                    ],
                                                  ),
                                                ),
                                                DropdownMenuItem(
                                                  value: 'signout',
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.logout_rounded, size: 12, color: Colors.redAccent),
                                                      SizedBox(width: 3),
                                                      Text('Sign Out', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Super Admin Dashboard',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                              // Platform Fee Earnings Counter (Follows Selected Venue)
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => EarningsScreen()),
                                  );
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text(
                                          'App Fee Income',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.richBlack,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.richBlack),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '₱${appFeeEarnings.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primaryGreen,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),
                          Divider(color: AppColors.primaryGreen.withOpacity(0.15), height: 1),
                          const SizedBox(height: 14),

                          // VENUE SELECTOR DROPDOWN
                          Row(
                            children: [
                              Icon(Icons.storefront_rounded, size: 18, color: AppColors.primaryGreen),
                              const SizedBox(width: 8),
                              Text(
                                'Venue:',
                                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.richBlack),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.primaryGreen.withOpacity(0.4)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: venueOptions.contains(_selectedVenueKey) ? _selectedVenueKey : 'ALL',
                                      isExpanded: true,
                                      icon: Icon(Icons.arrow_drop_down_circle_outlined, color: AppColors.primaryGreen, size: 20),
                                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.richBlack),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() {
                                            _selectedVenueKey = val;
                                          });
                                        }
                                      },
                                      items: venueOptions.map((vKey) {
                                        String label = vKey == 'ALL' ? '🌐 ALL VENUES (All Court Owners)' : vKey;
                                        return DropdownMenuItem<String>(
                                          value: vKey,
                                          child: Text(
                                            label,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Navigation Tabs Row (Follows Selected Venue)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildNavButton(
                          icon: Icons.calendar_month, 
                          label: 'Calendar', 
                          isSelected: _currentTab == 'calendar',
                          onTap: () => setState(() => _currentTab = 'calendar'),
                        ),
                        _buildNavButton(
                          icon: Icons.list_alt, 
                          label: 'Bookings (${filteredBookings.length})', 
                          isSelected: _currentTab == 'upcoming',
                          onTap: () => setState(() => _currentTab = 'upcoming'),
                        ),
                        _buildNavButton(
                          icon: Icons.sports_tennis, 
                          label: 'Venues (${filteredCourts.length})', 
                          isSelected: _currentTab == 'courts',
                          onTap: () => setState(() => _currentTab = 'courts'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  _buildTabContent(filteredBookings, filteredCourts),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [BoxShadow(color: AppColors.primaryGreen.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
              : [],
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? AppColors.softWhite : AppColors.richBlack),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.softWhite : AppColors.richBlack,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(List<dynamic> filteredBookings, List<dynamic> filteredCourts) {
    if (_currentTab == 'calendar') {
      return _buildCalendarView();
    } else if (_currentTab == 'upcoming') {
      return _buildUpcomingView(filteredBookings);
    } else {
      return _buildCourtsView(filteredCourts);
    }
  }

  // 📅 CALENDAR VIEW
  Widget _buildCalendarView() {
    final selectedBookings = _selectedDay != null ? _getBookingsForDay(_selectedDay!) : [];
    selectedBookings.sort((a, b) {
      final timeA = _parseTime((a['preferred_time'] ?? a['appointment_time'] ?? '').toString());
      final timeB = _parseTime((b['preferred_time'] ?? b['appointment_time'] ?? '').toString());
      return timeA.compareTo(timeB);
    });
    
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: AppColors.softWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: TableCalendar(
            firstDay: DateTime.utc(2020, 10, 16),
            lastDay: DateTime.utc(2030, 3, 14),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
              });
            },
            eventLoader: _getBookingsForDay,
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isNotEmpty) {
                  return Positioned(
                    bottom: 1,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryGreen.withOpacity(0.12),
                      ),
                      child: Center(
                        child: Text(
                          '${events.length}',
                          style: TextStyle(fontSize: 9, color: AppColors.primaryGreen, fontWeight: FontWeight.bold, height: 1.0),
                        ),
                      ),
                    ),
                  );
                }
                return null;
              },
            ),
            calendarStyle: CalendarStyle(
              selectedDecoration: const BoxDecoration(
                color: Color(0xFFE2F999),
                shape: BoxShape.circle,
              ),
              selectedTextStyle: TextStyle(color: AppColors.richBlack, fontWeight: FontWeight.bold),
              todayDecoration: BoxDecoration(
                color: Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              todayTextStyle: TextStyle(color: AppColors.richBlack),
              markerDecoration: BoxDecoration(
                color: AppColors.richBlack,
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (selectedBookings.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text("No bookings for this date", style: TextStyle(color: Colors.grey.shade600))),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: selectedBookings.map((booking) => _buildBookingCard(booking)).toList(),
            ),
          ),
      ],
    );
  }

  // 📋 UPCOMING & ALL BOOKINGS VIEW
  Widget _buildUpcomingView(List<dynamic> filteredBookings) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Search Bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search player, venue, owner email, ID...',
              hintStyle: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade500),
              prefixIcon: Icon(Icons.search, color: AppColors.primaryGreen),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.primaryGreen, width: 1.5)),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
          const SizedBox(height: 12),

          if (filteredBookings.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text("No bookings found for selected venue", style: TextStyle(color: Colors.grey.shade600))),
            )
          else
            Column(
              children: filteredBookings.map((b) => _buildBookingCard(b)).toList(),
            ),
        ],
      ),
    );
  }

  // 🏟️ COURTS & VENUES VIEW (WITH COURT ACTIVATION TOGGLE)
  Widget _buildCourtsView(List<dynamic> filteredCourts) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE2F999).withOpacity(0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primaryGreen.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.sports_tennis, color: AppColors.primaryGreen, size: 20),
                    const SizedBox(width: 8),
                    Text('Registered Venues', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.richBlack)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${filteredCourts.length} ${filteredCourts.length == 1 ? 'Venue' : 'Venues'}',
                    style: TextStyle(color: AppColors.softWhite, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        if (filteredCourts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Text("No registered venues found for selection", style: TextStyle(color: Colors.grey.shade600))),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: filteredCourts.map((c) {
                String vName = (c['name'] ?? c['venue_name'] ?? 'Court Venue').toString().trim();
                String oEmail = (c['owner_email'] ?? c['ownerEmail'] ?? '').toString().trim();
                bool isActive = _isVenueCurrentlyActive(vName, oEmail);
                dynamic courtId = c['id'];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.softWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isActive ? AppColors.primaryGreen.withOpacity(0.3) : Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(color: AppColors.richBlack.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  vName,
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.richBlack),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (oEmail.isNotEmpty)
                                  Text(
                                    oEmail,
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          
                          // COURT ACTIVATION TOGGLE BUTTON
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                isActive ? 'ACTIVATED' : 'DEACTIVATED',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isActive ? AppColors.primaryGreen : Colors.redAccent,
                                ),
                              ),
                              Switch(
                                value: isActive,
                                activeColor: AppColors.primaryGreen,
                                inactiveThumbColor: Colors.grey,
                                onChanged: (val) {
                                  _handleToggleVenueActivation(vName, oEmail, courtId, isActive);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.monetization_on_outlined, size: 15, color: Colors.grey.shade700),
                          const SizedBox(width: 6),
                          Text(
                            'App Fee: ₱15 / checkout session',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  // 🎴 DETAILED BOOKING CARD (With Payment Ref No, Date Created, Proof of Payment)
  Widget _buildBookingCard(dynamic booking) {
    String player = (booking['player_name'] ?? booking['full_name'] ?? 'Player').toString().trim();
    String court = (booking['court_name'] ?? booking['venue_name'] ?? booking['service_type'] ?? 'Court').toString().trim();
    String date = (booking['preferred_date'] ?? booking['appointment_date'] ?? 'N/A').toString().split('T')[0];
    String time = (booking['preferred_time'] ?? booking['appointment_time'] ?? 'Full Day').toString();
    String status = (booking['status'] ?? 'confirmed').toString().toUpperCase();
    String paymentMethod = (booking['payment_method'] ?? 'GCASH').toString().toUpperCase();
    String ownerEmail = (booking['owner_email'] ?? booking['court_owner'] ?? '').toString();

    double amount = 0;
    if (booking['total_amount'] != null) {
      amount = (booking['total_amount'] is num) ? (booking['total_amount'] as num).toDouble() : (double.tryParse(booking['total_amount'].toString()) ?? 0);
    }

    String firstNonEmpty(List<dynamic> candidates) {
      for (var c in candidates) {
        if (c != null) {
          String s = c.toString().trim();
          if (s.isNotEmpty && s != 'null') {
            return s;
          }
        }
      }
      return '';
    }

    String payRef = firstNonEmpty([
      booking['payment_reference'],
      booking['ref_no'],
      booking['payment_ref'],
      booking['proof_of_payment'],
      booking['agent_code'],
    ]).replaceAll(RegExp(r'^REF:\s*', caseSensitive: false), '');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.softWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: AppColors.richBlack.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  court,
                  style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: -0.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: status == 'COMPLETED' ? Colors.blue.shade700 : AppColors.primaryGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.softWhite),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Icon(Icons.person, size: 16, color: Colors.grey.shade700),
              const SizedBox(width: 8),
              Text(
                player,
                style: TextStyle(color: AppColors.richBlack, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 6),

          Row(
            children: [
              Icon(Icons.access_time, size: 16, color: Colors.grey.shade700),
              const SizedBox(width: 8),
              Text(
                '$date at $time',
                style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 6),

          if (booking['id'] != null) ...[
            Row(
              children: [
                Icon(Icons.receipt, size: 16, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ref #: ${booking['id']}',
                    style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],

          if (booking['created_at'] != null && booking['created_at'].toString().trim().isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Date Created: ${_formatDateCreated(booking['created_at'])}',
                    style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],

          if (payRef.isNotEmpty && !payRef.startsWith('data:')) ...[
            Row(
              children: [
                Icon(Icons.payment, size: 16, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Payment Ref No: $payRef',
                    style: TextStyle(color: Colors.grey.shade800, fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Amount: ₱${amount.toStringAsFixed(2)} ($paymentMethod)',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen, fontSize: 14),
              ),
              if (ownerEmail.isNotEmpty)
                Text(
                  ownerEmail,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

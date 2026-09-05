import 'package:flutter_project/theme/app_colors.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../widgets/custom_paddle_icon.dart';
import '../widgets/pickleball_icon.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';
import 'inbox_screen.dart';
import 'manage_court_schedule_screen.dart';
import 'add_court_screen.dart';
import 'earnings_screen.dart';

class OwnerDashboardScreen extends StatefulWidget {
  @override
  _OwnerDashboardScreenState createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  final ApiService _apiService = ApiService();
  String _userName = 'Owner';
  String _userEmail = '';
  
  bool _isLoading = true;
  String _currentTab = 'calendar'; // 'calendar', 'upcoming', 'courts'
  int _unreadCount = 0;
  
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();
  
  // Mocks for now until backend is fully wired
  List<dynamic> _allBookings = [];
  List<dynamic> _myCourts = [];
  int _unreadMessageCount = 0;
  Timer? _notificationTimer;
  int _lastNotificationId = 0;
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    if (userStr != null) {
      final userObj = json.decode(userStr);
      setState(() {
        _userName = userObj['full_name'] ?? 'Owner';
        _userEmail = userObj['email'] ?? '';
      });
      // Fetch bookings for owner's courts
      _fetchOwnerBookings(_userEmail);
      _fetchCourts(_userEmail);
      _fetchUnreadNotifications(_userEmail);
      _fetchUnreadMessages(_userEmail);
      _startNotificationListener();
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _startNotificationListener() {
    _notificationTimer?.cancel();
    _notificationTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      _checkNewOwnerNotifications();
    });
  }


  Future<void> _checkNewOwnerNotifications() async {
    if (_userEmail.isEmpty) return;
    final notifications = await _apiService.fetchNotifications(_userEmail);
    if (!mounted) return;

    int unread = notifications.where((n) => n['is_read'] != true).length;
    
    if (notifications.isNotEmpty) {
      final latest = notifications.first;
      int latestId = latest['id'] ?? 0;

      if (_lastNotificationId != 0 && latestId > _lastNotificationId && latest['is_read'] != true) {
        _showNewBookingBanner(
          title: latest['title'] ?? '🎾 New Court Booking!',
          message: latest['message'] ?? 'A new court booking has been completed.',
        );
        _fetchOwnerBookings(_userEmail);
      }
      _lastNotificationId = latestId;
    }

    setState(() {
      _unreadCount = unread;
    });
  }

  void _showNewBookingBanner({required String title, required String message}) {
    if (!mounted) return;

    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: -100, end: 0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, value),
                child: child,
              );
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.richBlack.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(color: AppColors.accentLime, width: 1.5),
              ),
              child: InkWell(
                onTap: () {
                  entry.remove();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => NotificationsScreen()),
                  ).then((_) => _loadUserData());
                },
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const PickleballIcon(size: 24, color: AppColors.softWhite, holeColor: AppColors.primaryGreen),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(color: AppColors.softWhite, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            message,
                            style: TextStyle(color: AppColors.softWhite.withOpacity(0.70), fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, color: AppColors.softWhite.withOpacity(0.54), size: 14),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);

    Future.delayed(const Duration(seconds: 5), () {
      if (entry.mounted) {
        entry.remove();
      }
    });
  }

  Future<void> _fetchUnreadNotifications(String email) async {
    final notifications = await _apiService.fetchNotifications(email);
    int unread = notifications.where((n) => n['is_read'] != true).length;
    if (notifications.isNotEmpty && _lastNotificationId == 0) {
      _lastNotificationId = notifications.first['id'] ?? 0;
    }
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

  Future<void> _fetchOwnerBookings(String email) async {
    final bookings = await _apiService.fetchOwnerBookingsAPI(email);
    setState(() {
      _allBookings = bookings;
      _isLoading = false;
    });
  }

  Future<void> _fetchCourts(String email) async {
    final courts = await _apiService.fetchOwnerCourts(email);
    setState(() {
      _myCourts = courts;
    });
  }

  List<dynamic> _getBookingsForDay(DateTime day) {
    return _allBookings.where((b) {
      if (b['appointment_date'] == null) return false;
      String dateString = b['appointment_date'].toString().substring(0, 10);
      DateTime localDate = DateTime.parse('$dateString 00:00:00');
      return isSameDay(localDate, day);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
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
            offset: Offset(-8, 8),
            backgroundColor: Colors.redAccent,
            child: IconButton(
              icon: Icon(Icons.chat_bubble_outline, color: AppColors.richBlack, size: 24),
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => InboxScreen()));
                _fetchUnreadMessages(_userEmail);
              },
            ),
          ),
          Badge(
            isLabelVisible: _unreadCount > 0,
            label: Text(_unreadCount.toString()),
            offset: Offset(-8, 8),
            child: IconButton(
              icon: Icon(Icons.notifications_outlined, color: AppColors.richBlack),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => NotificationsScreen()),
                );
                _fetchUnreadNotifications(_userEmail);
              },
            ),
          ),
          IconButton(
            icon: Icon(Icons.person_outline, color: AppColors.richBlack),
            onPressed: () async {
              final updated = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfileScreen()),
              );
              if (updated == true) {
                _loadUserData();
              }
            },
          ),
          SizedBox(width: 8),
        ],
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: AppColors.richBlack))
        : Column(
            children: [
              Padding(
                padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + kToolbarHeight + 24.0, bottom: 24.0),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => EarningsScreen()),
                        );
                      },
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 24),
                        padding: EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hi, ${_toTitleCase(_userName)}',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.richBlack,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Court Owner',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Earnings this Month',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.richBlack,
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.richBlack),
                                  ],
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'P${_calculateMonthlyEarnings()}',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildNavButton(
                          icon: Icons.calendar_month, 
                          label: 'Calendar', 
                          isSelected: _currentTab == 'calendar',
                          onTap: () => setState(() => _currentTab = 'calendar'),
                        ),
                        _buildNavButton(
                          icon: Icons.list_alt, 
                          label: 'Upcoming', 
                          isSelected: _currentTab == 'upcoming',
                          onTap: () => setState(() => _currentTab = 'upcoming'),
                        ),
                        _buildNavButton(
                          icon: Icons.sports_tennis, 
                          label: _myCourts.isNotEmpty ? 'My Courts (${_myCourts.length})' : 'My Courts', 
                          isSelected: _currentTab == 'courts',
                          onTap: () => setState(() => _currentTab = 'courts'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _buildTabContent(),
              ),
            ],
          ),
    );
  }

  Widget _buildTabContent() {
    if (_currentTab == 'calendar') {
      return _buildCalendarView();
    } else if (_currentTab == 'upcoming') {
      return _buildUpcomingView();
    } else {
      return _buildCourtsView();
    }
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
    } catch (e) {
      return DateTime(2000);
    }
  }

  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.toLowerCase().split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  String _calculateMonthlyEarnings() {
    double total = 0.0;
    for (var b in _allBookings) {
      if (b['status'] == 'blocked' || b['status'] == 'cancelled') continue;
      if (b['appointment_date'] != null) {
        try {
          final dateStr = b['appointment_date'].toString().substring(0, 10);
          final date = DateTime.parse(dateStr);
          if (date.year == _focusedDay.year && date.month == _focusedDay.month) {
            final amount = double.tryParse(b['total_amount']?.toString() ?? '0') ?? 0.0;
            total += amount;
          }
        } catch (e) {}
      }
    }
    return total.toStringAsFixed(2);
  }

  Widget _buildCalendarView() {
    final selectedBookings = _selectedDay != null ? _getBookingsForDay(_selectedDay!) : [];
    selectedBookings.sort((a, b) {
      final timeA = _parseTime(a['appointment_time']?.toString() ?? '');
      final timeB = _parseTime(b['appointment_time']?.toString() ?? '');
      return timeA.compareTo(timeB);
    });
    
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              Container(
                margin: EdgeInsets.symmetric(horizontal: 24),
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
                              color: AppColors.primaryGreen.withOpacity(0.08),
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
                    selectedDecoration: BoxDecoration(
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
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                ),
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
        if (selectedBookings.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text("No bookings for this date", style: TextStyle(color: Colors.grey))),
          )
        else
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final booking = selectedBookings[index];
                  return _buildBookingCard(booking);
                },
                childCount: selectedBookings.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUpcomingView() {
    final now = DateTime.now();
    final upcomingBookings = _allBookings.where((b) {
      if (b['appointment_date'] == null || b['appointment_time'] == null) return false;
      
      try {
        String dateString = b['appointment_date'].toString().substring(0, 10);
        
        String timeString = b['appointment_time'].toString().trim();
        int hour = int.parse(timeString.split(':')[0]);
        int minute = int.parse(timeString.split(':')[1].substring(0, 2));
        bool isPM = timeString.toUpperCase().contains('PM');
        
        if (isPM && hour < 12) hour += 12;
        if (!isPM && hour == 12) hour = 0;
        
        String hourStr = hour.toString().padLeft(2, '0');
        String minStr = minute.toString().padLeft(2, '0');
        
        final dt = DateTime.parse('$dateString $hourStr:$minStr:00');
        b['parsed_dt'] = dt;
        
        return dt.isAfter(now);
      } catch (e) {
        print('Error parsing date for upcoming view: $e');
        return false;
      }
    }).toList();
    
    upcomingBookings.sort((a, b) {
      DateTime dtA = a['parsed_dt'] ?? DateTime(2000);
      DateTime dtB = b['parsed_dt'] ?? DateTime(2000);
      int dateCmp = dtA.compareTo(dtB);
      if (dateCmp != 0) return dateCmp;
      
      String courtA = (a['service_type'] ?? '').toString();
      String courtB = (b['service_type'] ?? '').toString();
      return courtA.compareTo(courtB);
    });
    
    if (upcomingBookings.isEmpty) {
      return Center(child: Text("No upcoming bookings", style: TextStyle(color: Colors.grey)));
    }
    
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 24),
      itemCount: upcomingBookings.length,
      itemBuilder: (context, index) {
        return _buildBookingCard(upcomingBookings[index]);
      },
    );
  }

  Widget _buildCourtsView() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Color(0xFFE2F999).withOpacity(0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primaryGreen.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.sports_tennis, color: AppColors.primaryGreen, size: 20),
                    SizedBox(width: 8),
                    Text('Total Registered Courts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.richBlack)),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_myCourts.length} ${_myCourts.length == 1 ? 'Court' : 'Courts'}',
                    style: TextStyle(color: AppColors.softWhite, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AddCourtScreen(userEmail: _userEmail)),
              );
              if (result == true) {
                _fetchCourts(_userEmail);
              }
            },
            icon: Icon(Icons.add, color: AppColors.softWhite),
            label: Text('Add New Court', style: TextStyle(color: AppColors.softWhite, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              padding: EdgeInsets.symmetric(vertical: 16),
              minimumSize: Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        Expanded(
          child: _myCourts.isEmpty 
            ? Center(child: Text("You haven't added any courts yet.", style: TextStyle(color: Colors.grey)))
            : GridView.builder(
                padding: EdgeInsets.symmetric(horizontal: 24),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.70,
                ),
                itemCount: _myCourts.length,
                itemBuilder: (context, index) {
                  final court = _myCourts[index];
                  final String surface = court['description'] ?? 'Standard Surface';
                  return Card(
                    margin: EdgeInsets.zero,
                    elevation: 1.5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ManageCourtScheduleScreen(
                              court: court,
                              ownerEmail: _userEmail,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
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
                                      Text(
                                        court['name'] ?? 'Unnamed', 
                                        style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 15),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        surface, 
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 10), 
                                        maxLines: 1, 
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  padding: EdgeInsets.zero,
                                  constraints: BoxConstraints(),
                                  icon: Icon(Icons.more_vert, size: 18, color: Colors.grey.shade700),
                                  onSelected: (value) async {
                                    if (value == 'edit') {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => AddCourtScreen(
                                            userEmail: _userEmail,
                                            court: court,
                                          ),
                                        ),
                                      );
                                      if (result == true) {
                                        _fetchCourts(_userEmail);
                                      }
                                    } else if (value == 'delete') {
                                      _confirmDeleteCourt(court);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit, size: 16, color: Colors.blue),
                                          SizedBox(width: 8),
                                          Text('Edit', style: TextStyle(fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, size: 16, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Delete', style: TextStyle(fontSize: 13, color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: 6),
                            Expanded(
                              child: Center(
                                child: AspectRatio(
                                  aspectRatio: 0.75,
                                  child: CustomPaint(
                                    painter: PickleballCourtTopViewPainter(
                                      courtColor: surface.toLowerCase().contains('sand')
                                          ? Color(0xFF0D9488)
                                          : Color(0xFF1D4ED8),
                                      kitchenColor: Color(0xFF38BDF8),
                                      apronColor: surface.toLowerCase().contains('sand')
                                          ? Color(0xFF134E4A)
                                          : Color(0xFF1E3A8A),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'P${court['base_price']}/hr', 
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700, fontSize: 13)
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteCourt(Map<String, dynamic> court) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Court'),
        content: Text('Are you sure you want to delete "${court['name']}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete', style: TextStyle(color: AppColors.softWhite, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _apiService.deleteCourt(court['id']);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Court "${court['name']}" deleted successfully.')),
        );
        _fetchCourts(_userEmail);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete court.')),
        );
      }
    }
  }

  Future<void> _showMessageDialog(String renterEmail) async {
    final TextEditingController _messageController = TextEditingController();
    bool _isSending = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Message Renter'),
              content: TextField(
                controller: _messageController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Type your message here...',
                  border: OutlineInputBorder(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _isSending
                      ? null
                      : () async {
                          if (_messageController.text.trim().isEmpty) return;
                          setState(() => _isSending = true);
                          final success = await _apiService.sendNotification(
                            renterEmail,
                            _userEmail,
                            'Message from Court Owner',
                            _messageController.text.trim(),
                          );
                          setState(() => _isSending = false);
                          if (success) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Message sent successfully!')),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to send message.')),
                            );
                          }
                        },
                  child: _isSending ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text('Send'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBookingCard(dynamic booking) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.softWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: AppColors.richBlack.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                booking['service_type'] ?? 'Court Booking',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.5),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Confirmed',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.softWhite),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.access_time, size: 16, color: Colors.grey),
              SizedBox(width: 8),
              Text(
                '${booking['appointment_date']?.toString().substring(0, 10)} at ${booking['appointment_time']}',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
            ],
          ),
          SizedBox(height: 8),
          if (booking['id'] != null) ...[
            Row(
              children: [
                Icon(Icons.receipt, size: 16, color: Colors.grey),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ref #: ${booking['id']}',
                    style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.grey),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Renter: ${booking['full_name'] ?? 'Unknown'}',
                        style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  if (booking['email'] != null && booking['status'] != 'blocked')
                    IconButton(
                      icon: Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.chat_bubble_outline_rounded, size: 16, color: AppColors.primaryGreen),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                      onPressed: () {
                        _showMessageDialog(booking['email']);
                      },
                    ),
                  SizedBox(width: 8),
                  Text(
                    'Amount: P${booking['total_amount'] ?? '0.00'}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({required IconData icon, required String label, required VoidCallback onTap, bool isSelected = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 44,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.richBlack : AppColors.softWhite,
              borderRadius: BorderRadius.circular(9999),
              border: Border.all(color: AppColors.richBlack, width: 1),
            ),
            child: Icon(icon, color: isSelected ? AppColors.softWhite : AppColors.richBlack, size: 24),
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isSelected ? AppColors.richBlack : Colors.grey.shade700,
            ),
          )
        ],
      ),
    );
  }
}

class PickleballCourtTopViewPainter extends CustomPainter {
  final Color courtColor;
  final Color kitchenColor;
  final Color apronColor;
  final Color lineColor;

  PickleballCourtTopViewPainter({
    this.courtColor = const Color(0xFF1D4ED8),
    this.kitchenColor = const Color(0xFF38BDF8),
    this.apronColor = const Color(0xFF1E3A8A),
    this.lineColor = AppColors.softWhite,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double strokeWidth = 1.8;

    // 1. Apron (Background Outer Frame)
    final RRect outerRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(6),
    );
    final Paint apronPaint = Paint()
      ..color = apronColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(outerRRect, apronPaint);

    // 2. Inbounds Court Rect
    final double marginX = size.width * 0.08;
    final double marginY = size.height * 0.06;
    final Rect courtRect = Rect.fromLTRB(
      marginX,
      marginY,
      size.width - marginX,
      size.height - marginY,
    );

    final Paint courtPaint = Paint()
      ..color = courtColor
      ..style = PaintingStyle.fill;
    canvas.drawRect(courtRect, courtPaint);

    // 3. Non-Volley Zone (Kitchen - 7ft each side of 44ft total court length)
    final double netY = courtRect.top + courtRect.height / 2;
    final double kitchenHalfHeight = (7.0 / 44.0) * courtRect.height;
    final double kitchenTopY = netY - kitchenHalfHeight;
    final double kitchenBottomY = netY + kitchenHalfHeight;

    final Rect kitchenRect = Rect.fromLTRB(
      courtRect.left,
      kitchenTopY,
      courtRect.right,
      kitchenBottomY,
    );
    final Paint kitchenPaint = Paint()
      ..color = kitchenColor
      ..style = PaintingStyle.fill;
    canvas.drawRect(kitchenRect, kitchenPaint);

    // 4. White Boundary & Court Marking Lines
    final Paint linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    // Outer Boundary
    canvas.drawRect(courtRect, linePaint);

    // Kitchen Lines
    canvas.drawLine(
      Offset(courtRect.left, kitchenTopY),
      Offset(courtRect.right, kitchenTopY),
      linePaint,
    );
    canvas.drawLine(
      Offset(courtRect.left, kitchenBottomY),
      Offset(courtRect.right, kitchenBottomY),
      linePaint,
    );

    // Center Lines
    final double centerColumnX = courtRect.left + courtRect.width / 2;
    // Top center line
    canvas.drawLine(
      Offset(centerColumnX, courtRect.top),
      Offset(centerColumnX, kitchenTopY),
      linePaint,
    );
    // Bottom center line
    canvas.drawLine(
      Offset(centerColumnX, kitchenBottomY),
      Offset(centerColumnX, courtRect.bottom),
      linePaint,
    );

    // 5. Net Line across center with Posts
    final Paint netPaint = Paint()
      ..color = AppColors.softWhite.withOpacity(0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    final double netExtend = marginX * 0.5;
    canvas.drawLine(
      Offset(courtRect.left - netExtend, netY),
      Offset(courtRect.right + netExtend, netY),
      netPaint,
    );

    // Net Posts
    final Paint postPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(courtRect.left - netExtend, netY), 2.5, postPaint);
    canvas.drawCircle(Offset(courtRect.right + netExtend, netY), 2.5, postPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

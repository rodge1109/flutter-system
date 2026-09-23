import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class SuperDashboardScreen extends StatefulWidget {
  @override
  _SuperDashboardScreenState createState() => _SuperDashboardScreenState();
}

class _SuperDashboardScreenState extends State<SuperDashboardScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;

  List<dynamic> _allBookings = [];
  List<dynamic> _allCourts = [];
  
  // Filter States
  String _selectedVenue = 'ALL';
  String _selectedStatus = 'ALL';
  String _datePreset = 'MONTH'; // 'TODAY', 'WEEK', 'MONTH', 'ALL', 'CUSTOM'
  DateTimeRange? _customDateRange;
  String _searchQuery = '';

  final TextEditingController _searchController = TextEditingController();

  // Financial Metrics
  double _platformGrossVolume = 0;
  double _totalAppServiceFee = 0; // ₱15 per booking
  double _totalNetToOwners = 0;
  int _totalBookingsCount = 0;
  int _totalVenuesCount = 0;

  // Segregated Owner/Venue Summaries
  Map<String, Map<String, dynamic>> _venueSummaries = {};

  // Disabled Venues / Owners Tracking
  Set<String> _disabledVenues = {};
  Set<String> _disabledOwners = {};

  @override
  void initState() {
    super.initState();
    _loadDisabledLists();
    _loadDashboardData();
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
      _processCalculations();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nextStatus
                  ? '🟢 $venueName has been ACTIVATED and is now visible in Courts Nearby.'
                  : '🔴 $venueName is TEMPORARILY DEACTIVATED and hidden from Courts Nearby.',
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
    
    // Load cached first if available
    final prefs = await SharedPreferences.getInstance();
    final cachedBookingsStr = prefs.getString('super_admin_cached_bookings');
    if (cachedBookingsStr != null) {
      try {
        final cached = json.decode(cachedBookingsStr);
        if (cached is List && cached.isNotEmpty) {
          _allBookings = cached;
          _processCalculations();
          setState(() => _isLoading = false);
        }
      } catch (_) {}
    }

    try {
      final results = await Future.wait([
        _apiService.fetchSuperAdminBookings(),
        _apiService.fetchRawServices(),
      ]);

      final freshBookings = results[0] as List<dynamic>;
      final rawServices = results[1] as List<Map<String, dynamic>>;

      if (freshBookings.isNotEmpty) {
        _allBookings = freshBookings;
        await prefs.setString('super_admin_cached_bookings', json.encode(freshBookings));
      }
      
      _allCourts = rawServices;
      _processCalculations();
    } catch (e) {
      print('Super Dashboard fetch error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _processCalculations() {
    List<dynamic> filtered = _getFilteredBookings();

    double gross = 0;
    double appFee = 0;
    Map<String, Map<String, dynamic>> summaries = {};

    // First populate all registered courts from raw services so all venues can be managed
    for (var c in _allCourts) {
      String vName = c['name'] ?? c['venue_name'] ?? c['service_title'] ?? 'Court Venue';
      String oEmail = c['owner_email'] ?? c['ownerEmail'] ?? c['owner'] ?? '';
      String groupKey = '$vName (${oEmail.isNotEmpty ? oEmail : "rodge1109@yahoo.com"})';

      summaries[groupKey] = {
        'courtId': c['id'],
        'venueName': vName,
        'ownerEmail': oEmail.isNotEmpty ? oEmail : 'rodge1109@yahoo.com',
        'bookingsCount': 0,
        'grossVolume': 0.0,
        'appServiceFee': 0.0,
        'netOwnerPayout': 0.0,
      };
    }

    for (var b in filtered) {
      // Calculation of amount
      double price = 0;
      if (b['total_price'] != null) {
        price = (b['total_price'] is num) ? (b['total_price'] as num).toDouble() : (double.tryParse(b['total_price'].toString()) ?? 0);
      } else if (b['amount'] != null) {
        price = (b['amount'] is num) ? (b['amount'] as num).toDouble() : (double.tryParse(b['amount'].toString()) ?? 0);
      } else if (b['price'] != null) {
        price = (b['price'] is num) ? (b['price'] as num).toDouble() : (double.tryParse(b['price'].toString()) ?? 0);
      }

      // App service fee is ₱15 flat fee per booking session
      double fee = 15.00;
      if (b['service_fee'] != null && (b['service_fee'] as num) > 0) {
        fee = (b['service_fee'] as num).toDouble();
      }

      gross += price;
      appFee += fee;

      // Grouping by Venue / Owner
      String venueName = b['court_name'] ?? b['venue_name'] ?? b['service_title'] ?? 'General Venue';
      String ownerEmail = b['owner_email'] ?? b['court_owner'] ?? b['owner'] ?? 'Unknown Owner';

      String groupKey = '$venueName ($ownerEmail)';

      if (!summaries.containsKey(groupKey)) {
        summaries[groupKey] = {
          'courtId': b['court_id'] ?? b['service_id'] ?? 0,
          'venueName': venueName,
          'ownerEmail': ownerEmail,
          'bookingsCount': 0,
          'grossVolume': 0.0,
          'appServiceFee': 0.0,
          'netOwnerPayout': 0.0,
        };
      }

      summaries[groupKey]!['bookingsCount'] = (summaries[groupKey]!['bookingsCount'] as int) + 1;
      summaries[groupKey]!['grossVolume'] = (summaries[groupKey]!['grossVolume'] as double) + price;
      summaries[groupKey]!['appServiceFee'] = (summaries[groupKey]!['appServiceFee'] as double) + fee;
      summaries[groupKey]!['netOwnerPayout'] = (summaries[groupKey]!['netOwnerPayout'] as double) + (price - fee);
    }

    _platformGrossVolume = gross;
    _totalAppServiceFee = appFee;
    _totalNetToOwners = gross - appFee;
    if (_totalNetToOwners < 0) _totalNetToOwners = 0;
    _totalBookingsCount = filtered.length;
    _venueSummaries = summaries;
    _totalVenuesCount = summaries.keys.length;
  }

  List<dynamic> _getFilteredBookings() {
    return _allBookings.where((b) {
      // Status Filter
      if (_selectedStatus != 'ALL') {
        String status = (b['status'] ?? 'confirmed').toString().toUpperCase();
        if (status != _selectedStatus) return false;
      }

      // Venue Filter
      if (_selectedVenue != 'ALL') {
        String venueName = b['court_name'] ?? b['venue_name'] ?? b['service_title'] ?? '';
        String ownerEmail = b['owner_email'] ?? b['court_owner'] ?? b['owner'] ?? '';
        String key = '$venueName ($ownerEmail)';
        if (key != _selectedVenue && venueName != _selectedVenue) return false;
      }

      // Date Range Filter
      if (b['appointment_date'] != null || b['preferred_date'] != null || b['created_at'] != null) {
        String? dateStr = b['appointment_date'] ?? b['preferred_date'] ?? b['created_at'];
        if (dateStr != null) {
          try {
            DateTime bookingDate = DateTime.parse(dateStr.split('T')[0]);
            DateTime now = DateTime.now();
            DateTime today = DateTime(now.year, now.month, now.day);

            if (_datePreset == 'TODAY') {
              if (bookingDate.isBefore(today)) return false;
            } else if (_datePreset == 'WEEK') {
              DateTime startOfWeek = today.subtract(Duration(days: today.weekday - 1));
              if (bookingDate.isBefore(startOfWeek)) return false;
            } else if (_datePreset == 'MONTH') {
              DateTime startOfMonth = DateTime(now.year, now.month, 1);
              if (bookingDate.isBefore(startOfMonth)) return false;
            } else if (_datePreset == 'CUSTOM' && _customDateRange != null) {
              if (bookingDate.isBefore(_customDateRange!.start) || bookingDate.isAfter(_customDateRange!.end.add(const Duration(days: 1)))) {
                return false;
              }
            }
          } catch (_) {}
        }
      }

      // Search Query
      if (_searchQuery.trim().isNotEmpty) {
        String query = _searchQuery.toLowerCase().trim();
        String venue = (b['court_name'] ?? b['venue_name'] ?? '').toString().toLowerCase();
        String owner = (b['owner_email'] ?? b['court_owner'] ?? '').toString().toLowerCase();
        String customer = (b['user_name'] ?? b['user_email'] ?? b['name'] ?? '').toString().toLowerCase();
        String id = (b['id'] ?? '').toString().toLowerCase();

        if (!venue.contains(query) && !owner.contains(query) && !customer.contains(query) && !id.contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  String _formatCurrency(double amount) {
    final format = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
    return format.format(amount);
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(dateStr.split('T')[0]);
      return DateFormat('MMM dd, yyyy').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredBookings = _getFilteredBookings();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Super Dashboard',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh Data',
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : RefreshIndicator(
              color: AppColors.primaryGreen,
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- APP OWNER HERO EARNINGS BANNER ---
                    _buildAppOwnerEarningsCard(),

                    const SizedBox(height: 16),

                    // --- KPI METRICS GRID ---
                    _buildKpiMetricsGrid(),

                    const SizedBox(height: 20),

                    // --- SEARCH & DATE FILTER BAR ---
                    _buildFiltersSection(),

                    const SizedBox(height: 20),

                    // --- VENUE / COURT OWNER SEGREGATION CARDS ---
                    _buildSegregatedVenuesSection(),

                    const SizedBox(height: 24),

                    // --- ITEMIZATION HEADER & BOOKINGS STREAM ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Itemized Platform Bookings (${filteredBookings.length})',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.richBlack,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '₱15 App Fee / Booking',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    if (filteredBookings.isEmpty)
                      _buildEmptyState()
                    else
                      Column(
                        children: filteredBookings.map((booking) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: _buildBookingItemCard(booking),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  // APP OWNER EARNINGS HERO BANNER
  Widget _buildAppOwnerEarningsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryGreen,
            const Color(0xFF0F382A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accentLime.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_balance_wallet, color: AppColors.accentLime, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'App Owner Platform Earnings',
                    style: GoogleFonts.outfit(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentLime,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Service Fee: ₱15/Booking',
                  style: GoogleFonts.outfit(
                    color: AppColors.richBlack,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _formatCurrency(_totalAppServiceFee),
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Total net income earned from court owner service fees',
            style: GoogleFonts.outfit(
              color: Colors.white60,
              fontSize: 12,
            ),
          ),
          const Divider(color: Colors.white12, height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Platform Gross Volume',
                      style: GoogleFonts.outfit(color: Colors.white60, fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatCurrency(_platformGrossVolume),
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 24, width: 1, color: Colors.white24),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Net Court Owner Payouts',
                        style: GoogleFonts.outfit(color: Colors.white60, fontSize: 11),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatCurrency(_totalNetToOwners),
                        style: GoogleFonts.outfit(
                          color: AppColors.accentLime,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // KPI METRICS GRID
  Widget _buildKpiMetricsGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            title: 'Total Bookings',
            value: _totalBookingsCount.toString(),
            icon: Icons.confirmation_number_outlined,
            color: Colors.blue.shade700,
            bgColor: Colors.blue.shade50,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricTile(
            title: 'Active Venues',
            value: _totalVenuesCount.toString(),
            icon: Icons.storefront_outlined,
            color: Colors.purple.shade700,
            bgColor: Colors.purple.shade50,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricTile(
            title: 'Avg. Booking',
            value: _totalBookingsCount > 0 ? _formatCurrency(_platformGrossVolume / _totalBookingsCount) : '₱0.00',
            icon: Icons.trending_up,
            color: Colors.teal.shade700,
            bgColor: Colors.teal.shade50,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.richBlack,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // SEARCH AND FILTERS SECTION
  Widget _buildFiltersSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Input
          TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
                _processCalculations();
              });
            },
            decoration: InputDecoration(
              hintText: 'Search venue, owner email, customer, ID...',
              hintStyle: GoogleFonts.outfit(fontSize: 13, color: Colors.grey),
              prefixIcon: const Icon(Icons.search, color: AppColors.primaryGreen, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _processCalculations();
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              fillColor: const Color(0xFFF7F9FC),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Date Presets & Status Chips Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildDateFilterChip('Month', 'MONTH'),
                _buildDateFilterChip('Week', 'WEEK'),
                _buildDateFilterChip('Today', 'TODAY'),
                _buildDateFilterChip('All-Time', 'ALL'),
                const SizedBox(width: 12),
                Container(height: 20, width: 1, color: Colors.grey.shade300),
                const SizedBox(width: 12),
                _buildStatusChip('All Status', 'ALL'),
                _buildStatusChip('Confirmed', 'CONFIRMED'),
                _buildStatusChip('Completed', 'COMPLETED'),
                _buildStatusChip('Pending', 'PENDING'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilterChip(String label, String presetKey) {
    bool isSelected = _datePreset == presetKey;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: ChoiceChip(
        label: Text(label),
        labelStyle: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : AppColors.richBlack,
        ),
        selected: isSelected,
        selectedColor: AppColors.primaryGreen,
        backgroundColor: Colors.grey.shade100,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _datePreset = presetKey;
              _processCalculations();
            });
          }
        },
      ),
    );
  }

  Widget _buildStatusChip(String label, String statusKey) {
    bool isSelected = _selectedStatus == statusKey;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: ChoiceChip(
        label: Text(label),
        labelStyle: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : AppColors.richBlack,
        ),
        selected: isSelected,
        selectedColor: Colors.black87,
        backgroundColor: Colors.grey.shade100,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _selectedStatus = statusKey;
              _processCalculations();
            });
          }
        },
      ),
    );
  }

  // SEGREGATED VENUE & COURT OWNER CARDS SECTION
  Widget _buildSegregatedVenuesSection() {
    if (_venueSummaries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Segregated by Court Owner / Venue',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.richBlack,
              ),
            ),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _showVenueActivationManager,
                  icon: const Icon(Icons.power_settings_new, size: 14, color: AppColors.richBlack),
                  label: Text(
                    'Court Activation',
                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.richBlack),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentLime,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    elevation: 0,
                  ),
                ),
                if (_selectedVenue != 'ALL') ...[
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedVenue = 'ALL';
                        _processCalculations();
                      });
                    },
                    child: Text('Reset', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.primaryGreen)),
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 175,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _venueSummaries.keys.length + 1,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                // "All Venues" Overview Card
                bool isSelected = _selectedVenue == 'ALL';
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedVenue = 'ALL';
                      _processCalculations();
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 220,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primaryGreen : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppColors.primaryGreen : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'ALL VENUES',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : AppColors.richBlack,
                              ),
                            ),
                            Icon(Icons.border_all, color: isSelected ? AppColors.accentLime : AppColors.primaryGreen, size: 18),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatCurrency(_totalAppServiceFee),
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : AppColors.primaryGreen,
                              ),
                            ),
                            Text(
                              'App Fee Earnings (${_totalBookingsCount} bookings)',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                color: isSelected ? Colors.white70 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'All Venues Default Active 🟢',
                            style: GoogleFonts.outfit(fontSize: 10, color: isSelected ? Colors.white : Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              String key = _venueSummaries.keys.elementAt(index - 1);
              final item = _venueSummaries[key]!;
              bool isSelected = _selectedVenue == key;
              bool isActive = _isVenueCurrentlyActive(item['venueName'], item['ownerEmail']);

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedVenue = isSelected ? 'ALL' : key;
                    _processCalculations();
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 230,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryGreen : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primaryGreen
                          : (isActive ? Colors.grey.shade200 : Colors.red.shade300),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Venue title & status badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['venueName'],
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : AppColors.richBlack,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  item['ownerEmail'],
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    color: isSelected ? Colors.white70 : Colors.grey.shade600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: isActive,
                            activeColor: AppColors.accentLime,
                            inactiveThumbColor: Colors.redAccent,
                            onChanged: (val) {
                              _handleToggleVenueActivation(item['venueName'], item['ownerEmail'], item['courtId'], isActive);
                            },
                          ),
                        ],
                      ),

                      // Status Badge Tag
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isActive
                              ? (isSelected ? Colors.white24 : Colors.green.shade50)
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isActive ? '🟢 ACTIVATED' : '🔴 DEACTIVATED (Hidden in Nearby)',
                          style: GoogleFonts.outfit(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isActive
                                ? (isSelected ? Colors.white : Colors.green.shade800)
                                : Colors.red.shade800,
                          ),
                        ),
                      ),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'App Fee (₱15)',
                                style: GoogleFonts.outfit(
                                  fontSize: 9,
                                  color: isSelected ? Colors.white60 : Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                _formatCurrency(item['appServiceFee']),
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? AppColors.accentLime : AppColors.primaryGreen,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white24 : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${item['bookingsCount']} bks',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : AppColors.richBlack,
                              ),
                            ),
                          ),
                        ],
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

  // BOOKING CARD ITEM
  Widget _buildBookingItemCard(dynamic booking) {
    String venueName = booking['court_name'] ?? booking['venue_name'] ?? booking['service_title'] ?? 'Court Booking';
    String ownerEmail = booking['owner_email'] ?? booking['court_owner'] ?? booking['owner'] ?? 'rodge1109@yahoo.com';
    String customerName = booking['user_name'] ?? booking['name'] ?? booking['customer_name'] ?? 'Customer';
    String customerEmail = booking['user_email'] ?? booking['email'] ?? '';
    String date = _formatDate(booking['appointment_date'] ?? booking['preferred_date'] ?? booking['created_at']);
    String time = booking['appointment_time'] ?? booking['preferred_time'] ?? booking['time'] ?? 'Full Day';
    String status = (booking['status'] ?? 'CONFIRMED').toString().toUpperCase();

    double totalPrice = 0;
    if (booking['total_price'] != null) {
      totalPrice = (booking['total_price'] is num) ? (booking['total_price'] as num).toDouble() : (double.tryParse(booking['total_price'].toString()) ?? 0);
    } else if (booking['amount'] != null) {
      totalPrice = (booking['amount'] is num) ? (booking['amount'] as num).toDouble() : (double.tryParse(booking['amount'].toString()) ?? 0);
    }

    double appFee = 15.00;
    double netOwner = totalPrice - appFee;
    if (netOwner < 0) netOwner = 0;

    Color statusColor = Colors.green;
    if (status == 'PENDING') statusColor = Colors.orange;
    if (status == 'CANCELLED') statusColor = Colors.red;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Venue & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.sports_tennis, color: AppColors.primaryGreen, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        venueName,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.richBlack,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          Divider(color: Colors.grey.shade100, height: 1),
          const SizedBox(height: 10),

          // Details grid
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Court Owner:', style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey.shade600)),
                    Text(
                      ownerEmail,
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.richBlack),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text('Customer:', style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey.shade600)),
                    Text(
                      '$customerName (${customerEmail.isNotEmpty ? customerEmail : "Guest"})',
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Schedule:', style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey.shade600)),
                  Text(
                    date,
                    style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                  ),
                  Text(
                    time,
                    style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Gross Total', style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey.shade600)),
                    Text(
                      _formatCurrency(totalPrice),
                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.richBlack),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('App Fee (15.00)', style: GoogleFonts.outfit(fontSize: 10, color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
                    Text(
                      _formatCurrency(appFee),
                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Net to Owner', style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey.shade600)),
                    Text(
                      _formatCurrency(netOwner),
                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.indigo),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No Bookings Found',
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.richBlack),
          ),
          const SizedBox(height: 4),
          Text(
            'Try adjusting your search query or date/venue filters.',
            style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showVenueActivationManager() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final keys = _venueSummaries.keys.toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                              'Court Venue Status & Activation',
                              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.richBlack),
                            ),
                            Text(
                              'Default status is ACTIVATED. Deactivated venues are hidden from Courts Nearby.',
                              style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: keys.isEmpty
                        ? Center(child: Text('No registered court venues found', style: GoogleFonts.outfit(color: Colors.grey)))
                        : ListView.separated(
                            itemCount: keys.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              String key = keys[index];
                              final item = _venueSummaries[key]!;
                              bool isActive = _isVenueCurrentlyActive(item['venueName'], item['ownerEmail']);

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isActive ? Colors.green.shade50 : Colors.red.shade50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isActive ? Icons.check_circle : Icons.pause_circle_filled,
                                    color: isActive ? Colors.green.shade700 : Colors.red.shade700,
                                  ),
                                ),
                                title: Text(
                                  item['venueName'],
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                subtitle: Text(
                                  'Owner: ${item['ownerEmail']} • ${item['bookingsCount']} bookings',
                                  style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade600),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isActive ? Colors.green.shade100 : Colors.red.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        isActive ? 'Active 🟢' : 'Deactivated 🔴',
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isActive ? Colors.green.shade900 : Colors.red.shade900,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Switch(
                                      value: isActive,
                                      activeColor: AppColors.primaryGreen,
                                      inactiveThumbColor: Colors.redAccent,
                                      onChanged: (val) async {
                                        await _handleToggleVenueActivation(item['venueName'], item['ownerEmail'], item['courtId'], isActive);
                                        setModalState(() {});
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
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

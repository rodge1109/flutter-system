import 'package:flutter_project/theme/app_colors.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/custom_paddle_icon.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../models/service_model.dart';
import '../models/customer_model.dart';
import '../models/loyalty_settings_model.dart';
import '../widgets/loyalty_stamp_card_widget.dart';
import '../services/api_service.dart';
import 'booking_confirmation_screen.dart';
import 'login_screen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../utils/download_helper_stub.dart' if (dart.library.html) '../utils/download_helper_web.dart';

class BookingScreen extends StatefulWidget {
  final ServiceModel? initialService;
  final String? initialServiceName;
  final bool skipServiceSelection;
  final String? initialDate;
  final String? initialTime;

  final Map<String, dynamic>? venue;

  const BookingScreen({
    Key? key,
    this.initialService,
    this.initialServiceName,
    this.skipServiceSelection = false,
    this.initialDate,
    this.initialTime,
    this.venue,
  }) : super(key: key);

  @override
  _BookingScreenState createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final ApiService _apiService = ApiService();
  int _currentStep = 0;
  List<ServiceModel> _services = [];
  bool _isLoading = true;
  
  ServiceModel? _selectedService;
  Set<int> _selectedServiceIds = {};
  DateTime? _selectedDate;
  List<String> _selectedTimes = [];
  List<String> _bookedSlots = [];
  Map<String, List<String>> _courtBookedSlots = {};
  bool _isLoadingSlots = false;
  String _selectedCategory = 'All';
  Set<int> _expandedCourtIds = {};
  
  final List<String> _allTimeSlots = List.generate(24, (i) {
    int h = i % 12 == 0 ? 12 : i % 12;
    String ampm = i < 12 ? 'AM' : 'PM';
    return '$h:00 $ampm';
  });
  
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedPaymentMethod = 'GCASH';
  Uint8List? _proofOfPaymentBytes;
  final ImagePicker _picker = ImagePicker();

  bool _isOpenPlay = false;
  String _openPlayType = 'DOUBLES';
  final _openPlayMaxPlayersController = TextEditingController(text: '4');
  final _openPlayPriceController = TextEditingController();
  final _openPlayInstructionsController = TextEditingController();
  final _openPlayPaymentDetailsController = TextEditingController();
  
  bool _isOpenChallenge = false;
  String _challengeType = 'singles';
  final _hostTandemNameController = TextEditingController();
  final _challengeDescriptionController = TextEditingController();
  final _referenceNumberController = TextEditingController();

  String? _holdToken;
  Timer? _holdTimer;
  int _holdSecondsRemaining = 0;

  CustomerModel? _customerLoyalty;
  LoyaltySettingsModel? _loyaltySettings;

  @override
  void initState() {
    super.initState();
    if (widget.initialDate != null) {
      _selectedDate = DateTime.parse(widget.initialDate!);
    } else {
      _selectedDate = DateTime.now();
    }
    if (widget.initialTime != null) {
      _selectedTimes = [widget.initialTime!];
    }
    _emailController.addListener(() {
      if (_emailController.text.contains('@') && _emailController.text.contains('.')) {
        _checkLoyaltyStatus();
      }
    });
    _loadServices();
    _loadUserData();
  }

  Future<void> _checkLoyaltyStatus() async {
    if (_emailController.text.trim().isEmpty) return;
    String ownerEmail = _selectedService?.ownerPayment?['owner_email'] ?? '';
    if (ownerEmail.isEmpty && widget.venue != null) {
      ownerEmail = widget.venue!['owner_email'] ?? widget.venue!['email'] ?? '';
    }
    if (ownerEmail.isEmpty && _services.isNotEmpty) {
      for (var s in _services) {
        if (s.ownerPayment?['owner_email']?.toString().isNotEmpty == true) {
          ownerEmail = s.ownerPayment!['owner_email'].toString();
          break;
        }
      }
    }
    if (ownerEmail.isNotEmpty) {
      final loyalty = await _apiService.fetchCustomerLoyaltyStatus(_emailController.text.trim(), ownerEmail);
      final settings = await _apiService.fetchLoyaltySettings(ownerEmail);
      if (mounted) {
        setState(() {
          _customerLoyalty = loyalty;
          _loyaltySettings = settings;
        });
      }
    }
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    if (userStr != null) {
      final userObj = json.decode(userStr);
      setState(() {
        _nameController.text = userObj['full_name'] ?? '';
        _emailController.text = userObj['email'] ?? '';
        _phoneController.text = userObj['phone_number'] ?? '';
      });
      _checkLoyaltyStatus();
    }
    
    // Load Open Play defaults
    setState(() {
      _openPlayInstructionsController.text = prefs.getString('open_play_instructions_default') ?? '';
      _openPlayPaymentDetailsController.text = prefs.getString('open_play_payment_details_default') ?? '';
    });
  }

  Future<void> _loadServices() async {
    if (widget.venue != null && widget.venue!['courts'] != null) {
      final List<dynamic> rawCourts = widget.venue!['courts'];
      final List<ServiceModel> venueCourts = rawCourts.asMap().entries.map((entry) {
        final idx = entry.key;
        final c = entry.value;
        int courtId = c['id'] is int ? c['id'] : (int.tryParse(c['id'].toString()) ?? (1000 + idx));

        List<dynamic>? parsedVar;
        final rawVar = c['variable_prices'] ?? c['variablePrices'] ?? c['hourly_prices'] ?? c['hourlyPrices'] ?? c['serviceObj']?.variablePrices ?? c['serviceObj']?.hourlyPrices;
        if (rawVar != null) {
          if (rawVar is List) {
            parsedVar = rawVar;
          } else if (rawVar is String) {
            try {
              final decoded = json.decode(rawVar);
              if (decoded is List) parsedVar = decoded;
            } catch (_) {}
          }
        }

        return ServiceModel(
          id: courtId,
          name: c['name'] ?? 'Court ${idx + 1}',
          description: c['description'] ?? 'Court at ${widget.venue!['venueName'] ?? 'Venue'}',
          price: 'PHP ${c['price'] ?? widget.venue!['basePrice'] ?? '300'}',
          icon: c['icon'] ?? '🎾',
          duration: c['duration'] ?? '1H',
          category: 'pickle',
          isActive: true,
          variablePrices: parsedVar,
          hourlyPrices: parsedVar,
          ownerPayment: widget.venue!['owner_payment'] ?? widget.venue!['ownerPayment'] ?? c['owner_payment'],
          openTime: c['open_time'] ?? c['openTime'],
          closeTime: c['close_time'] ?? c['closeTime'],
          latitude: c['latitude'] != null ? double.tryParse(c['latitude'].toString()) : null,
          longitude: c['longitude'] != null ? double.tryParse(c['longitude'].toString()) : null,
          aboutVenue: c['about_venue'] ?? c['aboutVenue'] ?? widget.venue!['aboutVenue'],
          bookingPolicy: c['booking_policy'] ?? c['bookingPolicy'] ?? widget.venue!['bookingPolicy'],
          faq: c['faq'] ?? widget.venue!['faq'],
          dayStartHour: c['day_start_hour'] ?? c['dayStartHour'] ?? widget.venue!['day_start_hour'] ?? widget.venue!['dayStartHour'],
          nightStartHour: c['night_start_hour'] ?? c['nightStartHour'] ?? widget.venue!['night_start_hour'] ?? widget.venue!['nightStartHour'],
        );
      }).toList();

      if (venueCourts.isNotEmpty) {
        ServiceModel selected = venueCourts.first;
        if (widget.initialServiceName != null && widget.initialServiceName!.isNotEmpty) {
          final target = widget.initialServiceName!.trim().toLowerCase();
          final matched = venueCourts.firstWhere(
            (s) => s.name.toLowerCase().contains(target) || target.contains(s.name.toLowerCase()),
            orElse: () => venueCourts.first,
          );
          selected = matched;
        }

        // Reorder list so selected court (Aminova) is at index 0 at the top
        if (venueCourts.contains(selected)) {
          venueCourts.remove(selected);
          venueCourts.insert(0, selected);
        }

        setState(() {
          _services = venueCourts;
          _selectedService = selected;
          _selectedServiceIds = {selected.id};
          _expandedCourtIds = {selected.id};
          _isLoading = false;
        });
        _fetchSlots();
        return;
      }
    }

    try {
      final services = await _apiService.fetchServices();
      setState(() {
        _services = services.where((s) => s.isActive && s.category.toLowerCase().contains('pickle')).toList();
        _isLoading = false;

        if (widget.initialService != null) {
          _selectedService = widget.initialService;
          _selectedServiceIds = {_selectedService!.id};
          _expandedCourtIds = {_selectedService!.id};
        } else if (widget.initialServiceName != null && widget.initialServiceName!.isNotEmpty) {
          final matchName = widget.initialServiceName!.toLowerCase();
          final match = _services.firstWhere(
            (s) => s.name.toLowerCase().contains(matchName) || matchName.contains(s.name.toLowerCase()),
            orElse: () => ServiceModel(
              id: 999,
              name: widget.initialServiceName!,
              description: 'Enjoy a fun and active game on our well-maintained pickleball court, perfect for players of all skill levels.',
              price: 'PHP 350',
              icon: '🎾',
              duration: '30M',
              category: 'pickle',
              isActive: true,
            ),
          );
          _selectedService = match;
          _selectedServiceIds = {match.id};
          _expandedCourtIds = {match.id};

          if (_services.contains(match)) {
            _services.remove(match);
            _services.insert(0, match);
          }
        } else if (_services.isNotEmpty) {
          _selectedService = _services.first;
          _selectedServiceIds = {_services.first.id};
          _expandedCourtIds = {_services.first.id};
        }
      });
      _fetchSlots();
      _checkLoyaltyStatus();
    } catch (e) {
      setState(() {
        _isLoading = false;
        if (widget.initialServiceName != null && widget.initialServiceName!.isNotEmpty) {
          _selectedService = ServiceModel(
            id: 999,
            name: widget.initialServiceName!,
            description: 'Enjoy a fun and active game on our well-maintained pickleball court, perfect for players of all skill levels.',
            price: 'PHP 350',
            icon: '🎾',
            duration: '30M',
            category: 'pickle',
            isActive: true,
          );
        }
      });
      _fetchSlots();
    }
  }

  Future<void> _fetchSlots() async {
    if (_selectedDate == null || _services.isEmpty) return;
    setState(() => _isLoadingSlots = true);
    
    final dateStr = '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';
    
    Map<String, List<String>> courtBookings = {};
    
    for (var service in _services) {
      final result = await _apiService.fetchAvailableSlots(dateStr, service.name);
      final List<String> booked = (result['bookedSlots'] ?? []).map<String>((s) => s.toString()).toList();
      final List<String> blocked = (result['blockedSlots'] ?? []).map<String>((s) => s.toString()).toList();
      courtBookings[service.name] = [...booked, ...blocked];
    }
    
    setState(() {
      _courtBookedSlots = courtBookings;
      
      // We still update a unified _bookedSlots for legacy compatibility if needed
      List<String> allBooked = [];
      for (var list in courtBookings.values) {
        allBooked.addAll(list);
      }
      _bookedSlots = allBooked.toSet().toList();
      
      // Remove selected times if booked for that specific court
      _selectedTimes.removeWhere((rawTime) {
        if (rawTime.contains(': ')) {
          final parts = rawTime.split(': ');
          final courtName = parts[0];
          final cleanTime = parts[1];
          return _courtBookedSlots[courtName]?.contains(cleanTime) ?? false;
        } else if (_selectedService != null) {
           return _courtBookedSlots[_selectedService!.name]?.contains(rawTime) ?? false;
        }
        return false;
      });
      _isLoadingSlots = false;
    });
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _holdSelectedSlots() async {
    if (_selectedDate == null || _selectedTimes.isEmpty || _nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a date, time, and enter your name first'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isLoading = true);

    final dateStr = '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';
    
    // Group selected times by court/service name
    Map<String, List<String>> slotsByService = {};
    for (var rawTime in _selectedTimes) {
      String sName = _selectedService?.name ?? 'Court';
      String cleanTime = rawTime;
      int idx = rawTime.indexOf(': ');
      if (idx != -1) {
        sName = rawTime.substring(0, idx).trim();
        cleanTime = rawTime.substring(idx + 2).trim();
      }
      slotsByService.putIfAbsent(sName, () => []);
      slotsByService[sName]!.add(cleanTime);
    }

    String? lastHoldToken;
    bool holdFailed = false;

    for (var entry in slotsByService.entries) {
      final sName = entry.key;
      final timesList = entry.value;

      final holdToken = await _apiService.holdSlots(
        dateStr: dateStr,
        times: timesList,
        serviceType: sName,
        email: _emailController.text,
      );

      if (holdToken != null) {
        lastHoldToken = holdToken;
      } else {
        holdFailed = true;
        break;
      }
    }

    setState(() => _isLoading = false);

    if (!holdFailed && lastHoldToken != null) {
      setState(() {
        _holdToken = lastHoldToken;
        _holdSecondsRemaining = 300; // 5 minutes
      });
      _holdTimer?.cancel();
      _holdTimer = Timer.periodic(Duration(seconds: 1), (timer) {
        setState(() {
          if (_holdSecondsRemaining > 0) {
            _holdSecondsRemaining--;
          } else {
            _holdTimer?.cancel();
            _holdToken = null;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Hold expired! Please hold your slots again.'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
                margin: EdgeInsets.only(
                  bottom: MediaQuery.of(context).size.height - 180,
                  left: 16,
                  right: 16,
                ),
              ),
            );
          }
        });
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Slots held! You have 5 minutes to complete your booking.'),
          backgroundColor: AppColors.primaryGreen,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 180,
            left: 16,
            right: 16,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sorry, one or more slots are already taken or held.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 180,
            left: 16,
            right: 16,
          ),
        ),
      );
      _fetchSlots();
    }
  }

  void _submitBooking() async {
    if (_selectedDate == null || _selectedTimes.isEmpty || _nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });

    bool allSuccess = true;

    for (var rawTime in _selectedTimes) {
      String sName = _selectedService?.name ?? 'Court';
      String cleanTime = rawTime;
      int idx = rawTime.indexOf(': ');
      if (idx != -1) {
        sName = rawTime.substring(0, idx).trim();
        cleanTime = rawTime.substring(idx + 2).trim();
      }

      final matchedService = _services.firstWhere(
        (s) => s.name == sName,
        orElse: () => _selectedService ?? ServiceModel(
          id: 999,
          name: sName,
          description: '',
          price: 'PHP 350',
          icon: '🎾',
          duration: '1H',
          category: 'pickle',
          isActive: true,
        ),
      );

      String priceStr = _getPriceForTime(cleanTime, service: matchedService).replaceAll(RegExp(r'[^0-9.]'), '');
      double slotAmount = double.tryParse(priceStr) ?? 350.0;

      final appointmentData = {
        'serviceType': sName, 
        'specialistId': matchedService.id.toString(),
        'preferredDate': '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}',
        'preferredTime': cleanTime,
        'fullName': _nameController.text,
        'email': _emailController.text,
        'phoneNumber': _phoneController.text,
        'paymentMethod': _selectedPaymentMethod,
        'totalAmount': slotAmount,
        'proofOfPayment': _referenceNumberController.text.isNotEmpty ? 'REF: ${_referenceNumberController.text}' : null,
        'isOpenPlay': _isOpenPlay,
        'openPlayType': _openPlayType,
        'openPlayMaxPlayers': int.tryParse(_openPlayMaxPlayersController.text) ?? 4,
        'openPlayPrice': double.tryParse(_openPlayPriceController.text) ?? 0.0,
        'openPlayInstructions': _openPlayInstructionsController.text,
        'openPlayPaymentDetails': _openPlayPaymentDetailsController.text,
        'isOpenChallenge': _isOpenChallenge,
        'challengeType': _challengeType,
        'hostTandemName': _hostTandemNameController.text,
        'challengeDescription': _challengeDescriptionController.text,
        'holdToken': _holdToken,
      };

      final success = await _apiService.submitAppointment(appointmentData);
      if (!success) {
        allSuccess = false;
      }
    }

    setState(() {
      _isLoading = false;
    });

    if (allSuccess) {
      if (_isOpenPlay) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('open_play_instructions_default', _openPlayInstructionsController.text);
        await prefs.setString('open_play_payment_details_default', _openPlayPaymentDetailsController.text);
      }

      final double totalAmount = _selectedTimes.fold(0.0, (sum, time) {
        String priceStr = _getPriceForTime(time).replaceAll(RegExp(r'[^0-9.]'), '');
        return sum + (double.tryParse(priceStr) ?? 0.0);
      });

      final String courtName = _selectedService?.name ?? 'Smash Zone Pickleball';
      final String courtAddress = _selectedService?.address.isNotEmpty == true 
          ? _selectedService!.address 
          : (_selectedService?.description.isNotEmpty == true ? _selectedService!.description : 'Cayang');
      final String? courtImage = _selectedService?.icon;
      final DateTime date = _selectedDate ?? DateTime.now();
      final List<String> times = List.from(_selectedTimes);
      final String courtNum = courtName;

      // Navigate to the beautiful BookingConfirmationScreen matching design screenshot
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookingConfirmationScreen(
            courtName: courtName,
            courtAddress: courtAddress,
            courtImage: courtImage,
            bookingDate: date,
            timeSlots: times,
            courtNumber: courtNum,
            totalPaid: (_customerLoyalty != null && _customerLoyalty!.stampCount >= 9 && (_loyaltySettings?.freeRewardEnabled ?? true))
                ? 0.0
                : (totalAmount > 0 ? totalAmount : 350.0) + _getServiceFee(),
          ),
        ),
      );

      // Reset after booking
      setState(() {
        _currentStep = 0;
        _selectedService = null;
        _selectedDate = null;
        _selectedTimes = [];
        _nameController.clear();
        _emailController.clear();
        _phoneController.clear();
      });

      if (mounted) {
        Navigator.pop(context, result);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Some bookings failed to submit. Please try again.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _getPriceForTime(String time, {ServiceModel? service}) {
    final s = service ?? _selectedService;
    if (s == null) return '';
    double basePrice = 300.0;
    
    List<dynamic>? vPrices = s.variablePrices;
    if (vPrices == null && s.hourlyPrices != null) {
      if (s.hourlyPrices is List) {
        vPrices = s.hourlyPrices as List;
      } else if (s.hourlyPrices is String) {
        try {
          final decoded = json.decode(s.hourlyPrices);
          if (decoded is List) vPrices = decoded;
        } catch (_) {}
      }
    }

    final targetNormalized = _normalizeTime(time);

    if (vPrices != null && vPrices.isNotEmpty) {
      bool found = false;
      for (var vp in vPrices) {
        if (vp is! Map) continue;
        String? vpTime = vp['time']?.toString();
        String? vpHour = vp['hour']?.toString();
        
        if ((vpTime != null && _normalizeTime(vpTime) == targetNormalized) ||
            (vpHour != null && _normalizeTime(vpHour) == targetNormalized)) {
          final price = vp['price'] ?? vp['standardPrice'] ?? vp['standard_price'];
          if (price != null) {
            String priceStr = price.toString().replaceAll(RegExp(r'[^0-9.]'), '');
            double? parsed = double.tryParse(priceStr);
            if (parsed != null && parsed > 0) {
              basePrice = parsed;
              found = true;
              break;
            }
          }
        }
      }
      if (!found) {
        int dayStart = s.dayStartHour ?? 6;
        int nightStart = s.nightStartHour ?? 18;
        int h = _parseHourFromTimeString(time);
        bool isDay = dayStart < nightStart
            ? (h >= dayStart && h < nightStart)
            : (h >= dayStart || h < nightStart);
        basePrice = isDay ? 200.0 : 300.0;
      }
    } else {
      int dayStart = s.dayStartHour ?? 6;
      int nightStart = s.nightStartHour ?? 18;
      int h = _parseHourFromTimeString(time);
      bool isDay = dayStart < nightStart
          ? (h >= dayStart && h < nightStart)
          : (h >= dayStart || h < nightStart);
      basePrice = isDay ? 200.0 : 300.0;
    }

    // Automatically apply member discount for registered members
    if (_customerLoyalty?.isMember == true && _loyaltySettings != null) {
      double memberPrice = _loyaltySettings!.calculateMemberPrice(basePrice);
      if (memberPrice > 0 && memberPrice < basePrice) {
        return 'PHP ${memberPrice.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '')}';
      }
    }

    return basePrice > 0 ? 'PHP ${basePrice.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '')}' : s.price;
  }

  int _parseHourFromTimeString(String time) {
    String clean = time.trim().toUpperCase();
    bool isPm = clean.contains('PM');
    bool isAm = clean.contains('AM');
    clean = clean.replaceAll('AM', '').replaceAll('PM', '').trim();
    if (clean.contains(':')) {
      final parts = clean.split(':');
      int h = int.tryParse(parts[0]) ?? 0;
      if (isPm && h < 12) h += 12;
      if (isAm && h == 12) h = 0;
      return h;
    }
    int h = int.tryParse(clean) ?? 0;
    if (isPm && h < 12) h += 12;
    if (isAm && h == 12) h = 0;
    return h;
  }

  String _normalizeTime(String t) {
    String clean = t.trim();
    if (clean.toUpperCase().contains('AM') || clean.toUpperCase().contains('PM')) {
      if (clean.startsWith('0')) clean = clean.substring(1);
      return clean.toUpperCase();
    }
    if (clean.contains(':')) {
      final parts = clean.split(':');
      if (parts.length >= 2) {
        int h = int.tryParse(parts[0]) ?? 0;
        String min = parts[1];
        String ampm = h < 12 ? 'AM' : 'PM';
        int displayH = h % 12;
        if (displayH == 0) displayH = 12;
        return '$displayH:$min $ampm';
      }
    }
    int? plainH = int.tryParse(clean);
    if (plainH != null) {
      String ampm = plainH < 12 ? 'AM' : 'PM';
      int displayH = plainH % 12;
      if (displayH == 0) displayH = 12;
      return '$displayH:00 $ampm';
    }
    return clean.toUpperCase();
  }

  List<String> _getDisplayTimeSlots({ServiceModel? service}) {
    final s = service ?? _selectedService;
    if (s != null && s.variablePrices != null && s.variablePrices!.isNotEmpty) {
      List<String> definedSlots = [];
      for (var vp in s.variablePrices!) {
        if (vp is Map && vp['time'] != null && vp['time'].toString().isNotEmpty) {
          definedSlots.add(_normalizeTime(vp['time'].toString()));
        } else if (vp is Map && vp['hour'] != null && vp['hour'].toString().isNotEmpty) {
          definedSlots.add(_normalizeTime(vp['hour'].toString()));
        }
      }
      if (definedSlots.isNotEmpty) return definedSlots;
    }
    return _allTimeSlots;
  }

  Widget _buildIcon(String iconString) {
    if (iconString.startsWith('/uploads') || iconString.startsWith('http')) {
      final url = iconString.startsWith('/uploads') 
          ? 'http://localhost:5000$iconString' 
          : iconString;
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey)),
      );
    }
    return Center(
      child: Text(
        iconString.isNotEmpty ? iconString.substring(0, 1) : '🎾',
        style: TextStyle(fontSize: 50),
      ),
    );
  }
  void _handleStepContinue(bool skipChooseService) {
    if (_currentStep == 0 && (_selectedDate == null || _selectedTimes.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Select at least one time slot')));
      return;
    }
    if (_currentStep == 0 && _holdToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please click "Lock in this time" before proceeding.')));
      return;
    }
    if (_currentStep == 1 && (_nameController.text.isEmpty || _phoneController.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please fill your details')));
      return;
    }
    if (_currentStep == 2 && _referenceNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please enter your reference number to continue')));
      return;
    }

    if (_currentStep < 3) {
      setState(() => _currentStep += 1);
    } else {
      _submitBooking();
    }
  }

  void _handleStepCancel() {
    if (_holdToken != null) {
      _holdTimer?.cancel();
      setState(() {
        _holdToken = null;
        _holdSecondsRemaining = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Timeslot lock reset. You can now select different timeslots.'),
          backgroundColor: AppColors.primaryGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (_currentStep > 0) {
        setState(() => _currentStep -= 1);
      }
      return;
    }

    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool skipChooseService = widget.skipServiceSelection || widget.initialService != null || (widget.initialServiceName != null && widget.initialServiceName!.isNotEmpty);
    final int maxStep = 3;

    List<Step> steps = [];

    if (!skipChooseService) {
      steps.add(
        Step(
          title: Text('Courts & Times', style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.richBlack)),
          content: _buildSelectCourtsAndTimes(),
          isActive: _currentStep >= 0,
          state: _currentStep > 0 ? StepState.complete : StepState.indexed,
        ),
      );
    } else {
      steps.add(
        Step(
          title: Text('Date & Time', style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.richBlack)),
          content: _buildSelectCourtsAndTimes(),
          isActive: _currentStep >= 0,
          state: _currentStep > 0 ? StepState.complete : StepState.indexed,
        ),
      );
    }

    steps.addAll([
      Step(
        title: Text('Your Details', style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.richBlack)),
        content: _buildUserDetails(),
        isActive: _currentStep >= (skipChooseService ? 1 : 2),
        state: _currentStep > (skipChooseService ? 1 : 2) ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: Text('Payment', style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.richBlack)),
        content: _buildPaymentSelection(),
        isActive: _currentStep >= (skipChooseService ? 2 : 3),
        state: _currentStep > (skipChooseService ? 2 : 3) ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: Text('Confirmation', style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.richBlack)),
        content: _buildConfirmation(),
        isActive: _currentStep >= (skipChooseService ? 3 : 4),
      ),
    ]);


    // Step labels
    final List<String> stepLabels = skipChooseService
        ? ['Date & Time', 'Your Details', 'Payment', 'Confirm']
        : ['Courts & Times', 'Your Details', 'Payment', 'Confirm'];

    return PopScope(
      canPop: _currentStep == 0 && _holdToken == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleStepCancel();
      },
      child: Scaffold(
        backgroundColor: AppColors.creamWhite,
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.richBlack),
            onPressed: _handleStepCancel,
          ),
          title: RichText(
            text: TextSpan(
              style: TextStyle(fontFamily: 'Poppins', fontSize: 21, color: AppColors.richBlack, letterSpacing: 1),
              children: [
                TextSpan(text: 'PICKLE', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w900)),
                TextSpan(text: 'BOOK', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w300)),
              ]
            ),
          ),
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
          iconTheme: IconThemeData(color: AppColors.richBlack),
        ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.richBlack))
          : Column(
              children: [
                // ── Horizontal Step Indicator ──
                Container(
                  color: AppColors.creamWhite,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Column(
                    children: [
                      Row(
                        children: List.generate(stepLabels.length, (i) {
                          final bool isDone = i < _currentStep;
                          final bool isActive = i == _currentStep;
                          return Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 300),
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: isDone
                                              ? AppColors.primaryGreen
                                              : isActive
                                                  ? AppColors.richBlack
                                                  : Colors.grey.shade200,
                                          shape: BoxShape.circle,
                                          boxShadow: isActive
                                              ? [BoxShadow(color: AppColors.richBlack.withOpacity(0.18), blurRadius: 6, offset: Offset(0, 2))]
                                              : [],
                                        ),
                                        child: Center(
                                          child: isDone
                                              ? Icon(Icons.check, size: 14, color: Colors.white)
                                              : Text(
                                                  '${i + 1}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: isActive ? Colors.white : Colors.grey.shade500,
                                                  ),
                                                ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        stepLabels[i],
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontFamily: 'Poppins',
                                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                          color: isActive
                                              ? AppColors.richBlack
                                              : isDone
                                                  ? AppColors.primaryGreen
                                                  : Colors.grey.shade400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (i < stepLabels.length - 1)
                                  Expanded(
                                    child: Container(
                                      height: 2,
                                      margin: const EdgeInsets.only(bottom: 18),
                                      decoration: BoxDecoration(
                                        color: i < _currentStep ? AppColors.primaryGreen : Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),

                // ── Step Content ──
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (skipChooseService)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.primaryGreen.withOpacity(0.2)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(7),
                                  decoration: BoxDecoration(color: AppColors.primaryGreen, shape: BoxShape.circle),
                                  child: CustomPaddleIcon(color: AppColors.softWhite, size: 16),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('VENUE SELECTED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.richBlack.withOpacity(0.54), letterSpacing: 0.5)),
                                      SizedBox(height: 2),
                                      Text((widget.venue?['venueName'] ?? widget.venue?['name'] ?? 'KAPENARRA COURTSIDE').toString().toUpperCase(), style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.richBlack)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Active step content
                        steps[_currentStep].content,

                        const SizedBox(height: 24),

                        // Navigation buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _handleStepContinue(skipChooseService),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryGreen,
                                  foregroundColor: AppColors.softWhite,
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                                ),
                                child: Text(
                                  _currentStep == maxStep ? 'Confirm Booking' : 'Continue',
                                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.softWhite),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _handleStepCancel,
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  side: BorderSide(color: Colors.grey.shade400),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                                ),
                                child: Text('Back', style: TextStyle(fontFamily: 'Poppins', color: AppColors.richBlack, fontWeight: FontWeight.bold, fontSize: 13)),
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
    );
  }


  Widget _buildSelectCourtsAndTimes() {
    final List<String> fullMonths = [
      'January', 'February', 'March', 'April', 'May', 'June', 
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    String displayDate = '';
    if (_selectedDate != null) {
      displayDate = '${weekdays[_selectedDate!.weekday - 1]}, ${fullMonths[_selectedDate!.month - 1]} ${_selectedDate!.day}, ${_selectedDate!.year}';
    }

    // Get unique categories from services
    final categories = ['All'];
    for (var s in _services) {
      if (s.category.isNotEmpty && !categories.contains(s.category)) {
        categories.add(s.category);
      }
    }

    final filteredServices = _selectedCategory == 'All' 
        ? _services 
        : _services.where((s) => s.category == _selectedCategory).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_customerLoyalty?.isMember == true)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryGreen.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.verified, color: AppColors.primaryGreen, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '🌟 VIP Member Discount Active: Automatic member prices are applied!',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.richBlack),
                  ),
                ),
              ],
            ),
          ),
        _buildVenueInformationSection(),
        SizedBox(height: 16),
        // Date Selector Header
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: AppColors.primaryGreen,
                onPrimary: Colors.white,
                onSurface: AppColors.richBlack,
              ),
            ),
            child: CalendarDatePicker(
              initialDate: _selectedDate ?? DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 90)),
              onDateChanged: (picked) {
                if (_holdToken != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Timeslots are locked. Click BACK to modify your selection.'),
                      backgroundColor: Colors.orange,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                setState(() {
                  _selectedDate = picked;
                  _selectedTimes.clear();
                });
                _fetchSlots();
              },
            ),
          ),
        ),
        SizedBox(height: 16),

        // Category Filter
        Row(
          children: [
            Text('Sport', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            SizedBox(width: 12),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: categories.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    IconData? catIcon;
                    if (cat.toLowerCase().contains('pickle')) catIcon = Icons.sports_tennis;
                    if (cat.toLowerCase().contains('basket')) catIcon = Icons.sports_basketball;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Row(
                          children: [
                            if (catIcon != null) ...[
                              Icon(catIcon, size: 14, color: isSelected ? Colors.white : Colors.grey.shade800),
                              SizedBox(width: 4),
                            ],
                            Text(
                              cat,
                              style: TextStyle(
                                fontSize: 13,
                                color: isSelected ? Colors.white : Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                        selected: isSelected,
                        onSelected: (val) {
                          if (val) {
                            if (_holdToken != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Timeslots are locked. Click BACK to modify your selection.'),
                                  backgroundColor: Colors.orange,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }
                            setState(() => _selectedCategory = cat);
                          }
                        },
                        selectedColor: AppColors.primaryGreen,
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: isSelected ? AppColors.primaryGreen : Colors.grey.shade300),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),

        // Courts List
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: filteredServices.length,
          itemBuilder: (context, index) {
            final court = filteredServices[index];
            final isExpanded = _expandedCourtIds.contains(court.id);
            
            return Container(
              margin: EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
              child: ExpansionTile(
                initiallyExpanded: isExpanded,
                onExpansionChanged: (expanded) {
                  setState(() {
                    if (expanded) {
                      _expandedCourtIds.add(court.id);
                      // Auto-select this court if expanding
                      _selectedServiceIds.add(court.id);
                      _selectedService = court;
                      if (_selectedTimes.isEmpty) _fetchSlots();
                    } else {
                      _expandedCourtIds.remove(court.id);
                    }
                  });
                },
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      court.name,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.richBlack),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          court.price,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                        SizedBox(width: 12),
                        Icon(Icons.camera_alt_outlined, size: 14, color: Colors.grey.shade500),
                        SizedBox(width: 4),
                        Text(
                          '3 photos', // Mock for now as per plan
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _isLoadingSlots 
                      ? Center(child: CircularProgressIndicator())
                      : GridView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 2.0,
                          ),
                          itemCount: _getDisplayTimeSlots(service: court).length,
                          itemBuilder: (context, idx) {
                            final time = _getDisplayTimeSlots(service: court)[idx];
                            final slotKey = '${court.name}: $time';
                            final isSelected = _selectedTimes.contains(slotKey) || (_selectedServiceIds.length == 1 && _selectedTimes.contains(time));
                            final isBooked = _courtBookedSlots[court.name]?.contains(time) ?? false;

                            bool isPast = false;
                            bool isOutsideHours = false;

                            int slotHour = 0;
                            if (time.contains(':')) {
                              final parts = time.split(RegExp(r'[:\s]'));
                              if (parts.length >= 3) {
                                slotHour = int.tryParse(parts[0]) ?? 0;
                                if (parts[2].toUpperCase() == 'PM' && slotHour < 12) slotHour += 12;
                                if (parts[2].toUpperCase() == 'AM' && slotHour == 12) slotHour = 0;
                              }
                            } else {
                              slotHour = _allTimeSlots.indexOf(time);
                            }

                            if (_selectedDate != null) {
                              final now = DateTime.now();
                              if (_selectedDate!.year == now.year &&
                                  _selectedDate!.month == now.month &&
                                  _selectedDate!.day == now.day) {
                                if (slotHour < now.hour) {
                                  isPast = true;
                                } else if (slotHour == now.hour && now.minute > 0) {
                                  isPast = true;
                                }
                              }
                            }

                            if (court.openTime != null && court.openTime!.contains(':')) {
                              int openHour = int.tryParse(court.openTime!.split(':')[0]) ?? 0;
                              if (slotHour < openHour) isOutsideHours = true;
                            }
                            if (court.closeTime != null && court.closeTime!.contains(':')) {
                              int closeHour = int.tryParse(court.closeTime!.split(':')[0]) ?? 24;
                              if (slotHour >= closeHour) isOutsideHours = true;
                            }

                            final bool isDisabled = isBooked || isPast || isOutsideHours;

                            String getEndStr(String t) {
                              final parts = t.split(RegExp(r'[:\s]'));
                              if (parts.length >= 3) {
                                int h = int.tryParse(parts[0]) ?? 0;
                                String ampm = parts[2].toUpperCase();
                                int endH = h + 1;
                                if (endH == 12) ampm = ampm == 'AM' ? 'PM' : 'AM';
                                if (endH > 12) endH -= 12;
                                return '${endH}${ampm}';
                              }
                              return t;
                            }

                            final String startStr = time.replaceFirst(':00', '').replaceAll(' ', '').replaceFirst(RegExp(r'^0'), '');
                            final String displayTime = '${startStr}-${getEndStr(time)}';

                            return InkWell(
                              onTap: isDisabled ? null : () {
                                if (_holdToken != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Timeslot locked. Click BACK to modify your selection.'),
                                      backgroundColor: Colors.orange,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }
                                setState(() {
                                  // Ensure court is selected
                                  _selectedServiceIds.add(court.id);
                                  _selectedService = court;

                                  if (isSelected) {
                                    _selectedTimes.remove(slotKey);
                                    _selectedTimes.remove(time);
                                  } else {
                                    _selectedTimes.add(slotKey);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isDisabled 
                                          ? Colors.grey.shade200 
                                          : (isSelected ? AppColors.accentLime : AppColors.softWhite),
                                      border: isSelected ? null : Border.all(
                                        width: 1,
                                        color: Colors.grey.shade300,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              time.toUpperCase().contains('AM') ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined,
                                              size: 12,
                                              color: isSelected ? AppColors.softWhite : (isDisabled ? Colors.grey.shade400 : AppColors.deepTeal),
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              displayTime,
                                              style: TextStyle(
                                                color: isSelected ? AppColors.softWhite : (isDisabled ? Colors.grey.shade400 : AppColors.richBlack),
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isOutsideHours ? 'CLOSED' : (isPast ? 'PASSED' : (isBooked ? 'Booked' : _getPriceForTime(time, service: court))),
                                          style: TextStyle(
                                            color: isSelected ? AppColors.softWhite.withOpacity(0.90) : (isDisabled ? Colors.grey.shade500 : AppColors.richBlack),
                                            fontWeight: FontWeight.bold,
                                            fontSize: (isBooked || isOutsideHours) ? 9 : 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    Positioned(
                                      top: -5,
                                      right: -5,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: AppColors.softWhite,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: AppColors.accentLime, width: 1.5),
                                        ),
                                        child: Icon(Icons.check, size: 9, color: AppColors.accentLime),
                                      ),
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
        ),

        // Host Open Play / Challenge UI
        if (_selectedTimes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Open Play Toggle
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: CheckboxListTile(
                    title: Text('Host an Open Play', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.richBlack)),
                    subtitle: Text('Allow others to join your court slot', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    value: _isOpenPlay,
                    activeColor: AppColors.primaryGreen,
                    onChanged: (val) {
                      setState(() {
                        _isOpenPlay = val ?? false;
                        if (_isOpenPlay) _isOpenChallenge = false;
                      });
                    },
                  ),
                ),
                if (_isOpenPlay)
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          value: _openPlayType,
                          decoration: InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                          items: ['SINGLES', 'DOUBLES', 'MIXED'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                          onChanged: (val) => setState(() => _openPlayType = val!),
                        ),
                        SizedBox(height: 12),
                        TextFormField(
                          controller: _openPlayMaxPlayersController,
                          decoration: InputDecoration(labelText: 'Max Players', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                        ),
                        SizedBox(height: 12),
                        TextFormField(
                          controller: _openPlayPriceController,
                          decoration: InputDecoration(labelText: 'Price per player (?)', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                        ),
                        SizedBox(height: 12),
                        TextFormField(
                          controller: _openPlayInstructionsController,
                          decoration: InputDecoration(labelText: 'Instructions / Level', border: OutlineInputBorder()),
                          maxLines: 2,
                        ),
                        SizedBox(height: 12),
                        TextFormField(
                          controller: _openPlayPaymentDetailsController,
                          decoration: InputDecoration(labelText: 'Your GCash / Payment Info', border: OutlineInputBorder()),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),

                SizedBox(height: 12),

                // Challenge Toggle
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: CheckboxListTile(
                    title: Text('Post as a Challenge', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.richBlack)),
                    subtitle: Text('Challenge other players or tandems', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    value: _isOpenChallenge,
                    activeColor: AppColors.primaryGreen,
                    onChanged: (val) {
                      setState(() {
                        _isOpenChallenge = val ?? false;
                        if (_isOpenChallenge) _isOpenPlay = false;
                      });
                    },
                  ),
                ),
                if (_isOpenChallenge)
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          value: _challengeType,
                          decoration: InputDecoration(labelText: 'Challenge Type', border: OutlineInputBorder()),
                          items: ['singles', 'doubles', 'mixed'].map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase()))).toList(),
                          onChanged: (val) => setState(() => _challengeType = val!),
                        ),
                        SizedBox(height: 12),
                        TextFormField(
                          controller: _hostTandemNameController,
                          decoration: InputDecoration(labelText: 'Your Team / Player Name', border: OutlineInputBorder()),
                        ),
                        SizedBox(height: 12),
                        TextFormField(
                          controller: _challengeDescriptionController,
                          decoration: InputDecoration(labelText: 'Description / Stakes', border: OutlineInputBorder()),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

        // Lock in Time UI

        if (_selectedTimes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Column(
              children: [
                if (_holdToken == null)
                  ElevatedButton.icon(
                    icon: Icon(Icons.lock_clock, color: Colors.white),
                    label: Text('Lock in this time (5:00)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      minimumSize: Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isLoading ? null : _holdSelectedSlots,
                  ),
                if (_holdToken != null)
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border.all(color: Colors.orange.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.timer, color: Colors.orange.shade800),
                            SizedBox(width: 8),
                            Text(
                              'Time remaining to pay: ${_holdSecondsRemaining ~/ 60}:${(_holdSecondsRemaining % 60).toString().padLeft(2, '0')}',
                              style: TextStyle(
                                color: Colors.orange.shade800,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Timeslots locked. Click BACK to unlock and edit.',
                          style: TextStyle(fontSize: 12, color: Colors.orange.shade900, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildVenueInformationSection() {
    final Map<String, dynamic>? v = widget.venue;
    
    // 1. About Venue
    String aboutText = (v?['aboutVenue'] ?? v?['about_venue'] ?? v?['description'] ?? _selectedService?.description ?? '').toString().trim();
    if (aboutText.isEmpty) {
      aboutText = 'Welcome to our premier sports facility! Designed for players of all skill levels, our venue features professional-grade court surfaces, high-intensity LED lighting for evening games, spacious spectator seating, clean restrooms, and a welcoming community atmosphere.';
    }

    // 2. Booking Policy
    String policyText = (v?['bookingPolicy'] ?? v?['booking_policy'] ?? '').toString().trim();
    if (policyText.isEmpty) {
      policyText = '• Reservation & Payment: All bookings must be completed and confirmed prior to court entry.\n• Cancellation Policy: Free cancellation up to 24 hours before your reserved start time. Cancellations within 24 hours are non-refundable.\n• Arrival & Check-In: Please arrive 10-15 minutes before your scheduled slot. Late arrivals will not extend your reserved time.\n• Court Etiquette: Non-marking athletic shoes are strictly required to maintain court surface quality.';
    }

    // 3. FAQ / Q&A
    String faqText = (v?['faq'] ?? v?['faqText'] ?? '').toString().trim();
    if (faqText.isEmpty) {
      faqText = 'Q: Are paddles and balls available for rent or purchase?\nA: Yes! High-quality rental paddles and pickleballs are available at the front desk.\n\nQ: Is on-site parking available for players?\nA: Yes, we provide free dedicated parking directly adjacent to the venue.\n\nQ: What footwear is allowed on the courts?\nA: Only non-marking court or athletic shoes are permitted.\n\nQ: Can I host Open Plays or Pasalo transfers here?\nA: Absolutely! You can post Open Plays or offer Pasalo slots directly through the app.';
    }

    // 4. Facilities
    List<dynamic>? rawFacilities = v?['facilities'] ?? _selectedService?.facilities;
    List<String> facilities = rawFacilities != null 
        ? rawFacilities.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList()
        : [];

    return Container(
      margin: const EdgeInsets.only(top: 24),
      decoration: BoxDecoration(
        color: AppColors.softWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.08),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.primaryGreen, size: 20),
                SizedBox(width: 8),
                Text(
                  'Venue Information & Rules',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.richBlack),
                ),
              ],
            ),
          ),
          
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: Column(
              children: [
                // About Venue Accordion
                ExpansionTile(
                  leading: Icon(Icons.business, color: AppColors.primaryGreen, size: 20),
                  title: Text('About This Venue', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.richBlack)),
                  initiallyExpanded: true,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Text(aboutText, style: TextStyle(color: Colors.grey.shade800, fontSize: 13, height: 1.4)),
                    ),
                  ],
                ),
                Divider(height: 1, color: Colors.grey.shade200),

                // Booking Policy Accordion
                ExpansionTile(
                  leading: Icon(Icons.gavel, color: AppColors.primaryGreen, size: 20),
                  title: Text('Booking Policy & Rules', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.richBlack)),
                  initiallyExpanded: false,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Text(policyText, style: TextStyle(color: Colors.grey.shade800, fontSize: 13, height: 1.4)),
                    ),
                  ],
                ),
                Divider(height: 1, color: Colors.grey.shade200),

                // Q & A Accordion
                ExpansionTile(
                  leading: Icon(Icons.help_outline, color: AppColors.primaryGreen, size: 20),
                  title: Text('Frequently Asked Questions (Q&A)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.richBlack)),
                  initiallyExpanded: false,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Text(faqText, style: TextStyle(color: Colors.grey.shade800, fontSize: 13, height: 1.4)),
                    ),
                  ],
                ),
                Divider(height: 1, color: Colors.grey.shade200),

                // Facilities & Amenities
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.star_outline, color: AppColors.primaryGreen, size: 20),
                          SizedBox(width: 8),
                          Text('Amenities & Facilities', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.richBlack)),
                        ],
                      ),
                      SizedBox(height: 10),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final itemWidth = (constraints.maxWidth - 16) / 2;
                          return Wrap(
                            spacing: 16,
                            runSpacing: 12,
                            children: facilities.map((f) {
                              return SizedBox(
                                width: itemWidth,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.check_circle_outline, color: AppColors.primaryGreen, size: 18),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        f,
                                        style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.3),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        }
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({required String title, required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        decoration: BoxDecoration(
          color: AppColors.softWhite,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: AppColors.richBlack.withOpacity(0.02), blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.richBlack)),
            Icon(icon, color: AppColors.richBlack),
          ],
        ),
      ),
    );
  }

  Widget _buildUserDetails() {
    bool isGuest = _emailController.text.isEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isGuest) ...[
            Container(
              margin: EdgeInsets.only(bottom: 16),
              padding: EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primaryGreen.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Already a member? Log in to auto-fill details & unlock VIP rates.',
                      style: GoogleFonts.outfit(fontSize: 12, color: AppColors.primaryGreen, fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => LoginScreen()));
                      _loadUserData();
                    },
                    child: Text('Log In', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
                  ),
                ],
              ),
            ),
          ],
          _buildTextField(_nameController, 'Full Name', Icons.person_outline),
          SizedBox(height: 16),
          _buildTextField(_phoneController, 'Phone Number', Icons.phone_outlined, isPhone: true),
          SizedBox(height: 16),
          _buildTextField(_emailController, 'Email Address', Icons.email_outlined, isEmail: true),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isPhone = false, bool isEmail = false}) {
    return TextField(
      controller: controller,
      keyboardType: isPhone ? TextInputType.phone : (isEmail ? TextInputType.emailAddress : TextInputType.text),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey.shade600),
        filled: true,
        fillColor: AppColors.softWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.richBlack, width: 2),
        ),
      ),
    );
  }

  Widget _buildConfirmation() {
    if (_selectedService == null) return Container();
    
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFDDF7E8),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: AppColors.richBlack.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                CustomPaddleIcon( color: AppColors.softWhite, size: 28),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Selected Service', style: TextStyle(color: AppColors.softWhite.withOpacity(0.70), fontSize: 11)),
                      Text(_selectedService!.name, style: TextStyle(color: AppColors.softWhite, fontSize: 17, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              children: [
                if (_customerLoyalty != null) ...[
                  LoyaltyStampCardWidget(
                    stampCount: _customerLoyalty!.stampCount,
                    milestoneTarget: _loyaltySettings?.milestoneTarget ?? 10,
                    courtOwnerName: _selectedService?.name ?? 'Court Loyalty Program',
                    isMember: _customerLoyalty!.isMember,
                  ),
                  SizedBox(height: 16),
                ],
                _buildSummaryRow(Icons.calendar_today, 'Date', _selectedDate != null ? '${_selectedDate!.toLocal()}'.split(' ')[0] : '-'),
                Divider(height: 24, color: Colors.green.shade100),
                _buildSummaryRow(Icons.access_time, 'Times', _selectedTimes.isNotEmpty ? _selectedTimes.join(', ') : '-'),
                Divider(height: 24, color: Colors.green.shade100),
                _buildSummaryRow(Icons.person, 'Customer', _nameController.text.isEmpty ? '-' : _nameController.text),
                if (_customerLoyalty?.isMember == true && _loyaltySettings != null) ...[
                  Divider(height: 24, color: Colors.green.shade100),
                  _buildSummaryRow(
                    Icons.stars, 
                    'Member Discount', 
                    _loyaltySettings!.memberDiscountType == 'PERCENTAGE' 
                        ? '${_loyaltySettings!.memberDiscountValue.toInt()}% OFF (Applied)' 
                        : 'Member Price Applied'
                  ),
                ],
                Divider(height: 24, color: Colors.green.shade100),
                _buildSummaryRow('P', 'Subtotal', _getTotalAmount()),
                Divider(height: 24, color: Colors.green.shade100),
                _buildSummaryRow(Icons.receipt, 'Service Charge', 'PHP ${_getServiceFee().toStringAsFixed(2)}'),
                Divider(height: 24, color: Colors.green.shade100),
                _buildSummaryRow('P', 'Total Due', _getTotalDue()),
                SizedBox(height: 24),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.softWhite.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: AppColors.primaryGreen, size: 20),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Refund & Cancellation Policy', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen, fontSize: 13)),
                            SizedBox(height: 8),
                            Text('Cancellations made at least 24 hours in advance will receive a full refund. Cancellations made less than 24 hours before the booking time are non-refundable.', style: TextStyle(color: AppColors.primaryGreen, fontSize: 12, height: 1.4)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  double _getServiceFee() {
    int hours = _selectedTimes.length;
    if (hours <= 0) hours = 1;
    int blocks = (hours / 5.0).ceil();
    return blocks * 15.0;
  }

  String _getTotalAmount() {
    double total = 0.0;
    for (var time in _selectedTimes) {
      String priceStr = _getPriceForTime(time).replaceAll(RegExp(r'[^0-9.]'), '');
      double price = double.tryParse(priceStr) ?? 0.0;
      if (_customerLoyalty?.isMember == true && _loyaltySettings != null) {
        price = _loyaltySettings!.calculateMemberPrice(price);
      }
      total += price;
    }
    
    // Check if 10th transaction free milestone reached
    if (_customerLoyalty != null && _customerLoyalty!.stampCount >= 9 && (_loyaltySettings?.freeRewardEnabled ?? true)) {
      return 'PHP 0.00 (Free 10th Reward!)';
    }

    return total > 0 ? 'PHP ${total.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '')}' : '-';
  }

  String _getTotalDue() {
    // If 10th transaction is free, total due is $0.00
    if (_customerLoyalty != null && _customerLoyalty!.stampCount >= 9 && (_loyaltySettings?.freeRewardEnabled ?? true)) {
      return 'PHP 0.00 (FREE 10th Transaction 🎉)';
    }

    double total = 0.0;
    for (var time in _selectedTimes) {
      String priceStr = _getPriceForTime(time).replaceAll(RegExp(r'[^0-9.]'), '');
      double price = double.tryParse(priceStr) ?? 0.0;
      if (_customerLoyalty?.isMember == true && _loyaltySettings != null) {
        price = _loyaltySettings!.calculateMemberPrice(price);
      }
      total += price;
    }
    return 'PHP ${(total + _getServiceFee()).toStringAsFixed(2)}';
  }

  Widget _buildSummaryRow(dynamic iconOrText, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        iconOrText is IconData 
            ? Icon(iconOrText, color: AppColors.richBlack, size: 20)
            : Container(
                width: 20, 
                alignment: Alignment.center,
                child: Text(iconOrText.toString(), style: TextStyle(color: AppColors.richBlack, fontSize: 16, fontWeight: FontWeight.bold))
              ),
        SizedBox(width: 16),
        Text(label, style: TextStyle(color: AppColors.richBlack)),
        SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right, 
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.richBlack)
          ),
        ),
      ],
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied $label ($text) to clipboard!'),
        backgroundColor: AppColors.primaryGreen,
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _getPaymentDetail(String key, String fallback) {
    if (_selectedService?.ownerPayment != null) {
      final val = _selectedService!.ownerPayment![key];
      if (val != null && val.toString().isNotEmpty) {
        return val.toString();
      }
    }
    if (widget.venue != null) {
      if (widget.venue!['owner_payment'] != null && widget.venue!['owner_payment'][key] != null) {
        final val = widget.venue!['owner_payment'][key];
        if (val != null && val.toString().isNotEmpty) return val.toString();
      }
      if (widget.venue![key] != null && widget.venue![key].toString().isNotEmpty) {
        return widget.venue![key].toString();
      }
    }
    for (var service in _services) {
      if (service.ownerPayment != null && service.ownerPayment![key] != null) {
        final val = service.ownerPayment![key];
        if (val != null && val.toString().isNotEmpty) return val.toString();
      }
    }
    return fallback;
  }

  void _showFullQrCodeModal(String qrUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Payment QR Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.richBlack)),
                  IconButton(
                    icon: Icon(Icons.close, color: AppColors.richBlack),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              SizedBox(height: 8),
              InteractiveViewer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    qrUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(Icons.broken_image, size: 60, color: Colors.grey),
                  ),
                ),
              ),
              SizedBox(height: 12),
              Text('Pinch or drag to zoom QR Code', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentSelection() {
    final String qrUrl = _getPaymentDetail('qr_code_url', _getPaymentDetail('payment_qr_url', _getPaymentDetail('qr_code', '')));
    String gcashNum = _getPaymentDetail('gcash_number', _getPaymentDetail('gcash', ''));
    String mayaNum = _getPaymentDetail('paymaya_number', _getPaymentDetail('maya_number', _getPaymentDetail('paymaya', '')));
    String bankName = _getPaymentDetail('bank_name', _getPaymentDetail('bankName', ''));
    String bankAccountName = _getPaymentDetail('bank_account_name', _getPaymentDetail('bankAccountName', ''));
    String bankAccount = _getPaymentDetail('bank_account', _getPaymentDetail('bank_account_number', _getPaymentDetail('bankAccount', '')));
    final String customInstructions = _getPaymentDetail('payment_instructions', _getPaymentDetail('instructions', ''));

    // Fallbacks if empty
    if (gcashNum.isEmpty && widget.venue != null) {
      gcashNum = widget.venue!['gcash_number']?.toString() ?? widget.venue!['gcash']?.toString() ?? '';
    }
    if (gcashNum.isEmpty) {
      gcashNum = '09177720346';
    }

    if (bankAccount.isEmpty && widget.venue != null) {
      bankAccount = widget.venue!['bank_account']?.toString() ?? '';
    }
    if (bankAccountName.isNotEmpty && bankName.isEmpty) {
      if (bankAccountName.toUpperCase() == 'BPI' || bankAccountName.toUpperCase() == 'GCASH' || bankAccountName.toUpperCase() == 'MAYA') {
        bankName = bankAccountName;
      }
    }

    final bool hasCloudinaryQr = qrUrl.trim().isNotEmpty && qrUrl.startsWith('http');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 12),

        // Total Summary Card
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFDDF7E8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primaryGreen.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.payment_outlined, color: AppColors.primaryGreen, size: 20),
                  SizedBox(width: 8),
                  Text('Payment Summary', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen, fontSize: 15)),
                ],
              ),
              SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: TextStyle(color: AppColors.primaryGreen, height: 1.5, fontSize: 13, fontFamily: 'Poppins'),
                  children: [
                    TextSpan(text: 'Court Fee: ${_getTotalAmount()}\n'),
                    TextSpan(text: 'Service Charge: PHP ${_getServiceFee().toStringAsFixed(2)}\n'),
                    TextSpan(text: 'Total Amount to Pay: '),
                    TextSpan(text: '${_getTotalDue()}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.richBlack)),
                  ],
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 16),

        // Step-by-Step Payment Instructions Banner
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade800, size: 22),
                  SizedBox(width: 8),
                  Text('How to Pay (Step-by-Step)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue.shade900)),
                ],
              ),
              SizedBox(height: 10),
              Text(
                '1. Open your GCash, Maya, or Online Banking App.\n'
                '2. Scan the Payment QR Code below OR copy the account number.\n'
                '3. Send the exact total amount due: ${_getTotalDue()}.\n'
                '4. Copy your Payment Reference No. from your app and paste it below.',
                style: TextStyle(fontSize: 12.5, color: Colors.blue.shade900, height: 1.5),
              ),
              if (customInstructions.isNotEmpty) ...[
                Divider(height: 20, color: Colors.blue.shade200),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.speaker_notes, color: Colors.amber.shade900, size: 18),
                    SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Owner Payment Instructions:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.amber.shade900)),
                          SizedBox(height: 2),
                          Text(customInstructions, style: TextStyle(fontSize: 12, color: Colors.amber.shade900, height: 1.3)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        SizedBox(height: 20),

        // QR Code Display Card
        Center(
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.softWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [BoxShadow(color: AppColors.richBlack.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 4))],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code_2, color: AppColors.primaryGreen, size: 22),
                    SizedBox(width: 6),
                    Text(
                      hasCloudinaryQr ? 'Official Owner Payment QR Code' : 'Scan QR Code to Pay',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.richBlack),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    if (hasCloudinaryQr) {
                      _showFullQrCodeModal(qrUrl);
                    }
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: hasCloudinaryQr
                            ? Image.network(
                                qrUrl,
                                height: 220,
                                width: 220,
                                fit: BoxFit.contain,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    height: 220,
                                    width: 220,
                                    color: Colors.grey.shade100,
                                    child: Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
                                  );
                                },
                                errorBuilder: (_, __, ___) => Image.asset(
                                  'assets/qr-code.jpg',
                                  height: 200,
                                  width: 200,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Image.asset(
                                'assets/qr-code.jpg',
                                height: 200,
                                width: 200,
                                fit: BoxFit.cover,
                              ),
                      ),
                      if (hasCloudinaryQr)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.zoom_in, color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text('Tap to expand', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        SizedBox(height: 20),

        // Available Payment Options Header
        Text('Owner Payment Accounts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.richBlack)),
        SizedBox(height: 10),

        // GCash Container
        if (gcashNum.isNotEmpty) ...[
          Container(
            margin: EdgeInsets.only(bottom: 10),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.account_balance_wallet, color: Colors.blue.shade700, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('GCash Number', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue.shade900)),
                      Text(gcashNum, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  icon: Icon(Icons.copy, size: 14, color: Colors.blue.shade800),
                  label: Text('Copy', style: TextStyle(fontSize: 12, color: Colors.blue.shade800)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.blue.shade400),
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  onPressed: () => _copyToClipboard(gcashNum, 'GCash Number'),
                ),
              ],
            ),
          ),
        ],

        // Maya / PayMaya Container
        if (mayaNum.isNotEmpty) ...[
          Container(
            margin: EdgeInsets.only(bottom: 10),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.account_balance_wallet, color: Colors.green.shade700, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PayMaya / Maya', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green.shade900)),
                      Text(mayaNum, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green.shade900)),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  icon: Icon(Icons.copy, size: 14, color: Colors.green.shade800),
                  label: Text('Copy', style: TextStyle(fontSize: 12, color: Colors.green.shade800)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.green.shade400),
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  onPressed: () => _copyToClipboard(mayaNum, 'PayMaya Number'),
                ),
              ],
            ),
          ),
        ],

        // Bank Transfer Container
        if (bankAccount.isNotEmpty || bankName.isNotEmpty || bankAccountName.isNotEmpty) ...[
          Container(
            margin: EdgeInsets.only(bottom: 10),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.account_balance, color: Colors.purple.shade700, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bankName.isNotEmpty ? 'Bank Transfer ($bankName)' : (bankAccountName.isNotEmpty ? 'Bank Transfer ($bankAccountName)' : 'Bank Transfer'),
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.purple.shade900),
                      ),
                      if (bankAccountName.isNotEmpty && bankName.isNotEmpty && bankAccountName != bankName)
                        Text('Account Name: $bankAccountName', style: TextStyle(fontSize: 12, color: Colors.purple.shade900)),
                      if (bankAccount.isNotEmpty)
                        Text('Account No: $bankAccount', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.purple.shade900)),
                    ],
                  ),
                ),
                if (bankAccount.isNotEmpty)
                  OutlinedButton.icon(
                    icon: Icon(Icons.copy, size: 14, color: Colors.purple.shade800),
                    label: Text('Copy', style: TextStyle(fontSize: 12, color: Colors.purple.shade800)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.purple.shade400),
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    onPressed: () => _copyToClipboard(bankAccount, 'Bank Account Number'),
                  ),
              ],
            ),
          ),
        ],

        SizedBox(height: 16),

        TextFormField(
          controller: _referenceNumberController,
          decoration: InputDecoration(
            labelText: 'Payment Reference Number',
            hintText: 'Enter your GCash / Maya / Bank Ref No. after payment',
            prefixIcon: Icon(Icons.numbers, color: Colors.grey.shade600),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }
}




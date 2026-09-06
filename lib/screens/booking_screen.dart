import 'package:flutter_project/theme/app_colors.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../widgets/custom_paddle_icon.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../models/service_model.dart';
import '../services/api_service.dart';
import 'booking_confirmation_screen.dart';
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
  bool _isLoadingSlots = false;
  
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
    _loadServices();
    _loadUserData();
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
        return ServiceModel(
          id: c['id'] ?? (1000 + idx),
          name: c['name'] ?? 'Court ${idx + 1}',
          description: 'Court at ${widget.venue!['venueName'] ?? 'Venue'}',
          price: 'PHP ${c['price'] ?? widget.venue!['basePrice'] ?? '300'}',
          icon: '🎾',
          duration: '1H',
          category: 'pickle',
          isActive: true,
        );
      }).toList();

      if (venueCourts.isNotEmpty) {
        setState(() {
          _services = venueCourts;
          _selectedService = venueCourts.first;
          _selectedServiceIds = venueCourts.map((s) => s.id).toSet();
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
        } else if (_services.isNotEmpty) {
          _selectedService = _services.first;
          _selectedServiceIds = {_services.first.id};
        }
      });
      _fetchSlots();
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
    
    List<String> allBooked = [];
    final activeServices = _services.where((s) => _selectedServiceIds.contains(s.id)).toList();
    final fetchTargetServices = activeServices.isNotEmpty ? activeServices : [_services.first];

    for (var service in fetchTargetServices) {
      final result = await _apiService.fetchAvailableSlots(dateStr, service.name);
      final List<String> booked = (result['bookedSlots'] ?? []).map<String>((s) => s.toString()).toList();
      final List<String> blocked = (result['blockedSlots'] ?? []).map<String>((s) => s.toString()).toList();
      allBooked.addAll(booked);
      allBooked.addAll(blocked);
    }
    
    setState(() {
      _bookedSlots = allBooked.toSet().toList();
      // Remove selected times if booked
      _selectedTimes.removeWhere((rawTime) {
        final cleanTime = rawTime.contains(': ') ? rawTime.split(': ')[1] : rawTime;
        return _bookedSlots.contains(cleanTime);
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
              SnackBar(content: Text('Hold expired! Please hold your slots again.'), backgroundColor: Colors.orange),
            );
          }
        });
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Slots held! You have 5 minutes to complete your booking.'), backgroundColor: AppColors.primaryGreen),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sorry, one or more slots are already taken or held.'), backgroundColor: Colors.redAccent),
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
            totalPaid: (totalAmount > 0 ? totalAmount : 350.0) + 15.0,
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
    if (s.variablePrices != null && s.variablePrices!.isNotEmpty) {
      for (var vp in s.variablePrices!) {
        String? vpTime = vp['time']?.toString();
        String? vpHour = vp['hour']?.toString();
        
        if (vpTime != null && _normalizeTime(vpTime) == time) {
          final price = vp['price'];
          return price.toString().contains('PHP') ? price.toString() : 'PHP $price';
        } else if (vpHour != null && _normalizeTime(vpHour) == time) {
          final price = vp['price'];
          return price.toString().contains('PHP') ? price.toString() : 'PHP $price';
        }
      }
    }
    return s.price;
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

  List<String> _getDisplayTimeSlots() {
    if (_selectedService != null && _selectedService!.variablePrices != null && _selectedService!.variablePrices!.isNotEmpty) {
      List<String> definedSlots = [];
      for (var vp in _selectedService!.variablePrices!) {
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
    if (!skipChooseService) {
      if (_currentStep == 0 && _selectedService == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Select a service to continue')));
        return;
      }
      if (_currentStep == 1 && (_selectedDate == null || _selectedTimes.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Select date and at least one time')));
        return;
      }
      if (_currentStep == 1 && _holdToken == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please click "Lock in this time" below the time slots before proceeding.')));
        return;
      }
      if (_currentStep == 2 && (_nameController.text.isEmpty || _phoneController.text.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please fill your details')));
        return;
      }
      if (_currentStep == 3 && _referenceNumberController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please enter your reference number to continue')));
        return;
      }

      if (_currentStep < 4) {
        setState(() => _currentStep += 1);
      } else {
        _submitBooking();
      }
    } else {
      if (_currentStep == 0 && (_selectedDate == null || _selectedTimes.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Select date and at least one time')));
        return;
      }
      if (_currentStep == 0 && _holdToken == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please click "Lock in this time" below the time slots before proceeding.')));
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
  }

  void _handleStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool skipChooseService = widget.skipServiceSelection || widget.initialService != null || (widget.initialServiceName != null && widget.initialServiceName!.isNotEmpty);
    final int maxStep = skipChooseService ? 3 : 4;

    List<Step> steps = [];

    if (!skipChooseService) {
      steps.add(
        Step(
          title: Text('Choose Service', style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.richBlack)),
          subtitle: _currentStep == 0 
              ? Text('Select the court you want to book')
              : Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: _buildServiceSelection(),
                ),
          content: _currentStep == 0 ? _buildServiceSelection() : SizedBox.shrink(),
          isActive: _currentStep >= 0,
          state: _currentStep > 0 ? StepState.complete : StepState.indexed,
        ),
      );
    }

    steps.addAll([
      Step(
        title: Text('Date & Time', style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.richBlack)),
        content: _buildDateTimeSelection(),
        isActive: _currentStep >= (skipChooseService ? 0 : 1),
        state: _currentStep > (skipChooseService ? 0 : 1) ? StepState.complete : StepState.indexed,
      ),
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
        : ['Court', 'Date & Time', 'Your Details', 'Payment', 'Confirm'];

    return Scaffold(
      backgroundColor: AppColors.creamWhite,
      appBar: AppBar(
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
                                      Text('COURT SELECTED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.richBlack.withOpacity(0.54), letterSpacing: 0.5)),
                                      SizedBox(height: 2),
                                      Text(_selectedService?.name ?? widget.initialServiceName ?? 'Pickleball Court', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.richBlack)),
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
    );
  }


  Widget _buildServiceSelection() {
    return SizedBox(
      height: 64,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _services.length,
        itemBuilder: (context, index) {
          final service = _services[index];
          final isSelected = _selectedService?.id == service.id;
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedService = service;
                _selectedTimes.clear();
              });
              _fetchSlots();
            },
            child: Container(
              width: 100,
              margin: EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFDDF7E8) : AppColors.softWhite,
                borderRadius: BorderRadius.circular(12),
                border: isSelected ? null : Border.all(color: Colors.grey.shade300, width: 1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    service.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppColors.primaryGreen : AppColors.richBlack,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8),
                  Text(
                    service.price,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppColors.primaryGreen : AppColors.richBlack,
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

  Widget _buildDateTimeSelection() {
    final now = DateTime.now();
    final List<DateTime> dates = List.generate(90, (i) => now.add(Duration(days: i)));
    final List<String> fullMonths = [
      'January', 'February', 'March', 'April', 'May', 'June', 
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final List<String> shortMonths = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];
    final List<String> weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8.0, right: 16.0, bottom: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Select Date', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.richBlack)),
                if (_selectedDate != null)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text(
                      '${fullMonths[_selectedDate!.month - 1]} ${_selectedDate!.year}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.softWhite, letterSpacing: 0.5),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 72,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: dates.length,
              itemBuilder: (context, index) {
                final date = dates[index];
                final isSelected = _selectedDate != null && 
                    date.year == _selectedDate!.year && 
                    date.month == _selectedDate!.month && 
                    date.day == _selectedDate!.day;
                    
                final weekdayStr = weekdays[date.weekday - 1];
                final monthStr = shortMonths[date.month - 1];
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDate = date;
                      _selectedTimes.clear();
                    });
                    _fetchSlots();
                  },
                  child: Container(
                    width: 65,
                    margin: EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primaryGreen : AppColors.softWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected ? null : Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          weekdayStr,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? AppColors.softWhite : Colors.grey.shade600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? AppColors.softWhite : AppColors.richBlack,
                            height: 1.1,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          monthStr,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? AppColors.softWhite : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 24),
          if (_services.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 8.0, bottom: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Select Court(s)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.richBlack)),
                  Text('Tap to multi-select courts', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _services.length,
                itemBuilder: (context, index) {
                  final service = _services[index];
                  final isSelected = _selectedServiceIds.contains(service.id);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          if (_selectedServiceIds.length > 1) {
                            _selectedServiceIds.remove(service.id);
                          }
                        } else {
                          _selectedServiceIds.add(service.id);
                        }
                        _selectedService = _services.firstWhere((s) => _selectedServiceIds.contains(s.id));
                      });
                      _fetchSlots();
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      margin: EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primaryGreen : AppColors.softWhite,
                        borderRadius: BorderRadius.circular(20),
                        border: isSelected ? null : Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          if (isSelected) ...[
                            Icon(Icons.check_circle, size: 15, color: Colors.white),
                            SizedBox(width: 4),
                          ],
                          Text(
                            service.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : AppColors.richBlack,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 20),
          ],
          if (_selectedDate != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8.0, bottom: 16.0),
                  child: Text('Select Time(s)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.richBlack)),
                ),
                _isLoadingSlots 
                  ? Padding(padding: const EdgeInsets.all(24.0), child: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.richBlack))))
                  : Column(
                      children: (_services.where((s) => _selectedServiceIds.contains(s.id)).isEmpty
                              ? (_services.isNotEmpty ? [_services.first] : <ServiceModel>[])
                              : _services.where((s) => _selectedServiceIds.contains(s.id))).map((court) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.primaryGreen.withOpacity(0.3)),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: Offset(0, 3)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Court Header Banner
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGreen,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        CustomPaddleIcon(color: Colors.white, size: 16),
                                        const SizedBox(width: 8),
                                        Text(
                                          court.name,
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      court.price,
                                      style: TextStyle(color: AppColors.accentLime, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Available Timeslots for ${court.name}:',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                              ),
                              const SizedBox(height: 10),

                              // Timeslot Grid for this court
                              GridView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  childAspectRatio: 2.0,
                                ),
                                itemCount: _getDisplayTimeSlots().length,
                                itemBuilder: (context, index) {
                                  final time = _getDisplayTimeSlots()[index];
                                  final slotKey = '${court.name}: $time';
                                  final isSelected = _selectedTimes.contains(slotKey) || (_selectedServiceIds.length == 1 && _selectedTimes.contains(time));
                                  final isBooked = _bookedSlots.contains(time);
                                  
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
                                      return '$endH$ampm';
                                    }
                                    return t;
                                  }
                                  
                                  final String startStr = time.replaceFirst(':00', '').replaceAll(' ', '').replaceFirst(RegExp(r'^0'), '');
                                  final String displayTime = '$startStr-${getEndStr(time)}';

                                  return InkWell(
                                    onTap: isDisabled ? null : () {
                                      setState(() {
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
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ],
          ),
          
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
                      child: Row(
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
                    ),
                ],
              ),
            ),
            
          SizedBox(height: 24),
          // Open Play Toggle
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.softWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
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
                          Text('Host as Open Play', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          SizedBox(height: 8),
                          Text('Allow other players to join and buy spots in your session.', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isOpenPlay,
                      onChanged: (val) {
                        setState(() { 
                          _isOpenPlay = val; 
                          if (val) _isOpenChallenge = false;
                        });
                      },
                      activeColor: AppColors.accentLime,
                    ),
                  ],
                ),
                if (_isOpenPlay) ...[
                  SizedBox(height: 16),
                  Text('Play Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.richBlack)),
                  SizedBox(height: 8),
                  Row(
                    children: ['SINGLES', 'DOUBLES', 'SOCIAL'].map((type) {
                      final isSelected = _openPlayType == type;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: type == 'SOCIAL' ? 0 : 8.0),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _openPlayType = type;
                                if (type == 'SINGLES') _openPlayMaxPlayersController.text = '2';
                                else if (type == 'DOUBLES') _openPlayMaxPlayersController.text = '4';
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primaryGreen : AppColors.softWhite,
                                border: Border.all(color: isSelected ? AppColors.primaryGreen : Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                type,
                                style: TextStyle(
                                  color: isSelected ? AppColors.softWhite : AppColors.richBlack,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
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
                          controller: _openPlayMaxPlayersController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Max Players',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _openPlayPriceController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Price per Spot',
                            prefixText: 'P ',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _openPlayInstructionsController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Instructions for Joiners',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _openPlayPaymentDetailsController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Payment Details (e.g. GCash number, Bank Info)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Open Challenge Toggle
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.softWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
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
                          Text('Post an Open Challenge', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          SizedBox(height: 8),
                          Text('Look for opponents. Review and accept challengers.', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isOpenChallenge,
                      onChanged: (val) {
                        setState(() { 
                          _isOpenChallenge = val; 
                          if (val) _isOpenPlay = false;
                        });
                      },
                      activeColor: AppColors.primaryGreen,
                    ),
                  ],
                ),
                if (_isOpenChallenge) ...[
                  SizedBox(height: 16),
                  Text('Challenge Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.richBlack)),
                  SizedBox(height: 8),
                  Row(
                    children: ['singles', 'doubles'].map((type) {
                      final isSelected = _challengeType == type;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: type == 'singles' ? 8.0 : 0.0),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _challengeType = type;
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primaryGreen : AppColors.softWhite,
                                border: Border.all(color: isSelected ? AppColors.primaryGreen : Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                type.toUpperCase(),
                                style: TextStyle(
                                  color: isSelected ? AppColors.softWhite : AppColors.richBlack,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (_challengeType == 'doubles') ...[
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _hostTandemNameController,
                      decoration: InputDecoration(
                        labelText: 'Tandem Name / Partner Name',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                  ],
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _challengeDescriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Challenge Description / Details',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Venue Overview (About, Policies, Q&A, Facilities)
          _buildVenueInformationSection(),
        ],
      ),
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
    List<dynamic> rawFacilities = v?['facilities'] ?? _selectedService?.facilities ?? [];
    List<String> facilities = rawFacilities.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
    if (facilities.isEmpty) {
      facilities = ['Covered Court', 'Restrooms', 'Water Station', 'Parking', 'Equipment Rental'];
    }

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
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: facilities.map((f) => Chip(
                          avatar: Icon(Icons.check, size: 14, color: AppColors.primaryGreen),
                          label: Text(f, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          backgroundColor: AppColors.creamWhite,
                          side: BorderSide(color: Colors.grey.shade300),
                        )).toList(),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        children: [
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
                _buildSummaryRow(Icons.calendar_today, 'Date', _selectedDate != null ? '${_selectedDate!.toLocal()}'.split(' ')[0] : '-'),
                Divider(height: 24, color: Colors.green.shade100),
                _buildSummaryRow(Icons.access_time, 'Times', _selectedTimes.isNotEmpty ? _selectedTimes.join(', ') : '-'),
                Divider(height: 24, color: Colors.green.shade100),
                _buildSummaryRow(Icons.person, 'Customer', _nameController.text.isEmpty ? '-' : _nameController.text),
                Divider(height: 24, color: Colors.green.shade100),
                _buildSummaryRow('P', 'Subtotal', _getTotalAmount()),
                Divider(height: 24, color: Colors.green.shade100),
                _buildSummaryRow(Icons.receipt, 'Service Charge', 'PHP 15.00'),
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

  String _getTotalAmount() {
    double total = 0.0;
    for (var time in _selectedTimes) {
      String priceStr = _getPriceForTime(time).replaceAll(RegExp(r'[^0-9.]'), '');
      total += double.tryParse(priceStr) ?? 0.0;
    }
    return total > 0 ? 'PHP ${total.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '')}' : '-';
  }

  String _getTotalDue() {
    double total = 0.0;
    for (var time in _selectedTimes) {
      String priceStr = _getPriceForTime(time).replaceAll(RegExp(r'[^0-9.]'), '');
      total += double.tryParse(priceStr) ?? 0.0;
    }
    return 'PHP ${(total + 15.00).toStringAsFixed(2)}';
  }

  Widget _buildSummaryRow(dynamic iconOrText, String label, String value) {
    return Row(
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
        Spacer(),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.richBlack)),
      ],
    );
  }

  String _getPaymentDetail(String key, String fallback) {
    if (_selectedService?.ownerPayment != null) {
      final val = _selectedService!.ownerPayment![key];
      if (val != null && val.toString().isNotEmpty) {
        return val.toString();
      }
    }
    return fallback;
  }

  Widget _buildPaymentSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'Please scan the QR code below to pay. Your booking will only be confirmed once payment is verified.',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
        ),
        SizedBox(height: 16),
        Center(
          child: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.softWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [BoxShadow(color: AppColors.richBlack.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 4))],
            ),
            child: InkWell(
              onTap: () {
                downloadImage('assets/qr-code.PNG');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Downloading QR Code...'), duration: Duration(seconds: 2))
                );
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/qr-code.PNG',
                      height: 200,
                      fit: BoxFit.contain,
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.richBlack.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.download, color: AppColors.softWhite, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFDDF7E8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.primaryGreen, size: 20),
                  SizedBox(width: 8),
                  Text('Payment Instructions', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen, fontSize: 14)),
                ],
              ),
              SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: TextStyle(color: AppColors.primaryGreen, height: 1.5, fontSize: 13, fontFamily: 'Poppins'),
                  children: [
                    TextSpan(text: 'Court Fee: ${_getTotalAmount()}\n'),
                    TextSpan(text: 'Service Charge: PHP 15.00\n'),
                    TextSpan(text: 'Total Amount to Pay: '),
                    TextSpan(text: '${_getTotalDue()}\n\n', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    TextSpan(text: 'Please send the payment to any of the following:\n\n'),
                    TextSpan(text: 'GCash: ${_getPaymentDetail('gcash_number', '09123456789')}\n'),
                    TextSpan(text: 'Maya: ${_getPaymentDetail('paymaya_number', '09123456789')}\n'),
                    TextSpan(text: 'Bank: ${_getPaymentDetail('bank_account', 'BDO - 1234567890')}\n'),
                    TextSpan(text: 'Account Name: ${_getPaymentDetail('bank_account_name', 'Pickle Booking')}'),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        TextFormField(
          controller: _referenceNumberController,
          decoration: InputDecoration(
            labelText: 'Reference Number',
            prefixIcon: Icon(Icons.numbers, color: Colors.grey.shade600),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }
}




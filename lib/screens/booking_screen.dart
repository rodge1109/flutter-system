import 'package:flutter_project/theme/app_colors.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
import 'registration_screen.dart';
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
  int? _currentBookingLogId;
  
  ServiceModel? _selectedService;
  Set<int> _selectedServiceIds = {};
  DateTime? _selectedDate;
  List<String> _selectedTimes = [];
  List<String> _bookedSlots = [];
  Map<String, List<String>> _courtBookedSlots = {};
  Map<String, List<String>> _courtHeldSlots = {};
  bool _isLoadingSlots = false;
  String _selectedCategory = 'All';
  Set<int> _expandedCourtIds = {};
  bool _copiedVenueLink = false;
  
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
  XFile? _paymentReceiptFile;
  Uint8List? _paymentReceiptBytes;
  bool _isUploadingReceipt = false;

  bool _isGuest = true;
  String _captchaCode = '';
  int _captchaSeed = 42;
  final _captchaController = TextEditingController();
  String? _captchaError;

  void _generateCaptchaCode() {
    const chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    final rand = math.Random();
    final code = List.generate(5, (_) => chars[rand.nextInt(chars.length)]).join();
    setState(() {
      _captchaCode = code;
      _captchaSeed = rand.nextInt(10000);
      _captchaController.clear();
      _captchaError = null;
    });
  }

  Future<void> _pickReceiptImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _paymentReceiptFile = picked;
          _paymentReceiptBytes = bytes;
        });
      }
    } catch (e) {
      debugPrint('Error picking receipt image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to select receipt image: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showReceiptSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Upload Payment Receipt (JPG / PNG)',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.richBlack,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Attach a clear screenshot of your GCash, Maya, or Bank transfer receipt.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: AppColors.primaryGreen),
                ),
                title: const Text('Choose from Photo Gallery / Files', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 14)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickReceiptImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: AppColors.primaryGreen),
                ),
                title: const Text('Take a Photo with Camera', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 14)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickReceiptImage(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _holdToken;
  final Set<String> _activeHoldTokens = {};
  final Map<String, String> _courtHoldTokens = {};
  Future<void>? _pendingReleaseFuture;
  Timer? _holdTimer;
  int _holdSecondsRemaining = 0;
  final ScrollController _stepScrollController = ScrollController();

  CustomerModel? _customerLoyalty;
  LoyaltySettingsModel? _loyaltySettings;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_stepScrollController.hasClients) {
        _stepScrollController.animateTo(
          _stepScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

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
    _generateCaptchaCode();
    _loadServices();
    _loadUserData();
  }

  Future<void> _checkLoyaltyStatus() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      if (mounted) {
        setState(() {
          _customerLoyalty = null;
          _loyaltySettings = null;
        });
      }
      return;
    }

    // Immediately reset loyalty state to prevent stale state leak during async fetching
    if (mounted) {
      setState(() {
        _customerLoyalty = null;
      });
    }

    String ownerEmail = _selectedService?.ownerEmail ?? '';
    if (ownerEmail.isEmpty && _selectedService?.ownerPayment != null) {
      ownerEmail = _selectedService!.ownerPayment!['owner_email']?.toString() ??
                   _selectedService!.ownerPayment!['ownerEmail']?.toString() ?? '';
    }
    if (ownerEmail.isEmpty && widget.venue != null) {
      ownerEmail = widget.venue!['owner_email']?.toString() ??
                   widget.venue!['ownerEmail']?.toString() ??
                   widget.venue!['email']?.toString() ?? '';
    }
    if (ownerEmail.isEmpty && _services.isNotEmpty) {
      for (var s in _services) {
        if (s.ownerEmail.isNotEmpty) {
          ownerEmail = s.ownerEmail;
          break;
        }
        if (s.ownerPayment?['owner_email']?.toString().isNotEmpty == true) {
          ownerEmail = s.ownerPayment!['owner_email'].toString();
          break;
        }
      }
    }

    if (ownerEmail.isEmpty && _selectedService != null) {
      ownerEmail = await _apiService.getOwnerEmailByCourt(_selectedService!.name);
    }
    if (ownerEmail.isEmpty && widget.initialServiceName != null && widget.initialServiceName!.isNotEmpty) {
      ownerEmail = await _apiService.getOwnerEmailByCourt(widget.initialServiceName!);
    }

    CustomerModel? loyalty;
    if (ownerEmail.isNotEmpty) {
      loyalty = await _apiService.fetchCustomerLoyaltyStatus(email, ownerEmail);
    } else {
      final allLoyalty = await _apiService.fetchAllCustomerLoyalty(email);
      if (allLoyalty.isNotEmpty) {
        loyalty = allLoyalty.first;
        ownerEmail = loyalty.ownerEmail;
      }
    }

    LoyaltySettingsModel? settings;
    if (ownerEmail.isNotEmpty) {
      settings = await _apiService.fetchLoyaltySettings(ownerEmail);
    }

    if (mounted) {
      if (_emailController.text.trim() == email) {
        setState(() {
          _customerLoyalty = loyalty;
          _loyaltySettings = settings;
        });
      }
    }
  }

  bool _isLoggedIn = false;

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    if (userStr != null && userStr.isNotEmpty && userStr != 'null') {
      try {
        final userObj = json.decode(userStr);
        if (mounted) {
          setState(() {
            _isLoggedIn = true;
            _nameController.text = userObj['full_name'] ?? userObj['fullName'] ?? '';
            _emailController.text = userObj['email'] ?? '';
            _phoneController.text = userObj['phone_number'] ?? userObj['phoneNumber'] ?? userObj['phone'] ?? '';
          });
        }
        _checkLoyaltyStatus();
      } catch (e) {
        debugPrint('Error loading user data: $e');
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
        });
      }
    }
    
    // Load Open Play defaults
    if (mounted) {
      setState(() {
        _openPlayInstructionsController.text = prefs.getString('open_play_instructions_default') ?? '';
        _openPlayPaymentDetailsController.text = prefs.getString('open_play_payment_details_default') ?? '';
      });
    }
  }

  Future<bool> _ensureUserLoggedIn({bool forceDialog = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    if (userStr != null && userStr.isNotEmpty && userStr != 'null') {
      if (mounted) {
        setState(() {
          _isLoggedIn = true;
          _isGuest = false;
        });
      }
      return true;
    }

    if (mounted) {
      setState(() {
        _isGuest = true;
        _isLoggedIn = false;
      });
    }
    await _loadUserData();
    return true;
  }

  Future<void> _loadServices() async {
    if (widget.venue != null && widget.venue!['courts'] != null) {
      final List<dynamic> rawCourts = widget.venue!['courts'];
      List<ServiceModel> venueCourts = rawCourts.asMap().entries.map((entry) {
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

        List<String> courtFac = [];
        final rawF = c['facilities'] ?? c['amenities'] ?? widget.venue!['facilities'] ?? widget.venue!['amenities'];
        if (rawF != null) {
          if (rawF is List) {
            courtFac = rawF.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
          } else if (rawF is String && rawF.trim().isNotEmpty) {
            try {
              final decoded = json.decode(rawF);
              if (decoded is List) courtFac = decoded.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
            } catch (_) {
              if (rawF.contains(',')) {
                courtFac = rawF.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
              } else {
                courtFac = [rawF.trim()];
              }
            }
          }
        }

        Map<String, dynamic> cPayment = {};
        if (c['serviceObj'] is ServiceModel) {
          final sObj = c['serviceObj'] as ServiceModel;
          if (sObj.ownerPayment != null) {
            cPayment = Map<String, dynamic>.from(sObj.ownerPayment!);
          }
        }
        final rawOP = c['owner_payment'] ?? c['ownerPayment'] ?? widget.venue!['owner_payment'] ?? widget.venue!['ownerPayment'];
        if (rawOP is Map) {
          cPayment.addAll(Map<String, dynamic>.from(rawOP));
        } else if (rawOP is String && rawOP.trim().isNotEmpty) {
          try {
            final dec = json.decode(rawOP);
            if (dec is Map) cPayment.addAll(Map<String, dynamic>.from(dec));
          } catch (_) {}
        }
        if (cPayment['gcash_number'] == null || cPayment['gcash_number'].toString().trim().isEmpty) {
          final g = c['gcash_number'] ?? widget.venue!['gcash_number'] ?? widget.venue!['gcash'];
          if (g != null) cPayment['gcash_number'] = g;
        }
        if (cPayment['paymaya_number'] == null || cPayment['paymaya_number'].toString().trim().isEmpty) {
          final m = c['paymaya_number'] ?? widget.venue!['paymaya_number'] ?? widget.venue!['paymaya'];
          if (m != null) cPayment['paymaya_number'] = m;
        }
        final q = c['qr_code_url'] ?? c['payment_qr_url'] ?? widget.venue!['qr_code_url'] ?? widget.venue!['payment_qr_url'];
        if ((cPayment['qr_code_url'] == null || cPayment['qr_code_url'].toString().trim().isEmpty) && q != null) {
          cPayment['qr_code_url'] = q;
          cPayment['payment_qr_url'] = q;
        }

        String cOwner = (c['owner_email'] ?? c['ownerEmail'] ?? widget.venue!['owner_email'] ?? widget.venue!['ownerEmail'] ?? widget.venue!['email'] ?? '').toString();
        if (cOwner.isEmpty && c['serviceObj'] is ServiceModel) {
          cOwner = (c['serviceObj'] as ServiceModel).ownerEmail;
        }

        List<String> courtPhotos = [];
        final rawCp = c['photos'] ?? c['images'] ?? (c['serviceObj'] is ServiceModel ? (c['serviceObj'] as ServiceModel).photos : null) ?? widget.venue!['photos'] ?? widget.venue!['images'];
        if (rawCp != null) {
          if (rawCp is List) {
            courtPhotos = rawCp.map((e) => e.toString().trim()).where((e) => e.isNotEmpty && e.startsWith('http')).toList();
          } else if (rawCp is String && rawCp.trim().isNotEmpty) {
            try {
              final decoded = json.decode(rawCp);
              if (decoded is List) {
                courtPhotos = decoded.map((e) => e.toString().trim()).where((e) => e.isNotEmpty && e.startsWith('http')).toList();
              } else if (rawCp.startsWith('http')) {
                courtPhotos = [rawCp.trim()];
              }
            } catch (_) {
              if (rawCp.contains(',')) {
                courtPhotos = rawCp.split(',').map((e) => e.trim()).where((e) => e.startsWith('http')).toList();
              } else if (rawCp.startsWith('http')) {
                courtPhotos = [rawCp.trim()];
              }
            }
          }
        }

        return ServiceModel(
          id: courtId,
          name: c['name'] ?? 'Court ${idx + 1}',
          description: c['description'] ?? 'Court at ${widget.venue!['venueName'] ?? 'Venue'}',
          price: 'PHP ${c['price'] ?? widget.venue!['basePrice'] ?? '300'}',
          ownerEmail: cOwner,
          icon: c['icon'] ?? '🎾',
          duration: c['duration'] ?? '1H',
          category: 'pickle',
          isActive: true,
          photos: courtPhotos,
          images: courtPhotos,
          variablePrices: parsedVar,
          hourlyPrices: parsedVar,
          ownerPayment: cPayment.isNotEmpty ? cPayment : null,
          openTime: c['open_time'] ?? c['openTime'] ?? (widget.venue != null ? (widget.venue!['open_time'] ?? widget.venue!['openTime']) : null) ?? '08:00',
          closeTime: c['close_time'] ?? c['closeTime'] ?? (widget.venue != null ? (widget.venue!['close_time'] ?? widget.venue!['closeTime']) : null) ?? '23:59',
          latitude: c['latitude'] != null ? double.tryParse(c['latitude'].toString()) : null,
          longitude: c['longitude'] != null ? double.tryParse(c['longitude'].toString()) : null,
          aboutVenue: c['about_venue'] ?? c['aboutVenue'] ?? widget.venue!['aboutVenue'],
          bookingPolicy: c['booking_policy'] ?? c['bookingPolicy'] ?? widget.venue!['bookingPolicy'],
          faq: c['faq'] ?? widget.venue!['faq'],
          dayStartHour: parseHourValue(c['day_start_hour'] ?? c['dayStartHour'] ?? c['day_start'] ?? widget.venue!['day_start_hour'] ?? widget.venue!['dayStartHour'] ?? widget.venue!['day_start'], 6),
          nightStartHour: parseHourValue(c['night_start_hour'] ?? c['nightStartHour'] ?? c['night_start'] ?? widget.venue!['night_start_hour'] ?? widget.venue!['nightStartHour'] ?? widget.venue!['night_start'], 18),
          facilities: courtFac,
        );
      }).toList();

      bool hasAnyCourtPhotos = venueCourts.any((s) => s.photos.isNotEmpty || s.images.isNotEmpty);
      if (!hasAnyCourtPhotos) {
        try {
          final allS = await _apiService.fetchServices();
          venueCourts = venueCourts.map((vc) {
            final match = allS.firstWhere(
              (s) => s.id == vc.id || (s.name.trim().toLowerCase() == vc.name.trim().toLowerCase()), 
              orElse: () => vc,
            );
            if (match.photos.isNotEmpty || match.images.isNotEmpty) {
              final newPhotos = match.photos.isNotEmpty ? match.photos : match.images;
              return ServiceModel(
                id: vc.id,
                name: vc.name,
                description: vc.description,
                price: vc.price,
                ownerEmail: vc.ownerEmail,
                address: vc.address,
                facilities: vc.facilities,
                icon: vc.icon,
                duration: vc.duration,
                category: vc.category,
                isActive: vc.isActive,
                isVerified: vc.isVerified,
                photos: newPhotos,
                images: newPhotos,
                variablePrices: vc.variablePrices,
                ownerPayment: vc.ownerPayment,
                latitude: vc.latitude,
                longitude: vc.longitude,
                basePrice: vc.basePrice,
                hourlyPrices: vc.hourlyPrices,
                openTime: vc.openTime,
                closeTime: vc.closeTime,
                aboutVenue: vc.aboutVenue,
                bookingPolicy: vc.bookingPolicy,
                faq: vc.faq,
                dayStartHour: vc.dayStartHour,
                nightStartHour: vc.nightStartHour,
                venueName: vc.venueName,
                dayPrice: vc.dayPrice,
                nightPrice: vc.nightPrice,
              );
            }
            return vc;
          }).toList();
        } catch (_) {}
      }

      if (venueCourts.isNotEmpty) {
        ServiceModel selected = venueCourts.first;
        if (widget.initialServiceName != null && widget.initialServiceName!.isNotEmpty) {
          final target = widget.initialServiceName!.trim().toLowerCase();
          final matched = venueCourts.firstWhere(
            (s) => s.name.toLowerCase().trim() == target ||
                   s.name.toLowerCase().contains(target) ||
                   target.contains(s.name.toLowerCase()),
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
          _expandedCourtIds = venueCourts.length > 1 ? {} : {selected.id};
          _isLoading = false;
        });
        _fetchSlots();
        _checkLoyaltyStatus();
        return;
      }
    }

    try {
      final services = await _apiService.fetchServices();
      setState(() {
        _services = services.where((s) => s.isActive).toList();
        _isLoading = false;

        if (widget.initialService != null) {
          _selectedService = widget.initialService;
          _selectedServiceIds = {_selectedService!.id};
          _expandedCourtIds = _services.length > 1 ? {} : {_selectedService!.id};
        } else if (widget.initialServiceName != null && widget.initialServiceName!.isNotEmpty) {
          final matchName = widget.initialServiceName!.toLowerCase().trim();
          final venueMatches = _services.where((s) {
            final vName = (s.venueName ?? '').toLowerCase().trim();
            final sName = s.name.toLowerCase().trim();
            return (vName.isNotEmpty && (vName == matchName || vName.contains(matchName) || matchName.contains(vName))) ||
                   sName.contains(matchName) || matchName.contains(sName);
          }).toList();

          if (venueMatches.isNotEmpty) {
            _services = venueMatches;
            _selectedService = venueMatches.first;
            _selectedServiceIds = {venueMatches.first.id};
            _expandedCourtIds = venueMatches.length > 1 ? {} : {venueMatches.first.id};
          } else {
            _selectedService = _services.first;
            _selectedServiceIds = {_services.first.id};
            _expandedCourtIds = _services.length > 1 ? {} : {_services.first.id};
          }
        } else if (_services.isNotEmpty) {
          _selectedService = _services.first;
          _selectedServiceIds = {_services.first.id};
          _expandedCourtIds = _services.length > 1 ? {} : {_services.first.id};
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

  Future<void> _fetchSlots({bool preserveCurrentSelection = false}) async {
    if (_selectedDate == null || _services.isEmpty) return;
    setState(() => _isLoadingSlots = true);
    
    final dateStr = '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';
    
    Map<String, List<String>> courtBookings = {};
    Map<String, List<String>> courtHolds = {};
    
    for (var service in _services) {
      final result = await _apiService.fetchAvailableSlots(dateStr, service.name);
      final List<String> booked = (result['bookedSlots'] ?? []).map<String>((s) => s.toString()).toList();
      final List<String> held = (result['heldSlots'] ?? []).map<String>((s) => s.toString()).toList();
      final List<String> blocked = (result['blockedSlots'] ?? []).map<String>((s) => s.toString()).toList();
      courtBookings[service.name] = [...booked, ...blocked];
      courtHolds[service.name] = held;
    }

    if (preserveCurrentSelection && _selectedTimes.isNotEmpty) {
      for (final rawTime in _selectedTimes) {
        final court = _findCourtForSlot(rawTime);
        final courtName = court?.name ?? (_selectedService?.name ?? '');
        final cleanTime = _extractSlotTime(rawTime);
        if (courtName.isNotEmpty && courtBookings.containsKey(courtName)) {
          courtBookings[courtName]!.removeWhere(
            (bTime) => _normalizeTime(bTime) == _normalizeTime(cleanTime) || bTime.trim() == cleanTime.trim(),
          );
        }
        if (courtName.isNotEmpty && courtHolds.containsKey(courtName)) {
          courtHolds[courtName]!.removeWhere(
            (hTime) => _normalizeTime(hTime) == _normalizeTime(cleanTime) || hTime.trim() == cleanTime.trim(),
          );
        }
      }
    }
    
    setState(() {
      _courtBookedSlots = courtBookings;
      _courtHeldSlots = courtHolds;
      
      // We still update a unified _bookedSlots for legacy compatibility if needed
      List<String> allBooked = [];
      for (var list in courtBookings.values) {
        allBooked.addAll(list);
      }
      _bookedSlots = allBooked.toSet().toList();
      
      // Remove selected times if booked by ANOTHER user (do not strip slots currently held by this user or while releasing)
      if (!preserveCurrentSelection && _holdToken == null && _pendingReleaseFuture == null) {
        _selectedTimes.removeWhere((rawTime) {
          if (rawTime.contains(': ')) {
            final idx = rawTime.indexOf(': ');
            final courtName = rawTime.substring(0, idx).trim();
            final cleanTime = rawTime.substring(idx + 2).trim();
            final bookedList = _courtBookedSlots[courtName] ?? [];
            return bookedList.any((bTime) => _normalizeTime(bTime) == _normalizeTime(cleanTime) || bTime.trim() == cleanTime.trim());
          } else if (_selectedService != null) {
            final bookedList = _courtBookedSlots[_selectedService!.name] ?? [];
            return bookedList.any((bTime) => _normalizeTime(bTime) == _normalizeTime(rawTime) || bTime.trim() == rawTime.trim());
          }
          return false;
        });
      }
      _isLoadingSlots = false;
    });
  }

  Future<void> _releaseCurrentHold({bool refreshSlots = false}) async {
    _holdTimer?.cancel();
    final tokensToRelease = <String>{
      if (_holdToken != null && _holdToken!.trim().isNotEmpty) _holdToken!.trim(),
      ..._activeHoldTokens,
      ..._courtHoldTokens.values,
    };
    _activeHoldTokens.clear();
    _courtHoldTokens.clear();

    if (mounted) {
      setState(() {
        _holdToken = null;
        _holdSecondsRemaining = 0;
      });
    } else {
      _holdToken = null;
      _holdSecondsRemaining = 0;
    }

    if (tokensToRelease.isEmpty) return;

    final releaseWork = Future.wait(
      tokensToRelease.map((t) => _apiService.releaseHold(t)),
    );
    _pendingReleaseFuture = releaseWork;
    try {
      await releaseWork;
    } catch (_) {
    } finally {
      if (_pendingReleaseFuture == releaseWork) {
        _pendingReleaseFuture = null;
      }
    }

    if (refreshSlots && mounted) {
      await _fetchSlots(preserveCurrentSelection: true);
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    final tokensToRelease = <String>{
      if (_holdToken != null && _holdToken!.trim().isNotEmpty) _holdToken!.trim(),
      ..._activeHoldTokens,
    };
    for (final t in tokensToRelease) {
      _apiService.releaseHold(t);
    }
    _stepScrollController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _referenceNumberController.dispose();
    _captchaController.dispose();
    super.dispose();
  }

  void _holdSelectedSlots({bool autoAdvance = false}) async {
    if (_selectedDate == null || _selectedTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a date and time slot first'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    if (!_isLoggedIn && !_isGuest) {
      final loggedIn = await _ensureUserLoggedIn();
      if (!loggedIn) return;
    }

    setState(() => _isLoading = true);

    // Wait for any in-flight hold release (e.g. if user just clicked Back and immediately clicked Continue)
    if (_pendingReleaseFuture != null) {
      try {
        await _pendingReleaseFuture;
      } catch (_) {}
    }

    final dateStr = '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';
    
    // Group selected times by court/service name
    Map<String, List<String>> slotsByService = {};
    for (var rawTime in _selectedTimes) {
      final court = _findCourtForSlot(rawTime);
      final sName = court?.name ?? (_selectedService?.name ?? 'Court');
      final cleanTime = _extractSlotTime(rawTime);
      slotsByService.putIfAbsent(sName, () => []);
      slotsByService[sName]!.add(cleanTime);
    }

    String? lastHoldToken;
    bool holdFailed = false;
    final newlyHeldTokens = <String>[];
    final newlyHeldByCourt = <String, String>{};

    for (var entry in slotsByService.entries) {
      final sName = entry.key;
      final timesList = entry.value;

      final holdToken = await _apiService.holdSlots(
        dateStr: dateStr,
        times: timesList,
        serviceType: sName,
        email: _emailController.text,
        previousHoldToken: _courtHoldTokens[sName] ?? _holdToken,
      );

      if (holdToken != null) {
        lastHoldToken = holdToken;
        newlyHeldTokens.add(holdToken);
        newlyHeldByCourt[sName] = holdToken;
      } else {
        holdFailed = true;
        lastHoldToken = null;
        break;
      }
    }

    if (holdFailed && newlyHeldTokens.isNotEmpty) {
      for (final t in newlyHeldTokens) {
        await _apiService.releaseHold(t);
      }
    } else if (!holdFailed) {
      _activeHoldTokens
        ..clear()
        ..addAll(newlyHeldTokens);
      _courtHoldTokens
        ..clear()
        ..addAll(newlyHeldByCourt);
    }

    setState(() => _isLoading = false);

    if (!holdFailed && lastHoldToken != null) {
      setState(() {
        _holdToken = lastHoldToken;
        _holdSecondsRemaining = 300; // 5 minutes
        if (autoAdvance && _currentStep == 0) {
          _currentStep = 1;
        }
      });
      _scrollToBottom();
      _holdTimer?.cancel();
      _holdTimer = Timer.periodic(Duration(seconds: 1), (timer) {
        setState(() {
          if (_holdSecondsRemaining > 0) {
            _holdSecondsRemaining--;
          } else {
            _holdTimer?.cancel();
            _holdToken = null;
            _recordBookingLog('HOLD_EXPIRED', errorMsg: 'Slot hold expired after 5 minutes');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Hold expired! Please select and hold your slots again.'),
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
    } else {
      _holdToken = null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sorry, one or more selected slots are already booked or held by another renter. The list has been refreshed.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 180,
            left: 16,
            right: 16,
          ),
        ),
      );
      await _fetchSlots();
    }
  }

  Future<void> _recordBookingLog(String stage, {String? refNumber, String? errorMsg}) async {
    try {
      final distinctCourts = <String>{};
      for (var t in _selectedTimes) {
        final c = _findCourtForSlot(t);
        if (c != null && c.name.isNotEmpty) {
          distinctCourts.add(c.name);
        }
      }
      final String venueTitle = widget.venue?['venueName'] ?? widget.venue?['name'] ?? _selectedService?.venueName ?? '';
      final String courtNamesStr = distinctCourts.isNotEmpty 
          ? distinctCourts.join(", ") 
          : (_selectedService?.name ?? 'Court');

      final double totalAmount = _selectedTimes.fold(0.0, (sum, time) {
        return sum + _getSlotPriceValue(time);
      });
      double freeDiscount = 0.0;
      if (_customerLoyalty != null && _customerLoyalty!.stampCount >= 9 && (_loyaltySettings?.freeRewardEnabled ?? true)) {
        if (_selectedTimes.isNotEmpty) {
          freeDiscount = _getSlotPriceValue(_selectedTimes.first);
        } else {
          freeDiscount = 350.0;
        }
      }
      final double finalPaid = (totalAmount - freeDiscount).clamp(0.0, double.infinity) + _getServiceFee();

      final bookingDateStr = _selectedDate != null 
          ? '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}'
          : '';

      final logId = await _apiService.logBookingAttempt(
        logId: _currentBookingLogId,
        customerName: _nameController.text.trim(),
        customerEmail: _emailController.text.trim(),
        customerPhone: _phoneController.text.trim(),
        venueName: venueTitle,
        courtNames: courtNamesStr,
        bookingDate: bookingDateStr,
        timeSlots: _selectedTimes.join(', '),
        totalAmount: finalPaid,
        paymentMethod: _selectedPaymentMethod,
        referenceNumber: refNumber ?? (_referenceNumberController.text.trim().isNotEmpty ? _referenceNumberController.text.trim() : null),
        stage: stage,
        errorMessage: errorMsg,
        metadata: {
          'isOpenPlay': _isOpenPlay,
          'isOpenChallenge': _isOpenChallenge,
          'holdToken': _holdToken,
        },
      );

      if (logId != null) {
        _currentBookingLogId = logId;
      }
    } catch (e) {
      debugPrint('Silent booking log error: $e');
    }
  }

  void _submitBooking() async {
    if (_selectedDate == null || _selectedTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a date and time slot first'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!_isLoggedIn && !_isGuest) {
      final loggedIn = await _ensureUserLoggedIn();
      if (!loggedIn) return;
    }

    final fullName = _nameController.text.trim();
    if (fullName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (fullName.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Full name must be at least 3 characters'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    final String refText = _referenceNumberController.text.trim();
    if (refText.isEmpty || refText.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter all 4 digits of your payment reference number.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_paymentReceiptFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload your proof of payment receipt screenshot.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    _recordBookingLog('SUBMITTING', refNumber: refText);

    // 1. Upload receipt image to Cloudinary if attached
    String? uploadedReceiptUrl;
    if (_paymentReceiptFile != null) {
      try {
        uploadedReceiptUrl = await _apiService.uploadImageToCloudinary(_paymentReceiptFile!);
      } catch (e) {
        debugPrint('Error uploading payment receipt to Cloudinary: $e');
      }
    }

    String? finalProof;
    if (refText.isNotEmpty && uploadedReceiptUrl != null && uploadedReceiptUrl.isNotEmpty) {
      finalProof = 'REF: $refText | $uploadedReceiptUrl';
    } else if (uploadedReceiptUrl != null && uploadedReceiptUrl.isNotEmpty) {
      finalProof = uploadedReceiptUrl;
    } else if (refText.isNotEmpty) {
      finalProof = 'REF: $refText';
    }

    bool allSuccess = true;
    String? submitErrorMessage;
    String? lastBookingId;

    try {
      for (var rawTime in _selectedTimes) {
        final matchedService = _findCourtForSlot(rawTime) ?? _selectedService ?? ServiceModel(
          id: 999,
          name: 'Court',
          description: '',
          price: 'PHP 350',
          icon: '🎾',
          duration: '1H',
          category: 'pickle',
          isActive: true,
        );

        String sName = matchedService.name;
        String cleanTime = _extractSlotTime(rawTime);
        double slotAmount = _getSlotPriceValue(rawTime);
        double feePerSlot = _selectedTimes.isNotEmpty ? (_getServiceFee() / _selectedTimes.length) : 15.0;
        double slotTotalWithFee = slotAmount + feePerSlot;

        final appointmentData = {
          'serviceType': sName, 
          'specialistId': matchedService.id.toString(),
          'preferredDate': '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}',
          'preferredTime': cleanTime,
          'fullName': _nameController.text,
          'email': _emailController.text,
          'phoneNumber': _phoneController.text,
          'paymentMethod': _selectedPaymentMethod,
          'totalAmount': slotTotalWithFee,
          'proofOfPayment': finalProof,
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
          'holdToken': _courtHoldTokens[sName] ?? _holdToken,
        };

        final res = await _apiService.submitAppointmentWithResult(appointmentData);
        if (res == null || (res['success'] != true && res['appointment'] == null)) {
          allSuccess = false;
          submitErrorMessage = res?['message'] ?? 'Server failed to save appointment';
        } else if (res['appointment'] != null && res['appointment']['id'] != null) {
          lastBookingId = res['appointment']['id'].toString();
        }
      }
    } catch (e) {
      allSuccess = false;
      submitErrorMessage = e.toString();
    }

    setState(() {
      _isLoading = false;
    });

    if (allSuccess) {
      _holdTimer?.cancel();
      _holdToken = null;
      _holdSecondsRemaining = 0;
      _activeHoldTokens.clear();
      _courtHoldTokens.clear();

      if (_isOpenPlay) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('open_play_instructions_default', _openPlayInstructionsController.text);
        await prefs.setString('open_play_payment_details_default', _openPlayPaymentDetailsController.text);
      }

      _recordBookingLog('CONFIRMED', refNumber: _referenceNumberController.text.trim());

      final double totalAmount = _selectedTimes.fold(0.0, (sum, time) {
        return sum + _getSlotPriceValue(time);
      });

      double freeDiscount = 0.0;
      if (_customerLoyalty != null && _customerLoyalty!.stampCount >= 9 && (_loyaltySettings?.freeRewardEnabled ?? true)) {
        if (_selectedTimes.isNotEmpty) {
          freeDiscount = _getSlotPriceValue(_selectedTimes.first);
        } else {
          freeDiscount = 350.0;
        }
      }

      double finalPaid = (totalAmount - freeDiscount).clamp(0.0, double.infinity) + _getServiceFee();

      final distinctCourts = <String>{};
      for (var t in _selectedTimes) {
        final c = _findCourtForSlot(t);
        if (c != null && c.name.isNotEmpty) {
          distinctCourts.add(c.name);
        }
      }
      final String venueTitle = widget.venue?['venueName'] ?? widget.venue?['name'] ?? _selectedService?.venueName ?? '';
      final String courtName = distinctCourts.isNotEmpty 
          ? (distinctCourts.length == 1 
              ? distinctCourts.first 
              : (venueTitle.isNotEmpty ? '$venueTitle (${distinctCourts.join(" & ")})' : distinctCourts.join(" & ")))
          : (_selectedService?.name ?? 'Smash Zone Pickleball');
      final String courtNum = distinctCourts.isNotEmpty ? distinctCourts.join(", ") : courtName;
      final String courtAddress = _selectedService?.address.isNotEmpty == true 
          ? _selectedService!.address 
          : (_selectedService?.description.isNotEmpty == true ? _selectedService!.description : 'Cayang');
      final String venueLogo = _getVenueLogoUrl();
      final String? courtImage = (venueLogo.isNotEmpty && (venueLogo.startsWith('http') || venueLogo.startsWith('assets/')))
          ? venueLogo
          : (_selectedService?.icon.startsWith('http') == true 
              ? _selectedService!.icon 
              : ((widget.venue?['logo_url'] ?? widget.venue?['image'])?.toString().trim().isNotEmpty == true 
                  ? (widget.venue!['logo_url'] ?? widget.venue!['image']).toString().trim() 
                  : null));
      final DateTime date = _selectedDate ?? DateTime.now();
      final List<String> times = List.from(_selectedTimes);

      // Navigate to the beautiful BookingConfirmationScreen matching design screenshot
      final double courtFeeAmount = (totalAmount - freeDiscount).clamp(0.0, double.infinity);
      final double adminFeeAmount = _getServiceFee();
      final String? derivedRef = _holdToken != null && _holdToken!.isNotEmpty
          ? 'BK-${_holdToken!.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase().padRight(8, '0').substring(0, 8)}'
          : (lastBookingId != null && lastBookingId.isNotEmpty
              ? (lastBookingId.startsWith('BK-') || lastBookingId.startsWith('#PB-')
                  ? lastBookingId
                  : 'BK-${lastBookingId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase().padLeft(8, '0')}')
              : null);

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
            totalPaid: finalPaid,
            bookingId: lastBookingId,
            playerName: _nameController.text.trim(),
            customerEmail: _emailController.text.trim(),
            customerPhone: _phoneController.text.trim(),
            paymentMethod: _selectedPaymentMethod,
            courtFee: courtFeeAmount,
            processingFee: adminFeeAmount,
            bookingReference: derivedRef,
            bookingStatus: 'pending',
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
        _referenceNumberController.clear();
        _paymentReceiptFile = null;
        _paymentReceiptBytes = null;
        _currentBookingLogId = null;
      });

      if (mounted) {
        Navigator.pop(context, result);
      }
    } else {
      _recordBookingLog(
        'FAILED',
        refNumber: _referenceNumberController.text.trim(),
        errorMsg: submitErrorMessage ?? 'Some bookings failed to submit. Please try again.',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(submitErrorMessage != null && submitErrorMessage.isNotEmpty 
              ? 'Booking failed: $submitErrorMessage' 
              : 'Some bookings failed to submit. Please try again.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  ServiceModel? _findCourtForSlot(String rawTime) {
    String cName = '';
    int idx = rawTime.indexOf(': ');
    if (idx != -1) {
      cName = rawTime.substring(0, idx).trim();
    }
    if (cName.isNotEmpty) {
      final target = cName.toLowerCase().trim();
      for (var s in _services) {
        final sName = s.name.toLowerCase().trim();
        if (sName == target || sName.contains(target) || target.contains(sName)) {
          return s;
        }
      }
    }
    return _selectedService ?? (_services.isNotEmpty ? _services.first : null);
  }

  String _extractSlotTime(String rawTime) {
    int idx = rawTime.indexOf(': ');
    if (idx != -1) {
      return rawTime.substring(idx + 2).trim();
    }
    return rawTime.trim();
  }

  String _formatSlotRange(String rawTime) {
    final clean = _extractSlotTime(rawTime);
    final parts = clean.split(RegExp(r'[:\s]'));
    if (parts.length >= 3) {
      int h = int.tryParse(parts[0]) ?? 0;
      String ampm = parts[2].toUpperCase();
      int endH = h + 1;
      String endAmpm = ampm;
      if (endH == 12) endAmpm = ampm == 'AM' ? 'PM' : 'AM';
      if (endH > 12) endH -= 12;
      return '$clean - $endH:00 $endAmpm';
    }
    return clean;
  }

  String _extractSlotCourtName(String rawTime) {
    int idx = rawTime.indexOf(': ');
    if (idx != -1) {
      return rawTime.substring(0, idx).trim();
    }
    return _selectedService?.name ?? 'Court';
  }

  double _getSlotPriceValue(String rawTime) {
    final court = _findCourtForSlot(rawTime);
    final cleanTime = _extractSlotTime(rawTime);
    final priceStr = _getPriceForTime(cleanTime, service: court).replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(priceStr) ?? 350.0;
  }

  String _getPriceForTime(String timeStr, {ServiceModel? service}) {
    String time = timeStr.trim();
    ServiceModel? matchedService = service;

    if (matchedService == null && timeStr.contains(': ')) {
      int idx = timeStr.indexOf(': ');
      String cName = timeStr.substring(0, idx).trim();
      time = timeStr.substring(idx + 2).trim();
      final target = cName.toLowerCase().trim();
      for (var s in _services) {
        final sName = s.name.toLowerCase().trim();
        if (sName == target || sName.contains(target) || target.contains(sName)) {
          matchedService = s;
          break;
        }
      }
    } else if (timeStr.contains(':')) {
      final parts = timeStr.split(':');
      if (parts.length > 2) {
        String cName = parts[0].trim();
        time = parts.sublist(1).join(':').trim();
        if (matchedService == null) {
          final target = cName.toLowerCase().trim();
          for (var s in _services) {
            final sName = s.name.toLowerCase().trim();
            if (sName == target || sName.contains(target) || target.contains(sName)) {
              matchedService = s;
              break;
            }
          }
        }
      }
    }

    final s = matchedService ?? _selectedService ?? (_services.isNotEmpty ? _services.first : null);
    if (s == null) return '';

    int hourNum = _parseHourFromTimeString(time);
    int dayStart = s.dayStartHour ?? 6;
    int nightStart = s.nightStartHour ?? 18;
    bool isNight = false;
    if (nightStart > dayStart) {
      isNight = (hourNum >= nightStart || hourNum < dayStart);
    } else {
      isNight = (hourNum >= nightStart && hourNum < dayStart);
    }

    // Determine court day rate (e.g. 200 for Aminova, 300 for Red Goose)
    double courtDayRate = 200.0;
    if (s.dayPrice != null && s.dayPrice!.isNotEmpty) {
      double? p = double.tryParse(s.dayPrice!.replaceAll(RegExp(r'[^0-9.]'), ''));
      if (p != null && p > 0) courtDayRate = p;
    } else if (s.price.isNotEmpty) {
      double? p = double.tryParse(s.price.replaceAll(RegExp(r'[^0-9.]'), ''));
      if (p != null && p > 0) courtDayRate = p;
    }

    // Determine court night rate (e.g. 300 for Aminova, 350 for Red Goose)
    double courtNightRate = courtDayRate >= 300.0 ? 350.0 : 300.0;
    if (s.nightPrice != null && s.nightPrice!.isNotEmpty) {
      double? p = double.tryParse(s.nightPrice!.replaceAll(RegExp(r'[^0-9.]'), ''));
      if (p != null && p > 0) courtNightRate = p;
    } else if (s.basePrice != null && s.basePrice!.isNotEmpty) {
      double? bp = double.tryParse(s.basePrice!.replaceAll(RegExp(r'[^0-9.]'), ''));
      if (bp != null && bp > 0) courtNightRate = bp;
    }

    double courtPrice = isNight ? courtNightRate : courtDayRate;
    double basePrice = courtPrice;
    
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
        String? vpTime = vp['time']?.toString() ?? vp['slot']?.toString() ?? vp['time_slot']?.toString();
        String? vpHour = vp['hour']?.toString();
        int? vpHourInt = vp['hour'] != null ? parseHourValue(vp['hour'], -1) : (vpTime != null ? _parseHourFromTimeString(vpTime) : null);
        
        bool isMatched = (vpHourInt != null && vpHourInt >= 0 && vpHourInt == hourNum) ||
            (vpTime != null && _normalizeTime(vpTime) == targetNormalized) ||
            (vpHour != null && _normalizeTime(vpHour) == targetNormalized);
            
        if (isMatched) {
          int slotNightStart = vp['night_start_hour'] != null 
              ? parseHourValue(vp['night_start_hour'], nightStart) 
              : (vp['nightStartHour'] != null ? parseHourValue(vp['nightStartHour'], nightStart) : nightStart);
          
          bool slotIsNight = (slotNightStart > dayStart) 
              ? (hourNum >= slotNightStart || hourNum < dayStart) 
              : (hourNum >= slotNightStart && hourNum < dayStart);
          DateTime targetDate = _selectedDate ?? DateTime.now();
          bool isWeekday = targetDate.weekday >= DateTime.monday && targetDate.weekday <= DateTime.friday;
          bool isWeekend = targetDate.weekday == DateTime.saturday || targetDate.weekday == DateTime.sunday;

          bool isDiscActive = vp['isDiscountActive'] == true || 
              vp['is_discount_active'] == true || 
              vp['isDiscountActive'] == 'true' ||
              vp['is_discount_active'] == 'true' ||
              vp['isDiscountActive'] == 1 ||
              vp['is_discount_active'] == 1;

          final discPriceRaw = vp['discountPrice'] ?? vp['discount_price'] ?? vp['promoPrice'] ?? vp['promo_price'];
          final appTo = (vp['discountAppliesTo'] ?? vp['discount_applies_to'] ?? vp['discountDays'] ?? vp['discount_days'] ?? 'ALL').toString().toUpperCase();

          bool appliesToSelectedDate = true;
          if (appTo.contains('WEEKDAY')) {
            appliesToSelectedDate = isWeekday;
          } else if (appTo.contains('WEEKEND')) {
            appliesToSelectedDate = isWeekend;
          }

          double? selectedPrice;
          if (isDiscActive && appliesToSelectedDate) {
            if (discPriceRaw != null) {
              double? dp = double.tryParse(discPriceRaw.toString().replaceAll(RegExp(r'[^0-9.]'), ''));
              if (dp != null && dp > 0) selectedPrice = dp;
            }
            if (selectedPrice == null && vp['price'] != null) {
              double? p = double.tryParse(vp['price'].toString().replaceAll(RegExp(r'[^0-9.]'), ''));
              if (p != null && p > 0) selectedPrice = p;
            }
          } else {
            // Promo does NOT apply to selected date (e.g. Weekend when promo is Weekdays Only)
            final stdKey = vp['standardPrice'] ?? vp['standard_price'] ?? vp['standardRate'] ?? vp['standard_rate'];
            if (stdKey != null) {
              double? sp = double.tryParse(stdKey.toString().replaceAll(RegExp(r'[^0-9.]'), ''));
              if (sp != null && sp > 0) selectedPrice = sp;
            }
          }

          if (selectedPrice == null) {
            final priceKey = slotIsNight
                ? (vp['night_price'] ?? vp['nightPrice'] ?? vp['night_rate'] ?? vp['standardPrice'] ?? vp['price'] ?? vp['rate'])
                : (vp['day_price'] ?? vp['dayPrice'] ?? vp['day_rate'] ?? vp['standardPrice'] ?? vp['price'] ?? vp['rate']);
            if (priceKey != null) {
              double? p = double.tryParse(priceKey.toString().replaceAll(RegExp(r'[^0-9.]'), ''));
              if (p != null && p > 0) selectedPrice = p;
            }
          }

          if (selectedPrice != null && selectedPrice > 0) {
            basePrice = selectedPrice;
            found = true;
            break;
          }
        }
      }
      if (!found) {
        basePrice = courtPrice;
      }
    } else {
      basePrice = courtPrice;
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

  int _parseHourFromTimeString(String timeStr) {
    String time = timeStr.trim();
    if (time.contains('-')) time = time.split('-')[0].trim();
    if (time.contains('—')) time = time.split('—')[0].trim();

    String clean = time.toUpperCase();
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
    if (clean.contains('-')) clean = clean.split('-')[0].trim();
    if (clean.contains('—')) clean = clean.split('—')[0].trim();

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
    List<String> slots = [];

    if (s != null && s.variablePrices != null && s.variablePrices!.isNotEmpty) {
      List<String> definedSlots = [];
      for (var vp in s.variablePrices!) {
        if (vp is Map && vp['time'] != null && vp['time'].toString().isNotEmpty) {
          definedSlots.add(_normalizeTime(vp['time'].toString()));
        } else if (vp is Map && vp['hour'] != null && vp['hour'].toString().isNotEmpty) {
          definedSlots.add(_normalizeTime(vp['hour'].toString()));
        }
      }
      if (definedSlots.isNotEmpty) {
        slots = definedSlots;
      }
    }

    if (slots.isEmpty) {
      slots = List.from(_allTimeSlots);
    }

    // Filter time slots according to court operating hours (openTime & closeTime)
    String? courtOpen = s?.openTime ?? widget.venue?['open_time'] ?? widget.venue?['openTime'] ?? '08:00';
    String? courtClose = s?.closeTime ?? widget.venue?['close_time'] ?? widget.venue?['closeTime'] ?? '23:59';
    
    int openHour = parseHourValue(courtOpen, 8);
    int closeHour = parseHourValue(courtClose, 24);
    if (courtClose != null && courtClose.toString().contains(':')) {
      final parts = courtClose.toString().split(':');
      if (parts.length >= 2) {
        int min = int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        if (min > 0 && closeHour < 24) closeHour += 1;
      }
    }
    if (closeHour == 0) closeHour = 24;

    slots = slots.where((t) {
      int h = _allTimeSlots.indexOf(t);
      if (h == -1) {
        h = parseHourValue(t, -1);
      }
      if (h == -1) return true;

      if (closeHour > openHour) {
        return h >= openHour && h < closeHour;
      } else if (closeHour < openHour) {
        // Overnight operating hours (e.g. 6 PM to 2 AM)
        return h >= openHour || h < closeHour;
      }
      return true;
    }).toList();

    return slots;
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
  void _handleStepContinue(bool skipChooseService) async {
    if (_currentStep == 0 && (_selectedDate == null || _selectedTimes.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Select at least one time slot')));
      return;
    }
    if (_currentStep == 0 && _holdToken == null) {
      if (!_isLoggedIn && !_isGuest) {
        final loggedIn = await _ensureUserLoggedIn();
        if (!loggedIn) return;
      }
      _holdSelectedSlots(autoAdvance: true);
      return;
    }
    if (_currentStep == 1) {
      if (!_isLoggedIn && !_isGuest) {
        final loggedIn = await _ensureUserLoggedIn();
        if (!loggedIn) return;
      }
      final fullName = _nameController.text.trim();
      if (fullName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your full name')));
        return;
      }
      if (fullName.length < 3) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Full name must be at least 3 characters')));
        return;
      }
      final phone = _phoneController.text.trim();
      if (phone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your phone number')));
        return;
      }
      if (phone.length < 7) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid phone number (at least 7 digits)')));
        return;
      }
      final email = _emailController.text.trim();
      if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid email address')));
        return;
      }
      if (!_isLoggedIn) {
        final entered = _captchaController.text.trim().toUpperCase();
        if (entered.isEmpty) {
          setState(() {
            _captchaError = 'Please enter the visual CAPTCHA code above.';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter the visual CAPTCHA code to continue'), backgroundColor: Colors.redAccent),
          );
          return;
        }
        if (entered != _captchaCode.toUpperCase()) {
          setState(() {
            _captchaError = 'Incorrect visual code. Please try again with the new code.';
          });
          _generateCaptchaCode();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Incorrect CAPTCHA code. A new code has been generated.'), backgroundColor: Colors.redAccent),
          );
          return;
        }
        setState(() {
          _captchaError = null;
        });
      }
      _recordBookingLog('PAYMENT_VIEWED');
    }
    if (_currentStep == 2) {
      final ref = _referenceNumberController.text.trim();
      if (ref.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter your payment reference number.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      if (ref.length < 4) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter at least 4 digits of your payment reference number.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      if (_paymentReceiptFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please upload your proof of payment (screenshot of receipt).'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      _recordBookingLog('PAYMENT_ENTERED', refNumber: ref);
      if (!_isLoggedIn && !_isGuest) {
        final loggedIn = await _ensureUserLoggedIn();
        if (!loggedIn) return;
      }
      _submitBooking();
      return;
    }

    if (_currentStep < 2) {
      setState(() => _currentStep += 1);
    } else {
      if (!_isLoggedIn && !_isGuest) {
        final loggedIn = await _ensureUserLoggedIn();
        if (!loggedIn) return;
      }
      _submitBooking();
    }
  }

  void _handleStepCancel() {
    // Only release the timeslot hold when backing out of Step 1 back to Step 0 (or unlocking on Step 0).
    // Backing from Payment (Step 2) -> Details (Step 1)
    // preserves the 5-minute slot lock so the user never loses their held timeslots!
    if (_holdToken != null && _currentStep <= 1) {
      _releaseCurrentHold(refreshSlots: true);
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
      _releaseCurrentHold(refreshSlots: false);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool skipChooseService = widget.skipServiceSelection || widget.initialService != null || (widget.initialServiceName != null && widget.initialServiceName!.isNotEmpty);

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
    ]);


    // Step labels
    final List<String> stepLabels = skipChooseService
        ? ['Date & Time', 'Your Details', 'Payment']
        : ['Courts & Times', 'Your Details', 'Payment'];

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
                    controller: _stepScrollController,
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_currentStep == 0 && (skipChooseService || widget.venue != null)) ...[
                          Builder(
                            builder: (context) {
                              final venueLogo = _getVenueLogoUrl();
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12, top: 4),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.06),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: (venueLogo.isNotEmpty && (venueLogo.startsWith('http') || venueLogo.startsWith('assets/')))
                                          ? (venueLogo.startsWith('assets/')
                                              ? Image.asset(venueLogo, fit: BoxFit.cover)
                                              : Image.network(
                                                  venueLogo,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => Container(
                                                    padding: const EdgeInsets.all(8),
                                                    color: AppColors.primaryGreen,
                                                    child: CustomPaddleIcon(color: AppColors.softWhite, size: 16),
                                                  ),
                                                ))
                                          : Container(
                                              padding: const EdgeInsets.all(8),
                                              color: AppColors.primaryGreen,
                                              child: CustomPaddleIcon(color: AppColors.softWhite, size: 16),
                                            ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'VENUE SELECTED',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.richBlack.withOpacity(0.54),
                                              letterSpacing: 0.6,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            (widget.venue?['venueName'] ?? widget.venue?['name'] ?? 'KAPENARRA COURTSIDE').toString().toUpperCase(),
                                            style: const TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.richBlack,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Builder(
                                            builder: (ctx) {
                                              final String deepLink = _getVenueDeepLink();
                                              return InkWell(
                                                onTap: () {
                                                  Clipboard.setData(ClipboardData(text: deepLink));
                                                  setState(() => _copiedVenueLink = true);
                                                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Row(
                                                        children: const [
                                                          Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                                                          SizedBox(width: 8),
                                                          Text('Venue link copied to clipboard!'),
                                                        ],
                                                      ),
                                                      backgroundColor: AppColors.primaryGreen,
                                                      duration: const Duration(seconds: 2),
                                                      behavior: SnackBarBehavior.floating,
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                    ),
                                                  );
                                                  Future.delayed(const Duration(seconds: 2), () {
                                                    if (mounted) setState(() => _copiedVenueLink = false);
                                                  });
                                                },
                                                borderRadius: BorderRadius.circular(6),
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.link_rounded,
                                                        size: 13,
                                                        color: AppColors.primaryGreen,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Flexible(
                                                        child: Text(
                                                          deepLink,
                                                          style: TextStyle(
                                                            fontFamily: 'Poppins',
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w500,
                                                            color: AppColors.primaryGreen,
                                                            decoration: TextDecoration.underline,
                                                            decorationColor: AppColors.primaryGreen.withOpacity(0.4),
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Tooltip(
                                                        message: 'Copy venue link',
                                                        child: AnimatedContainer(
                                                          duration: const Duration(milliseconds: 200),
                                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                                                          decoration: BoxDecoration(
                                                            color: _copiedVenueLink
                                                                ? AppColors.primaryGreen.withOpacity(0.15)
                                                                : Colors.grey.shade100,
                                                            borderRadius: BorderRadius.circular(4),
                                                            border: Border.all(
                                                              color: _copiedVenueLink
                                                                  ? AppColors.primaryGreen.withOpacity(0.3)
                                                                  : Colors.grey.shade300,
                                                              width: 0.8,
                                                            ),
                                                          ),
                                                          child: Icon(
                                                            _copiedVenueLink ? Icons.check_rounded : Icons.copy_rounded,
                                                            size: 12,
                                                            color: _copiedVenueLink ? AppColors.primaryGreen : Colors.grey.shade700,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                        if (_currentStep == 0 && widget.venue != null)
                          _buildVenuePhotoCarousel(),

                        // Active step content
                        steps[_currentStep].content,

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                // ── Sticky Floating Footer ──
                if (_selectedTimes.isNotEmpty && _currentStep != 1 && _currentStep != 2)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.creamWhite,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 10,
                          offset: const Offset(0, -3),
                        ),
                      ],
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
                      color: AppColors.primaryGreen.withOpacity(0.08),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.sports_tennis, color: AppColors.primaryGreen, size: 16),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        '${_selectedTimes.length} ${_selectedTimes.length == 1 ? "slot" : "slots"} selected',
                                        style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: AppColors.richBlack, fontSize: 12.5),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _selectedTimes.map((t) => '${_extractSlotCourtName(t)}: ${_formatSlotRange(t)}').join(' • '),
                                  style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _getTotalDue(),
                            style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, color: AppColors.primaryGreen, fontSize: 13.5),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () => _handleStepContinue(skipChooseService),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                              foregroundColor: AppColors.softWhite,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              minimumSize: const Size(0, 46),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9999),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Text(
                                  'Book Now',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppColors.softWhite,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.softWhite),
                              ],
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
                key: Key('court_${court.id}_${isExpanded}'),
                initiallyExpanded: isExpanded,
                onExpansionChanged: (expanded) {
                  setState(() {
                    if (expanded) {
                      _expandedCourtIds.add(court.id);
                      // Auto-select this court if expanding
                      _selectedServiceIds.add(court.id);
                      _selectedService = court;
                      _checkLoyaltyStatus();
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
                            final isBooked = (_courtBookedSlots[court.name] ?? _courtBookedSlots[court.venueName] ?? [])
                                .any((bTime) => _normalizeTime(bTime) == _normalizeTime(time) || bTime.trim() == time.trim());
                            final isHeld = (_courtHeldSlots[court.name] ?? _courtHeldSlots[court.venueName] ?? [])
                                .any((hTime) => _normalizeTime(hTime) == _normalizeTime(time) || hTime.trim() == time.trim());

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

                            if (court.openTime != null && court.openTime.toString().trim().isNotEmpty) {
                              int openHour = parseHourValue(court.openTime, 0);
                              if (slotHour < openHour) isOutsideHours = true;
                            }
                            if (court.closeTime != null && court.closeTime.toString().trim().isNotEmpty) {
                              int closeHour = parseHourValue(court.closeTime, 24);
                              if (court.closeTime.toString().contains(':')) {
                                final parts = court.closeTime.toString().split(':');
                                if (parts.length >= 2) {
                                  int min = int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                                  if (min > 0 && closeHour < 24) closeHour += 1;
                                }
                              }
                              if (closeHour == 0) closeHour = 24;
                              int openHour = parseHourValue(court.openTime, 0);

                              if (closeHour > openHour) {
                                if (slotHour >= closeHour) isOutsideHours = true;
                              } else if (closeHour < openHour) {
                                // Overnight operating hours
                                if (slotHour < openHour && slotHour >= closeHour) isOutsideHours = true;
                              }
                            }

                            final bool isDisabled = isBooked || isPast || isOutsideHours;

                            if (isOutsideHours) {
                              return const SizedBox.shrink();
                            }

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
                                _checkLoyaltyStatus();
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
                                              (slotHour >= (court.dayStartHour ?? 6) && slotHour < (court.nightStartHour ?? 18))
                                                  ? Icons.wb_sunny_outlined 
                                                  : Icons.nights_stay_outlined,
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
                                          isOutsideHours ? 'CLOSED' : (isPast ? 'PASSED' : (isHeld ? 'On Hold' : (isBooked ? 'Booked' : _getPriceForTime(time, service: court)))),
                                          style: TextStyle(
                                            color: isSelected ? AppColors.softWhite.withOpacity(0.90) : (isDisabled ? Colors.grey.shade500 : AppColors.richBlack),
                                            fontWeight: FontWeight.bold,
                                            fontSize: (isBooked || isHeld || isOutsideHours) ? 9 : 10,
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

        if (_selectedTimes.isNotEmpty && _holdToken != null)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Column(
              children: [
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
    List<String> facilities = [];
    if (_selectedService != null && _selectedService!.facilities.isNotEmpty) {
      facilities = List<String>.from(_selectedService!.facilities);
    } else {
      final rawFac = v?['facilities'];
      if (rawFac != null) {
        if (rawFac is List) {
          facilities = rawFac.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
        } else if (rawFac is String && rawFac.trim().isNotEmpty) {
          try {
            final decoded = jsonDecode(rawFac);
            if (decoded is List) {
              facilities = decoded.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
            } else if (rawFac.contains(',')) {
              facilities = rawFac.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
            } else {
              facilities = [rawFac.trim()];
            }
          } catch (_) {
            if (rawFac.contains(',')) {
              facilities = rawFac.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
            } else {
              facilities = [rawFac.trim()];
            }
          }
        }
      }
    }

    final String fbUrl = (v?['facebook_url'] ?? v?['facebook'] ?? '').toString().trim();
    final String igUrl = (v?['instagram_url'] ?? v?['instagram'] ?? '').toString().trim();
    final String webUrl = (v?['website_url'] ?? v?['website'] ?? '').toString().trim();

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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(aboutText, style: TextStyle(color: Colors.grey.shade800, fontSize: 13, height: 1.4)),
                          if (fbUrl.isNotEmpty || igUrl.isNotEmpty || webUrl.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (fbUrl.isNotEmpty)
                                  Chip(
                                    avatar: Icon(Icons.facebook, size: 16, color: Color(0xFF1877F2)),
                                    label: Text('Facebook', style: TextStyle(fontSize: 12)),
                                    backgroundColor: Colors.white,
                                    side: BorderSide(color: Colors.grey.shade300),
                                  ),
                                if (igUrl.isNotEmpty)
                                  Chip(
                                    avatar: Icon(Icons.camera_alt_outlined, size: 16, color: Color(0xFFE4405F)),
                                    label: Text('Instagram', style: TextStyle(fontSize: 12)),
                                    backgroundColor: Colors.white,
                                    side: BorderSide(color: Colors.grey.shade300),
                                  ),
                                if (webUrl.isNotEmpty)
                                  Chip(
                                    avatar: Icon(Icons.language, size: 16, color: AppColors.primaryGreen),
                                    label: Text('Website', style: TextStyle(fontSize: 12)),
                                    backgroundColor: Colors.white,
                                    side: BorderSide(color: Colors.grey.shade300),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
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
                      facilities.isEmpty
                        ? Text('No specific amenities listed for this venue.', style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontStyle: FontStyle.italic))
                        : LayoutBuilder(
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
                            },
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

  Widget _buildLabeledDetailField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool isPhone = false,
    bool isEmail = false,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.richBlack,
            ),
            children: [
              TextSpan(text: '$label '),
              const TextSpan(
                text: '*',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: readOnly,
          keyboardType: isPhone
              ? TextInputType.phone
              : (isEmail ? TextInputType.emailAddress : TextInputType.text),
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: AppColors.richBlack,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            suffixIcon: readOnly
                ? Icon(Icons.lock_outline, size: 16, color: Colors.grey.shade400)
                : null,
            filled: true,
            fillColor: const Color(0xFFF3F4F6),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserDetails() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Complete Your Booking',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.richBlack,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Enter your details to reserve your court.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),

          if (!_isLoggedIn) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.softWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2.0),
                    child: Icon(Icons.how_to_reg_outlined, color: AppColors.primaryGreen, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Have an account?',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.richBlack,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Sign up to track your bookings here at this venue and see your history any time — or log in if you already have one. You can still check out as a guest below.',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            height: 1.45,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: () async {
                                final res = await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => RegistrationScreen()),
                                );
                                if (res == 'guest' && mounted) {
                                  setState(() => _isGuest = true);
                                }
                                await _loadUserData();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen,
                                foregroundColor: AppColors.softWhite,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(9999),
                                ),
                              ),
                              child: const Text(
                                'Sign Up',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.softWhite,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton(
                              onPressed: () async {
                                final res = await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => LoginScreen()),
                                );
                                if (res == 'guest' && mounted) {
                                  setState(() => _isGuest = true);
                                }
                                await _loadUserData();
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF334155),
                                side: const BorderSide(color: Color(0xFF94A3B8)),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(9999),
                                ),
                              ),
                              child: const Text(
                                'Log In',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primaryGreen.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_user, color: AppColors.primaryGreen, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Verified Account: ${_nameController.text} (${_emailController.text})',
                      style: GoogleFonts.outfit(fontSize: 12, color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // "Your Details" Card wrapping Full Name, Email, Phone Number, and Security Verification
          Container(
            decoration: BoxDecoration(
              color: AppColors.softWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Bar: Soft gray-green tinted header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.08),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: const Text(
                    'Your Details',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.richBlack,
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabeledDetailField(
                        controller: _nameController,
                        label: 'Full Name',
                        hint: 'John Doe',
                        readOnly: _isLoggedIn,
                      ),
                      const SizedBox(height: 16),
                      _buildLabeledDetailField(
                        controller: _emailController,
                        label: 'Email',
                        hint: 'john@example.com',
                        isEmail: true,
                        readOnly: _isLoggedIn,
                      ),
                      const SizedBox(height: 16),
                      _buildLabeledDetailField(
                        controller: _phoneController,
                        label: 'Phone Number',
                        hint: '+639123456789',
                        isPhone: true,
                        readOnly: _isLoggedIn,
                      ),

                      if (!_isLoggedIn) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.security_rounded, size: 18, color: AppColors.primaryGreen),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Security Verification (CAPTCHA)',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppColors.richBlack,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'ANTI-BOT',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Enter the 5 characters shown below to confirm you are human.',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey.shade400),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CustomPaint(
                                        size: const Size(130, 46),
                                        painter: _VisualCaptchaPainter(_captchaCode, seed: _captchaSeed),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton(
                                    icon: const Icon(Icons.refresh_rounded, color: AppColors.primaryGreen, size: 24),
                                    tooltip: 'Generate new code',
                                    onPressed: _generateCaptchaCode,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _captchaController,
                                      textCapitalization: TextCapitalization.characters,
                                      maxLength: 6,
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        letterSpacing: 2.0,
                                        color: AppColors.richBlack,
                                      ),
                                      decoration: InputDecoration(
                                        labelText: 'Visual Code *',
                                        labelStyle: const TextStyle(letterSpacing: 0, fontSize: 13),
                                        hintText: 'e.g. 7QK4',
                                        hintStyle: TextStyle(letterSpacing: 1.0, color: Colors.grey.shade400, fontWeight: FontWeight.normal, fontSize: 12),
                                        counterText: '',
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide(color: Colors.grey.shade300),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_captchaError != null) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.error_outline_rounded, size: 14, color: Colors.redAccent),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        _captchaError!,
                                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // BOOKING SUMMARY Card + Confirm Booking Card
          Builder(
            builder: (context) {
              final String venueName = (widget.venue?['venueName'] ??
                      widget.venue?['name'] ??
                      _selectedService?.venueName ??
                      _selectedService?.name ??
                      'Court Venue')
                  .toString()
                  .trim();

              final distinctCourts = <String>{};
              for (final t in _selectedTimes) {
                distinctCourts.add(_extractSlotCourtName(t));
              }
              final String courtText = distinctCourts.isNotEmpty
                  ? distinctCourts.join(', ')
                  : (_selectedService?.name ?? '-');

              final String dateText = _selectedDate != null
                  ? DateFormat('EEEE, MMM d').format(_selectedDate!)
                  : '-';

              final String timeText = _selectedTimes.isNotEmpty
                  ? _selectedTimes
                      .map((t) => distinctCourts.length > 1
                          ? '${_extractSlotCourtName(t)}: ${_formatSlotRange(t)}'
                          : _formatSlotRange(t))
                      .join('\n')
                  : '-';

              final int hoursCount = _selectedTimes.length;
              final String durationText = '$hoursCount ${hoursCount == 1 ? "hour" : "hours"}';

              double courtFeeAmount = 0.0;
              for (final t in _selectedTimes) {
                courtFeeAmount += _getSlotPriceValue(t);
              }
              final String courtFeeText = 'PHP ${courtFeeAmount.toStringAsFixed(2)}';
              final String adminFeeText = 'PHP ${_getServiceFee().toStringAsFixed(2)}';
              final String pesoTotalText = _getTotalDue().replaceFirst(RegExp(r'^PHP\s*'), '₱');

              Widget buildInfoRow(String label, String value) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          value,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.richBlack,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Booking Summary Card
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.softWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Header Bar: Soft gray-green tinted header
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withOpacity(0.08),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.receipt_long_outlined, color: AppColors.primaryGreen, size: 19),
                              SizedBox(width: 8),
                              Text(
                                'BOOKING SUMMARY',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                  color: AppColors.richBlack,
                                ),
                              ),
                            ],
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                venueName,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.richBlack,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                courtText,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13.5,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 14),
                              buildInfoRow('Date', dateText),
                              buildInfoRow('Time', timeText),
                              buildInfoRow('Duration', durationText),
                            ],
                          ),
                        ),

                        Divider(height: 1, color: Colors.grey.shade200),

                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              buildInfoRow('Court Fee', courtFeeText),
                              buildInfoRow('Web Admin Fee', adminFeeText),
                              const SizedBox(height: 12),

                              // Total Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Total',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.richBlack,
                                    ),
                                  ),
                                  Text(
                                    pesoTotalText,
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.richBlack,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. Confirm Booking & Terms Card below Booking Summary
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                    decoration: BoxDecoration(
                      color: AppColors.softWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12.5,
                              height: 1.5,
                              color: Color(0xFF64748B),
                            ),
                            children: [
                              TextSpan(text: "By pressing the button below you agree to $venueName's "),
                              const TextSpan(
                                text: 'Terms of Service',
                                style: TextStyle(
                                  color: AppColors.richBlack,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              const TextSpan(text: ' and '),
                              const TextSpan(
                                text: 'Waiver of Liability',
                                style: TextStyle(
                                  color: AppColors.richBlack,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              const TextSpan(text: ", and PickleBook's "),
                              const TextSpan(
                                text: 'Privacy Policy',
                                style: TextStyle(
                                  color: Color(0xFF475569),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              const TextSpan(text: '.'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              final bool skipChooseService = widget.skipServiceSelection ||
                                  widget.initialService != null ||
                                  (widget.initialServiceName != null && widget.initialServiceName!.isNotEmpty);
                              _handleStepContinue(skipChooseService);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                              foregroundColor: AppColors.softWhite,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9999),
                              ),
                            ),
                            child: const Text(
                              'Confirm Booking',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.softWhite,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Your court is held as soon as you confirm — send your payment and proof to secure it.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12.5,
                            height: 1.45,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: _handleStepCancel,
                          borderRadius: BorderRadius.circular(6),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Text(
                              'Back to available hours',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isPhone = false, bool isEmail = false, bool readOnly = false}) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: isPhone ? TextInputType.phone : (isEmail ? TextInputType.emailAddress : TextInputType.text),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey.shade600),
        suffixIcon: readOnly ? Icon(Icons.lock_outline, size: 16, color: Colors.grey.shade400) : null,
        filled: true,
        fillColor: readOnly ? Colors.grey.shade100 : AppColors.softWhite,
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
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFE6E8E2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildSummaryRow(Icons.sports_tennis, 'Court', _selectedService!.name),
          Divider(height: 24, color: Colors.grey.shade300),
          _buildSummaryRow(Icons.calendar_today, 'Date', _selectedDate != null ? '${_selectedDate!.toLocal()}'.split(' ')[0] : '-'),
          Divider(height: 24, color: Colors.grey.shade300),
          Builder(
            builder: (context) {
              final distinctCourts = <String>{};
              for (var t in _selectedTimes) {
                final c = _findCourtForSlot(t);
                if (c != null && c.name.isNotEmpty) distinctCourts.add(c.name);
              }
              if (distinctCourts.length > 1) {
                return Column(
                  children: [
                    _buildSummaryRow(Icons.sports_tennis, 'All Courts', distinctCourts.join(' & ')),
                    Divider(height: 24, color: Colors.grey.shade300),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
          _buildSummaryRow(
            Icons.access_time, 
            'Times', 
            _selectedTimes.isNotEmpty 
                ? _selectedTimes.map((t) => '${_extractSlotCourtName(t)}: ${_formatSlotRange(t)} (PHP ${_getSlotPriceValue(t).toStringAsFixed(0)})').join('\n')
                : '-'
          ),
          Divider(height: 24, color: Colors.grey.shade300),
          _buildSummaryRow(Icons.person, 'Customer', _nameController.text.isEmpty ? '-' : _nameController.text),
          if (_customerLoyalty?.isMember == true && _loyaltySettings != null) ...[
            Divider(height: 24, color: Colors.grey.shade300),
            _buildSummaryRow(
              Icons.stars, 
              'VIP Member Discount', 
              _loyaltySettings!.memberDiscountType == 'PERCENTAGE' 
                  ? '${_loyaltySettings!.memberDiscountValue.toInt()}% OFF (Applied)' 
                  : (_loyaltySettings!.memberDiscountType == 'DISCOUNT_AMOUNT'
                      ? '-₱${_loyaltySettings!.memberDiscountValue.toStringAsFixed(0)} OFF / slot (Applied)'
                      : '₱${_loyaltySettings!.memberDiscountValue.toStringAsFixed(0)} Member Rate (Applied)')
            ),
          ],
          Divider(height: 24, color: Colors.grey.shade300),
          _buildSummaryRow('P', 'Subtotal', _getTotalAmount()),
          Divider(height: 24, color: Colors.grey.shade300),
          _buildSummaryRow(Icons.receipt, 'Service Charge', 'PHP ${_getServiceFee().toStringAsFixed(2)}'),
          Divider(height: 24, color: Colors.grey.shade300),
          _buildSummaryRow('P', 'Total Due', _getTotalDue()),
          if (_referenceNumberController.text.trim().isNotEmpty) ...[
            Divider(height: 24, color: Colors.grey.shade300),
            _buildSummaryRow(Icons.numbers, 'Payment Ref (Last 4)', _referenceNumberController.text.trim()),
          ],
          if (_paymentReceiptBytes != null) ...[
            Divider(height: 24, color: Colors.grey.shade300),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.memory(_paymentReceiptBytes!, width: 40, height: 40, fit: BoxFit.cover),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Proof of Payment', style: TextStyle(fontFamily: 'Poppins', color: Colors.grey.shade600, fontSize: 12)),
                      Text('Receipt Screenshot Attached (JPG)', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryGreen)),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle_rounded, color: AppColors.primaryGreen, size: 20),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.softWhite.withOpacity(0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: AppColors.primaryGreen, size: 20),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
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
    List<double> slotPrices = [];
    for (var time in _selectedTimes) {
      double price = _getSlotPriceValue(time);
      total += price;
      slotPrices.add(price);
    }
    
    // Check if 10th transaction free milestone reached (1 HOUR FREE)
    if (_customerLoyalty != null && _customerLoyalty!.stampCount >= 9 && (_loyaltySettings?.freeRewardEnabled ?? true)) {
      double freeDiscount = slotPrices.isNotEmpty ? slotPrices.first : 0.0;
      double finalTotal = (total - freeDiscount).clamp(0.0, double.infinity);
      if (finalTotal == 0) {
        return 'PHP 0.00 (1 Hour Free Reward!)';
      } else {
        return 'PHP ${finalTotal.toStringAsFixed(2)} (-PHP ${freeDiscount.toStringAsFixed(0)} Free 1 Hour)';
      }
    }

    return total > 0 ? 'PHP ${total.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '')}' : '-';
  }

  String _getTotalDue() {
    double total = 0.0;
    List<double> slotPrices = [];
    for (var time in _selectedTimes) {
      double price = _getSlotPriceValue(time);
      total += price;
      slotPrices.add(price);
    }

    if (_customerLoyalty != null && _customerLoyalty!.stampCount >= 9 && (_loyaltySettings?.freeRewardEnabled ?? true)) {
      double freeDiscount = slotPrices.isNotEmpty ? slotPrices.first : 0.0;
      double finalTotal = (total - freeDiscount).clamp(0.0, double.infinity) + _getServiceFee();
      if (finalTotal == 0) {
        return 'PHP 0.00 (FREE 1st Hour 🎉)';
      } else {
        return 'PHP ${finalTotal.toStringAsFixed(2)} (1 Hour Free Applied 🎉)';
      }
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

  String _getPaymentDetail(dynamic keysInput, String fallback) {
    List<String> keys = [];
    if (keysInput is String) {
      keys = [keysInput];
    } else if (keysInput is List) {
      keys = keysInput.map((e) => e.toString()).toList();
    }

    // Expand common alias keys for maximum resilience
    List<String> expandedKeys = List.from(keys);
    for (var k in keys) {
      final lk = k.toLowerCase();
      if (lk.contains('gcash')) {
        expandedKeys.addAll(['gcash_number', 'gcashNumber', 'gcash', 'gcash_no']);
      }
      if (lk.contains('maya')) {
        expandedKeys.addAll(['paymaya_number', 'paymayaNumber', 'maya_number', 'mayaNumber', 'paymaya', 'maya']);
      }
      if (lk.contains('qr')) {
        expandedKeys.addAll(['qr_code_url', 'qrCodeUrl', 'payment_qr_url', 'paymentQrUrl', 'qr_code', 'qrCode']);
      }
      if (lk.contains('bank_account_name') || lk.contains('accountname')) {
        expandedKeys.addAll(['bank_account_name', 'bankAccountName', 'account_name', 'accountName']);
      }
      if (lk.contains('bank_account') || lk.contains('accountnumber')) {
        expandedKeys.addAll(['bank_account', 'bank_account_number', 'bankAccountNumber', 'bankAccount', 'account_number', 'accountNumber']);
      }
      if (lk.contains('bank_name') || lk.contains('bankname')) {
        expandedKeys.addAll(['bank_name', 'bankName', 'bank']);
      }
      if (lk.contains('instruction')) {
        expandedKeys.addAll(['payment_instructions', 'paymentInstructions', 'instructions', 'notes']);
      }
    }
    keys = expandedKeys.toSet().toList();

    String? checkMap(Map? map) {
      if (map == null) return null;
      for (var k in keys) {
        if (map[k] != null) {
          final v = map[k].toString().trim();
          if (v.isNotEmpty && v != 'null') return v;
        }
      }
      final rawOp = map['owner_payment'] ?? map['ownerPayment'];
      if (rawOp is Map) {
        for (var k in keys) {
          if (rawOp[k] != null) {
            final v = rawOp[k].toString().trim();
            if (v.isNotEmpty && v != 'null') return v;
          }
        }
      } else if (rawOp is String && rawOp.trim().isNotEmpty) {
        try {
          final dec = json.decode(rawOp);
          if (dec is Map) {
            for (var k in keys) {
              if (dec[k] != null) {
                final v = dec[k].toString().trim();
                if (v.isNotEmpty && v != 'null') return v;
              }
            }
          }
        } catch (_) {}
      }
      return null;
    }

    // 1. Check selected service
    if (_selectedService != null) {
      if (_selectedService!.ownerPayment != null) {
        final found = checkMap(_selectedService!.ownerPayment);
        if (found != null) return found;
      }
    }

    // 2. Check widget.venue & venue courts
    if (widget.venue != null) {
      final foundVenue = checkMap(widget.venue);
      if (foundVenue != null) return foundVenue;

      if (widget.venue!['courts'] != null && widget.venue!['courts'] is List) {
        for (var c in widget.venue!['courts']) {
          if (c is Map) {
            final foundC = checkMap(c);
            if (foundC != null) return foundC;
          }
        }
      }
    }

    // 3. Check all services in _services for payment details fallback
    for (var service in _services) {
      if (service.ownerPayment != null) {
        final found = checkMap(service.ownerPayment);
        if (found != null) return found;
      }
    }

    return fallback;
  }

  String _getVenueOwnerEmail() {
    String ownerEmail = _selectedService?.ownerEmail ?? '';
    if (ownerEmail.isEmpty && _selectedService?.ownerPayment != null) {
      ownerEmail = _selectedService!.ownerPayment!['owner_email']?.toString() ??
                   _selectedService!.ownerPayment!['ownerEmail']?.toString() ?? '';
    }
    if (ownerEmail.isEmpty && widget.venue != null) {
      ownerEmail = widget.venue!['owner_email']?.toString() ??
                   widget.venue!['ownerEmail']?.toString() ??
                   widget.venue!['email']?.toString() ?? '';
    }
    if (ownerEmail.isEmpty && _services.isNotEmpty) {
      for (var s in _services) {
        if (s.ownerEmail.isNotEmpty) {
          ownerEmail = s.ownerEmail;
          break;
        }
        if (s.ownerPayment?['owner_email']?.toString().isNotEmpty == true) {
          ownerEmail = s.ownerPayment!['owner_email'].toString();
          break;
        }
      }
    }
    return ownerEmail.trim().toLowerCase();
  }

  bool _isRogerCourt() {
    final ownerEmail = _getVenueOwnerEmail();
    final venueName = (widget.venue?['venueName'] ?? widget.venue?['name'] ?? _selectedService?.venueName ?? '').toString().toLowerCase();
    return ownerEmail.contains('rodge1109') || venueName.contains('rtpa');
  }

  void _showFullQrCodeModal(String qrUrl, {bool isRoger = false}) {
    final bool isNetwork = qrUrl.isNotEmpty && (qrUrl.startsWith('http') || qrUrl.startsWith('/uploads'));
    if (!isNetwork && !isRoger) return;
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isNetwork || isRoger)
                        IconButton(
                          icon: Icon(Icons.download_rounded, color: AppColors.richBlack),
                          tooltip: 'Download QR Code',
                          onPressed: () => downloadImage(isNetwork ? qrUrl : 'assets/qr-code.PNG'),
                        ),
                      IconButton(
                        icon: Icon(Icons.close, color: AppColors.richBlack),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 8),
              InteractiveViewer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: isNetwork
                      ? Image.network(
                          qrUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => isRoger
                              ? Image.asset('assets/qr-code.PNG', fit: BoxFit.contain)
                              : Container(
                                  padding: EdgeInsets.all(20),
                                  color: Colors.grey.shade100,
                                  child: Text('Unable to display QR Code image.', style: TextStyle(color: Colors.grey.shade700)),
                                ),
                        )
                      : Image.asset(
                          'assets/qr-code.PNG',
                          fit: BoxFit.contain,
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
    String qrUrl = _getPaymentDetail(['qr_code_url', 'payment_qr_url', 'qr_code'], '');
    if (qrUrl.startsWith('/uploads')) {
      qrUrl = 'https://pickle-system.onrender.com$qrUrl';
    }
    String gcashNum = _getPaymentDetail(['gcash_number', 'gcash'], '');
    String mayaNum = _getPaymentDetail(['paymaya_number', 'maya_number', 'paymaya', 'maya'], '');
    String bankName = _getPaymentDetail(['bank_name', 'bankName', 'bank'], '');
    String bankAccountName = _getPaymentDetail(['bank_account_name', 'bankAccountName', 'account_name'], '');
    String bankAccount = _getPaymentDetail(['bank_account', 'bank_account_number', 'bankAccount', 'account_number'], '');
    final String customInstructions = _getPaymentDetail(['payment_instructions', 'instructions', 'notes'], '');

    final bool isRogerCourt = _isRogerCourt();

    // Fallbacks if empty
    if (gcashNum.isEmpty && widget.venue != null) {
      gcashNum = widget.venue!['gcash_number']?.toString() ?? widget.venue!['gcash']?.toString() ?? '';
    }

    if (bankAccount.isEmpty && widget.venue != null) {
      bankAccount = widget.venue!['bank_account']?.toString() ?? '';
    }
    if (bankAccountName.isNotEmpty && bankName.isEmpty) {
      if (bankAccountName.toUpperCase() == 'BPI' || bankAccountName.toUpperCase() == 'GCASH' || bankAccountName.toUpperCase() == 'MAYA') {
        bankName = bankAccountName;
      }
    }

    // Only fallback to Roger's GCash number if this venue/court belongs to Roger
    if (gcashNum.isEmpty && isRogerCourt) {
      gcashNum = '09276230491';
    }

    final bool hasCloudinaryQr = qrUrl.trim().isNotEmpty && (qrUrl.startsWith('http') || qrUrl.startsWith('/uploads'));
    final bool canShowQr = hasCloudinaryQr || isRogerCourt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          'Book a Court',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.richBlack,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Almost there — confirm your payment.',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 16),

        // Complete Your Payment & Summary Card
        Builder(
          builder: (context) {
            final String venueName = (widget.venue?['venueName'] ??
                    widget.venue?['name'] ??
                    _selectedService?.venueName ??
                    _selectedService?.name ??
                    'Court Venue')
                .toString()
                .trim();

            final distinctCourts = <String>{};
            for (final t in _selectedTimes) {
              distinctCourts.add(_extractSlotCourtName(t));
            }
            final String courtText = distinctCourts.isNotEmpty
                ? distinctCourts.join(', ')
                : (_selectedService?.name ?? 'Court 1');

            final String dateText = _selectedDate != null
                ? DateFormat('EEEE, MMM d').format(_selectedDate!)
                : '-';

            final int hoursCount = _selectedTimes.length;
            final String hrsLabel = '$hoursCount ${hoursCount == 1 ? "hr" : "hrs"}';
            final String timeRangeText = _selectedTimes.isNotEmpty
                ? '${_selectedTimes.map((t) => _formatSlotRange(t)).join(", ")} ($hrsLabel)'
                : '-';

            final String pesoAmountDue = _getTotalDue()
                .replaceFirst(RegExp(r'^PHP\s*'), '₱')
                .replaceFirst(RegExp(r'\.00$'), '');

            final String rawToken = (_holdToken ?? 'PVVJVBNW')
                .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
                .toUpperCase();
            final String confirmCode = '#PB-${rawToken.length >= 8 ? rawToken.substring(0, 8) : rawToken.padRight(8, 'X')}';

            final int minsLeft = _holdSecondsRemaining > 0 ? (_holdSecondsRemaining ~/ 60) : 0;
            final int secsLeft = _holdSecondsRemaining > 0 ? (_holdSecondsRemaining % 60) : 0;
            final String timerStr = '${minsLeft.toString().padLeft(2, '0')}:${secsLeft.toString().padLeft(2, '0')}';

            final String venueLogo = _getVenueLogoUrl();

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.softWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row with "Complete your payment" and "Time left" badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Complete your\npayment',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                                color: AppColors.richBlack,
                              ),
                            ),
                            const SizedBox(height: 8),
                            RichText(
                              text: const TextSpan(
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  height: 1.45,
                                  color: Color(0xFF64748B),
                                ),
                                children: [
                                  TextSpan(text: 'Your court is reserved for '),
                                  TextSpan(
                                    text: '5 minutes',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                  TextSpan(
                                    text: '. Send payment and your screenshot to confirm your booking.',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F4EE),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.hourglass_empty_rounded,
                              color: AppColors.primaryGreen,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Time left',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                Text(
                                  timerStr,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Inner Venue & Slot Summary Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F5F8),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 78,
                                height: 78,
                                child: venueLogo.startsWith('http')
                                    ? Image.network(
                                        venueLogo,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Image.asset(
                                          'assets/images/pickleball_court.png',
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            color: AppColors.primaryGreen.withOpacity(0.15),
                                            child: const Icon(Icons.sports_tennis, color: AppColors.primaryGreen, size: 32),
                                          ),
                                        ),
                                      )
                                    : Image.asset(
                                        venueLogo.isNotEmpty ? venueLogo : 'assets/images/pickleball_court.png',
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: AppColors.primaryGreen.withOpacity(0.15),
                                          child: const Icon(Icons.sports_tennis, color: AppColors.primaryGreen, size: 32),
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    venueName,
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.richBlack,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today_outlined, size: 13.5, color: Color(0xFF64748B)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          dateText,
                                          style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 12.5,
                                            color: Color(0xFF334155),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.only(top: 2.0),
                                        child: Icon(Icons.access_time_outlined, size: 13.5, color: Color(0xFF64748B)),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          timeRangeText,
                                          style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 12.5,
                                            color: Color(0xFF334155),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.grid_view_outlined, size: 13.5, color: Color(0xFF64748B)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          courtText,
                                          style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 12.5,
                                            color: Color(0xFF334155),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        const SizedBox(height: 12),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Amount due',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 11.5,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    pesoAmountDue,
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.richBlack,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Confirmation',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11.5,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  confirmCode,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.richBlack,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 16),

        // Step 1 ("Send the exact amount") & Step 2 ("Upload your payment screenshot") Container Card
        Builder(
          builder: (context) {
            final String pesoAmountShort = _getTotalDue()
                .replaceFirst(RegExp(r'^PHP\s*'), '₱')
                .replaceFirst(RegExp(r'\.00$'), '');
            final String numericAmount = _getTotalDue()
                .replaceAll(RegExp(r'[^0-9.]'), '')
                .replaceFirst(RegExp(r'\.00$'), '');

            final String primaryAccountNum = gcashNum.isNotEmpty
                ? gcashNum
                : (mayaNum.isNotEmpty ? mayaNum : bankAccount);
            final String primaryAccountLabel = gcashNum.isNotEmpty
                ? 'GCASH'
                : (mayaNum.isNotEmpty
                    ? 'MAYA'
                    : (bankName.isNotEmpty ? bankName.toUpperCase() : 'GCASH'));
            final String accountHolderDisplay = bankAccountName.isNotEmpty
                ? bankAccountName
                : (gcashNum == '09276230491' && isRogerCourt
                    ? 'Roger Tonacao'
                    : (widget.venue?['venueName'] ?? widget.venue?['name'] ?? _selectedService?.venueName ?? '').toString());

            Widget buildTimelineStep({
              required String number,
              required Widget content,
              required bool showLineBelow,
            }) {
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryGreen,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            number,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (showLineBelow)
                          Expanded(
                            child: Container(
                              width: 1.5,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              color: AppColors.primaryGreen.withOpacity(0.28),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: showLineBelow ? 14.0 : 4.0, top: 2.0),
                        child: content,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F6F1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 1. Send the exact amount header ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const Text(
                          '1',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Send the exact amount',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.richBlack,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Your court is held while you pay.',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Amount to send card ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Amount to send',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12.5,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              pesoAmountShort,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: AppColors.richBlack,
                              ),
                            ),
                          ],
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _copyToClipboard(numericAmount, 'Amount'),
                          icon: const Icon(Icons.copy_rounded, size: 15, color: AppColors.richBlack),
                          label: const Text(
                            'Copy',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.richBlack,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9999),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ── QR Code Section (Top) ──
                  if (canShowQr) ...[
                    Text(
                      '$primaryAccountLabel QR code',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.richBlack,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF2E7D32)),
                        const SizedBox(width: 6),
                        Text(
                          '$pesoAmountShort already filled in',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: GestureDetector(
                        onTap: () => _showFullQrCodeModal(
                          hasCloudinaryQr ? qrUrl : 'assets/qr-code.PNG',
                          isRoger: isRogerCourt,
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: hasCloudinaryQr
                                  ? Image.network(
                                      qrUrl,
                                      height: 220,
                                      width: 220,
                                      fit: BoxFit.contain,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return SizedBox(
                                          height: 220,
                                          width: 220,
                                          child: Center(
                                            child: CircularProgressIndicator(color: AppColors.richBlack),
                                          ),
                                        );
                                      },
                                      errorBuilder: (_, __, ___) => isRogerCourt
                                          ? Image.asset(
                                              'assets/qr-code.PNG',
                                              height: 220,
                                              width: 220,
                                              fit: BoxFit.contain,
                                            )
                                          : SizedBox(
                                              height: 220,
                                              width: 220,
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.broken_image_outlined, size: 40, color: Colors.grey.shade400),
                                                  const SizedBox(height: 8),
                                                  Text('QR Code unavailable', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                                ],
                                              ),
                                            ),
                                    )
                                  : Image.asset(
                                      'assets/qr-code.PNG',
                                      height: 220,
                                      width: 220,
                                      fit: BoxFit.contain,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => downloadImage(hasCloudinaryQr ? qrUrl : 'assets/qr-code.PNG'),
                        icon: const Icon(Icons.file_download_outlined, size: 17, color: AppColors.richBlack),
                        label: const Text(
                          'Save QR to photos',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.richBlack,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9999),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Instructions & Account Card (Placed Below the QR Code) ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (primaryAccountNum.isNotEmpty) ...[
                          Text(
                            primaryAccountNum,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.richBlack,
                            ),
                          ),
                          if (accountHolderDisplay.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              accountHolderDisplay,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12.5,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          OutlinedButton(
                            onPressed: () => _copyToClipboard(primaryAccountNum, '$primaryAccountLabel Number'),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9999),
                              ),
                            ),
                            child: const Text(
                              'Copy',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.richBlack,
                              ),
                            ),
                          ),
                          if (mayaNum.isNotEmpty && mayaNum != primaryAccountNum) ...[
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Maya: $mayaNum',
                                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.richBlack),
                                ),
                                TextButton(
                                  onPressed: () => _copyToClipboard(mayaNum, 'Maya Number'),
                                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                  child: const Text('Copy', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
                                ),
                              ],
                            ),
                          ],
                          if (bankAccount.isNotEmpty && bankAccount != primaryAccountNum) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${bankName.isNotEmpty ? bankName : "Bank"}: $bankAccount',
                                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.richBlack),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => _copyToClipboard(bankAccount, 'Bank Account'),
                                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                  child: const Text('Copy', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 14),
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                          const SizedBox(height: 14),
                        ],

                        // Step 1, 2, 3 Timeline
                        buildTimelineStep(
                          number: '1',
                          showLineBelow: true,
                          content: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                height: 1.4,
                                color: Color(0xFF475569),
                              ),
                              children: [
                                TextSpan(text: 'Open $primaryAccountLabel and send '),
                                TextSpan(
                                  text: '$pesoAmountShort.',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.richBlack,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        buildTimelineStep(
                          number: '2',
                          showLineBelow: true,
                          content: const Text(
                            'Take a screenshot of the payment confirmation.',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              height: 1.4,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                        buildTimelineStep(
                          number: '3',
                          showLineBelow: false,
                          content: const Text(
                            'Upload the screenshot below.',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              height: 1.4,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Tip box
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F5F8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 1.0),
                                child: Icon(Icons.lightbulb_rounded, size: 16, color: Color(0xFFF59E0B)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: RichText(
                                  text: const TextSpan(
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 12,
                                      height: 1.45,
                                      color: Color(0xFF64748B),
                                    ),
                                    children: [
                                      TextSpan(
                                        text: 'Tip: ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.richBlack,
                                        ),
                                      ),
                                      TextSpan(
                                        text: 'make sure the amount, date and reference number are visible.',
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (customInstructions.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Owner Note: $customInstructions',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                color: Color(0xFF92400E),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ── 2. Upload your payment screenshot header ──
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const Text(
                          '2',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Upload your payment screenshot',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.richBlack,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Dashed Rounded Upload Box
                  if (_paymentReceiptBytes == null)
                    InkWell(
                      onTap: _showReceiptSourceSheet,
                      borderRadius: BorderRadius.circular(14),
                      child: CustomPaint(
                        painter: _DashedBorderPainter(
                          color: const Color(0xFF94A3B8),
                          strokeWidth: 1.5,
                          dashWidth: 6.0,
                          dashSpace: 4.5,
                          radius: 14.0,
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.camera_alt_rounded,
                                size: 30,
                                color: AppColors.richBlack,
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Tap to upload screenshot',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.5,
                                  color: AppColors.richBlack,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'JPG or PNG',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    CustomPaint(
                      painter: _DashedBorderPainter(
                        color: AppColors.primaryGreen,
                        strokeWidth: 1.5,
                        dashWidth: 6.0,
                        dashSpace: 4.5,
                        radius: 14.0,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                _paymentReceiptBytes!,
                                width: 58,
                                height: 58,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: const [
                                      Icon(Icons.check_circle_rounded, color: AppColors.primaryGreen, size: 16),
                                      SizedBox(width: 4),
                                      Text(
                                        'Receipt Attached',
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: AppColors.primaryGreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _paymentReceiptFile?.name ?? 'payment_receipt.jpg',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade800,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: _showReceiptSourceSheet,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Change', style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18, color: Colors.redAccent),
                              onPressed: () {
                                setState(() {
                                  _paymentReceiptFile = null;
                                  _paymentReceiptBytes = null;
                                });
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Privacy Caption
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Padding(
                        padding: EdgeInsets.only(top: 1.5),
                        child: Icon(
                          Icons.privacy_tip_outlined,
                          size: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "Only the club's staff can see your screenshot, and it is deleted automatically after 90 days.",
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            height: 1.4,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Reference No. Input
                  const Text(
                    'Reference No.',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.richBlack,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _referenceNumberController,
                    keyboardType: TextInputType.text,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.richBlack,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. 123456789012',
                      hintStyle: const TextStyle(
                        fontFamily: 'Poppins',
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.normal,
                        fontSize: 14,
                      ),
                      counterText: '',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'The reference number from your GCash, Maya or bank receipt.',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      height: 1.4,
                      color: Color(0xFF64748B),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Submit payment proof button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final bool skipChooseService = widget.skipServiceSelection ||
                            widget.initialService != null ||
                            (widget.initialServiceName != null && widget.initialServiceName!.isNotEmpty);
                        _handleStepContinue(skipChooseService);
                      },
                      icon: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                      label: const Text(
                        'Submit payment proof',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF708D57),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Lock note below button
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.lock_rounded,
                        size: 14,
                        color: Color(0xFF64748B),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your booking is confirmed once the club checks your payment.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            height: 1.4,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 16),

        // "Start again" link below card
        Center(
          child: InkWell(
            onTap: () {
              _releaseCurrentHold(refreshSlots: true);
              setState(() {
                _currentStep = 0;
              });
            },
            borderRadius: BorderRadius.circular(6),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                'Start again',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13.5,
                  color: Color(0xFF64748B),
                  decoration: TextDecoration.underline,
                  decorationColor: Color(0xFF64748B),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getVenueSlug() {
    if (widget.venue != null && widget.venue!['slug'] != null && widget.venue!['slug'].toString().trim().isNotEmpty) {
      return widget.venue!['slug'].toString().trim().toLowerCase();
    }
    String name = (widget.venue?['venueName'] ?? widget.venue?['name'] ?? _selectedService?.venueName ?? _selectedService?.name ?? '').toString().trim();
    if (name.isEmpty) return 'court';

    String clean = name
        .replaceAll(RegExp(r'\s*\([^)]*\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'[-\s]*(Court|CT|#)\s*\d+.*$', caseSensitive: false), '')
        .trim();

    if (clean.toLowerCase().contains('matchpoint')) return 'matchpoint';
    if (clean.toLowerCase().contains('aminova')) return 'aminova';

    String slug = clean.toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');

    if (slug.startsWith('the-')) {
      slug = slug.substring(4);
    }
    if (slug.endsWith('-pickleball')) {
      slug = slug.substring(0, slug.length - 11);
    }
    return slug.isNotEmpty ? slug : 'venue';
  }

  String _getVenueDeepLink() {
    final slug = _getVenueSlug();
    return 'www.picklebook-ph.com/$slug';
  }

  String _getVenueLogoUrl() {
    String logoUrl = '';
    if (widget.venue != null) {
      logoUrl = (widget.venue!['logo_url'] ?? 
                 widget.venue!['logoUrl'] ?? 
                 widget.venue!['logo'] ?? 
                 widget.venue!['court_logo'] ?? 
                 widget.venue!['image'] ?? 
                 widget.venue!['icon'] ?? '').toString().trim();
      if ((logoUrl.isEmpty || !logoUrl.startsWith('http')) && widget.venue!['courts'] is List) {
        for (var c in widget.venue!['courts']) {
          final cLogo = (c['logo_url'] ?? c['logoUrl'] ?? c['logo'] ?? c['court_logo'] ?? c['image'] ?? c['icon'] ?? '').toString().trim();
          if (cLogo.startsWith('http')) {
            logoUrl = cLogo;
            break;
          }
        }
      }
    }
    if ((logoUrl.isEmpty || !logoUrl.startsWith('http')) && _selectedService != null) {
      if (_selectedService!.icon.startsWith('http')) {
        logoUrl = _selectedService!.icon;
      }
    }
    if (logoUrl.isEmpty || !logoUrl.startsWith('http')) {
      for (var s in _services) {
        if (s.icon.startsWith('http')) {
          logoUrl = s.icon;
          break;
        }
      }
    }
    return logoUrl;
  }

  Widget _buildVenuePhotoCarousel() {
    String logoUrl = _getVenueLogoUrl();

    List<String> photosList = [];

    void parseAndAddPhotos(dynamic source) {
      if (source == null) return;
      if (source is List) {
        for (var item in source) {
          if (item != null) {
            final s = item.toString().trim();
            if (s.isNotEmpty && s.startsWith('http') && !photosList.contains(s)) {
              photosList.add(s);
            }
          }
        }
      } else if (source is String && source.trim().isNotEmpty) {
        final str = source.trim();
        if (str.startsWith('[')) {
          try {
            final decoded = jsonDecode(str);
            if (decoded is List) {
              for (var item in decoded) {
                final s = item.toString().trim();
                if (s.isNotEmpty && s.startsWith('http') && !photosList.contains(s)) {
                  photosList.add(s);
                }
              }
            }
          } catch (_) {}
        } else if (str.contains(',')) {
          for (var part in str.split(',')) {
            final s = part.trim();
            if (s.isNotEmpty && s.startsWith('http') && !photosList.contains(s)) {
              photosList.add(s);
            }
          }
        } else if (str.startsWith('http') && !photosList.contains(str)) {
          photosList.add(str);
        }
      }
    }

    if (widget.venue != null) {
      parseAndAddPhotos(widget.venue!['photos']);
      parseAndAddPhotos(widget.venue!['images']);
      parseAndAddPhotos(widget.venue!['gallery']);
      if (widget.venue!['courts'] != null && widget.venue!['courts'] is List) {
        for (var c in widget.venue!['courts']) {
          parseAndAddPhotos(c['photos']);
          parseAndAddPhotos(c['images']);
          if (c['serviceObj'] is ServiceModel) {
            parseAndAddPhotos((c['serviceObj'] as ServiceModel).photos);
            parseAndAddPhotos((c['serviceObj'] as ServiceModel).images);
          }
        }
      }
    }

    if (_selectedService != null) {
      parseAndAddPhotos(_selectedService!.photos);
      parseAndAddPhotos(_selectedService!.images);
    }

    for (var service in _services) {
      parseAndAddPhotos(service.photos);
      parseAndAddPhotos(service.images);
      if (service.icon.startsWith('http') && !photosList.contains(service.icon)) {
        if (!service.icon.contains('paddle') && !service.icon.contains('logo')) {
          photosList.add(service.icon);
        }
      }
    }

    bool isUsingDefaultLogo = false;
    if (photosList.isEmpty) {
      if (logoUrl.isNotEmpty) {
        photosList.add(logoUrl);
        isUsingDefaultLogo = true;
      }
    }

    return _VenuePhotoCarouselWidget(
      photos: photosList,
      logoUrl: logoUrl,
      venueName: (widget.venue?['venueName'] ?? widget.venue?['name'] ?? 'PICKLEBALL VENUE').toString(),
      isUsingDefaultLogo: isUsingDefaultLogo,
    );
  }
}

class _VenuePhotoCarouselWidget extends StatefulWidget {
  final List<String> photos;
  final String logoUrl;
  final String venueName;
  final bool isUsingDefaultLogo;

  const _VenuePhotoCarouselWidget({
    Key? key,
    required this.photos,
    required this.logoUrl,
    required this.venueName,
    this.isUsingDefaultLogo = false,
  }) : super(key: key);

  @override
  _VenuePhotoCarouselWidgetState createState() => _VenuePhotoCarouselWidgetState();
}

class _VenuePhotoCarouselWidgetState extends State<_VenuePhotoCarouselWidget> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    if (widget.photos.length > 1) {
      _autoTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (_pageController.hasClients) {
          int nextPage = (_currentIndex + 1) % widget.photos.length;
          _pageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty && widget.logoUrl.isEmpty) {
      return Container(
        height: 140,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [AppColors.deepTeal, AppColors.primaryGreen],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              bottom: -20,
              child: Opacity(
                opacity: 0.15,
                child: Icon(Icons.sports_tennis, size: 140, color: Colors.white),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'OFFICIAL VENUE',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.venueName,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: const [
                      Icon(Icons.photo_library_outlined, size: 14, color: Colors.white70),
                      SizedBox(width: 6),
                      Text('Pickleball Court Facility', style: TextStyle(fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final displayPhotos = widget.photos;

    return Container(
      height: 180,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: displayPhotos.length,
              onPageChanged: (idx) {
                setState(() => _currentIndex = idx);
              },
              itemBuilder: (ctx, i) {
                final imgUrl = displayPhotos[i];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      imgUrl,
                      fit: widget.isUsingDefaultLogo ? BoxFit.contain : BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.deepTeal.withOpacity(0.1),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.sports_tennis, size: 40, color: AppColors.primaryGreen),
                              const SizedBox(height: 6),
                              Text(widget.venueName, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.richBlack, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (!widget.isUsingDefaultLogo)
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withOpacity(0.3),
                              Colors.transparent,
                              Colors.black.withOpacity(0.5),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            if (widget.logoUrl.isNotEmpty && !widget.isUsingDefaultLogo) ...[
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.network(
                      widget.logoUrl,
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.primaryGreen,
                        child: Icon(Icons.sports_tennis, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (widget.isUsingDefaultLogo) ...[
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.verified_outlined, size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text('Official Venue Logo', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ],
            if (displayPhotos.length > 1) ...[
              Positioned(
                bottom: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_currentIndex + 1}/${displayPhotos.length}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(displayPhotos.length, (idx) {
                    final bool isCurrent = idx == _currentIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: isCurrent ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isCurrent ? Colors.white : Colors.white.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
              ),
            ],
            if (!widget.isUsingDefaultLogo)
              Positioned(
                bottom: 12,
                left: 12,
                child: Text(
                  widget.venueName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VisualCaptchaPainter extends CustomPainter {
  final String text;
  final int seed;

  _VisualCaptchaPainter(this.text, {this.seed = 42});

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(seed);

    // Background fill
    final bgPaint = Paint()..color = const Color(0xFFF1F5F9);
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)), bgPaint);

    // Draw random noise lines
    final linePaint = Paint()
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 6; i++) {
      linePaint.color = Colors.primaries[rand.nextInt(Colors.primaries.length)].withOpacity(0.35);
      final p1 = Offset(rand.nextDouble() * size.width, rand.nextDouble() * size.height);
      final p2 = Offset(rand.nextDouble() * size.width, rand.nextDouble() * size.height);
      canvas.drawLine(p1, p2, linePaint);
    }

    // Draw random noise dots
    final dotPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 35; i++) {
      dotPaint.color = Colors.primaries[rand.nextInt(Colors.primaries.length)].withOpacity(0.3);
      canvas.drawCircle(Offset(rand.nextDouble() * size.width, rand.nextDouble() * size.height), 1.2, dotPaint);
    }

    if (text.isEmpty) return;

    // Draw characters with random skew, tilt, and colors
    final charSpacing = size.width / (text.length + 1);
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      final color = Colors.primaries[(i * 3 + rand.nextInt(5)) % Colors.primaries.length].shade900;

      final textSpan = TextSpan(
        text: char,
        style: TextStyle(
          fontFamily: 'Courier',
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final x = (i + 1) * charSpacing - (textPainter.width / 2) + (rand.nextDouble() * 4 - 2);
      final y = (size.height / 2) - (textPainter.height / 2) + (rand.nextDouble() * 4 - 2);

      canvas.save();
      final angle = (rand.nextDouble() - 0.5) * 0.45; // slight tilt
      canvas.translate(x + textPainter.width / 2, y + textPainter.height / 2);
      canvas.rotate(angle);
      textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _VisualCaptchaPainter oldDelegate) =>
      oldDelegate.text != text || oldDelegate.seed != seed;
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double radius;

  _DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.dashWidth = 6.0,
    this.dashSpace = 4.5,
    this.radius = 14.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dashWidth, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.dashWidth != dashWidth ||
      oldDelegate.dashSpace != dashSpace ||
      oldDelegate.radius != radius;
}

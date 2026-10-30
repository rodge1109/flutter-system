import 'package:flutter/material.dart';
import 'package:flutter_project/theme/app_colors.dart';
import '../services/api_service.dart';
import 'booking_confirmation_screen.dart';
import 'dashboard_screen.dart';

class CourtPassScreen extends StatefulWidget {
  final String? bookingId;
  final Map<String, String>? queryParams;

  const CourtPassScreen({
    Key? key,
    this.bookingId,
    this.queryParams,
  }) : super(key: key);

  @override
  State<CourtPassScreen> createState() => _CourtPassScreenState();
}

class _CourtPassScreenState extends State<CourtPassScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _errorMessage;

  String? _courtName;
  String? _courtAddress;
  String? _courtImage;
  DateTime? _bookingDate;
  List<String> _timeSlots = [];
  String? _courtNumber;
  double _totalPaid = 0.0;
  String? _bookingId;
  String? _playerName;

  @override
  void initState() {
    super.initState();
    _loadCourtPass();
  }

  Future<void> _loadCourtPass() async {
    final bId = widget.bookingId?.trim();
    final qParams = widget.queryParams;

    // Check if query params have sufficient details for immediate preview
    if (qParams != null && qParams.containsKey('court')) {
      _applyQueryParams(qParams);
      if (bId == null || bId.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
    }

    if (bId == null || bId.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No booking reference or court pass ID provided.';
      });
      return;
    }

    try {
      // Fetch appointment and raw services in parallel for rich court metadata
      final results = await Future.wait([
        _apiService.getAppointmentById(bId),
        _apiService.fetchRawServices(),
      ]);

      final appointment = results[0] as Map<String, dynamic>?;
      final services = results[1] as List<dynamic>? ?? [];

      if (appointment != null) {
        final serviceType = (appointment['service_type'] ?? '').toString().trim();
        final specialistId = (appointment['specialist_id'] ?? '').toString().trim();

        // Find matching service for logo & address
        dynamic matchedService;
        for (var s in services) {
          if (s is Map) {
            final sId = (s['id'] ?? '').toString();
            final sName = (s['name'] ?? '').toString().trim();
            if ((specialistId.isNotEmpty && sId == specialistId) ||
                (serviceType.isNotEmpty && sName.toLowerCase() == serviceType.toLowerCase())) {
              matchedService = s;
              break;
            }
          }
        }

        final venueTitle = matchedService?['venue_name'] ?? matchedService?['venueName'] ?? '';
        final cName = serviceType.isNotEmpty
            ? serviceType
            : (matchedService?['name'] ?? 'Court');

        final cAddress = matchedService?['address']?.toString().isNotEmpty == true
            ? matchedService!['address'].toString()
            : (matchedService?['description']?.toString().isNotEmpty == true
                ? matchedService!['description'].toString()
                : 'Cayang, Bogo City');

        String? cImage;
        if (matchedService != null) {
          final logo = matchedService['logo_url'] ?? matchedService['logo'] ?? matchedService['icon'] ?? matchedService['image'];
          if (logo != null && logo.toString().trim().startsWith('http')) {
            cImage = logo.toString().trim();
          }
        }

        // Date parsing avoiding UTC shifts
        DateTime bDate = DateTime.now();
        final rawDate = (appointment['preferred_date'] ?? '').toString();
        if (rawDate.isNotEmpty) {
          try {
            final datePart = rawDate.split('T')[0];
            final parts = datePart.split('-');
            if (parts.length == 3) {
              bDate = DateTime(
                int.parse(parts[0]),
                int.parse(parts[1]),
                int.parse(parts[2]),
              );
            } else {
              bDate = DateTime.parse(rawDate).toLocal();
            }
          } catch (_) {
            bDate = DateTime.tryParse(rawDate) ?? DateTime.now();
          }
        }

        // Time slot formatting
        final prefTime = (appointment['preferred_time'] ?? '10:00 AM').toString().trim();
        final String formattedSlot = (cName.isNotEmpty && !prefTime.contains(': '))
            ? '$cName: $prefTime'
            : prefTime;

        final double price = double.tryParse(
              (appointment['total_amount'] ?? appointment['amount'] ?? '0')
                  .toString()
                  .replaceAll(RegExp(r'[^0-9.]'), ''),
            ) ??
            0.0;

        setState(() {
          _courtName = cName;
          _courtAddress = cAddress;
          _courtImage = cImage;
          _bookingDate = bDate;
          _timeSlots = [formattedSlot];
          _courtNumber = cName;
          _totalPaid = price;
          _bookingId = bId;
          _playerName = appointment['full_name']?.toString();
          _isLoading = false;
        });
        return;
      }

      // If appointment was not found from API, check if fallback params exist
      if (qParams != null && qParams.containsKey('court')) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Court pass for booking #$bId could not be found or has expired.';
      });
    } catch (e) {
      if (qParams != null && qParams.containsKey('court')) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load court pass: $e';
      });
    }
  }

  void _applyQueryParams(Map<String, String> q) {
    _courtName = q['court'] ?? 'Court';
    _courtAddress = q['address'] ?? 'Cayang, Bogo City';
    _courtNumber = q['courtNum'] ?? q['court'] ?? 'Court 1';
    _totalPaid = double.tryParse(q['price'] ?? '0') ?? 0.0;
    _playerName = q['name'];
    _bookingId = widget.bookingId ?? q['id'] ?? q['bookingId'];

    if (q['time'] != null && q['time']!.isNotEmpty) {
      _timeSlots = [q['time']!];
    } else {
      _timeSlots = ['10:00 AM'];
    }

    if (q['date'] != null && q['date']!.isNotEmpty) {
      try {
        _bookingDate = DateTime.parse(q['date']!);
      } catch (_) {
        _bookingDate = DateTime.now();
      }
    } else {
      _bookingDate = DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.creamWhite,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Image.asset(
                  'assets/app_icon.png',
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.sports_tennis,
                    color: AppColors.primaryGreen,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.8,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Retrieving Court Pass...',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.richBlack.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null || _courtName == null) {
      return Scaffold(
        backgroundColor: AppColors.creamWhite,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.richBlack),
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const DashboardScreen()),
                );
              }
            },
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.receipt_long_outlined,
                      color: Colors.orange.shade700,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Court Pass Not Found',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.richBlack,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage ?? 'Unable to find reservation details for this match pass.',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        } else {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const DashboardScreen()),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Back to Home / Courts',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
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

    return BookingConfirmationScreen(
      courtName: _courtName!,
      courtAddress: _courtAddress ?? 'Cayang, Bogo City',
      courtImage: _courtImage,
      bookingDate: _bookingDate ?? DateTime.now(),
      timeSlots: _timeSlots,
      courtNumber: _courtNumber ?? _courtName!,
      totalPaid: _totalPaid,
      bookingId: _bookingId,
      playerName: _playerName,
    );
  }
}

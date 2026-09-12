import 'dart:convert';

class ServiceModel {
  final int id;
  final String name;
  final String description;
  final String price;
  final String address;
  final List<String> facilities;
  final String icon;
  final String duration;
  final String category;
  final bool isActive;
  final List<dynamic>? variablePrices;
  final Map<String, dynamic>? ownerPayment;
  final double? latitude;
  final double? longitude;
  final String? basePrice;
  final dynamic hourlyPrices;
  final String? openTime;
  final String? closeTime;
  final String? aboutVenue;
  final String? bookingPolicy;
  final String? faq;
  final String ownerEmail;
  final int? dayStartHour;
  final int? nightStartHour;

  ServiceModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.ownerEmail = '',
    this.address = '',
    this.facilities = const [],
    required this.icon,
    required this.duration,
    required this.category,
    required this.isActive,
    this.variablePrices,
    this.ownerPayment,
    this.latitude,
    this.longitude,
    this.basePrice,
    this.hourlyPrices,
    this.openTime,
    this.closeTime,
    this.aboutVenue,
    this.bookingPolicy,
    this.faq,
    this.dayStartHour,
    this.nightStartHour,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    List<dynamic>? parsedVariablePrices;
    final rawVar = json['variable_prices'] ?? json['hourly_prices'] ?? json['hourlyPrices'];
    if (rawVar != null) {
      if (rawVar is List) {
        parsedVariablePrices = rawVar;
      } else if (rawVar is String) {
        try {
          final decoded = jsonDecode(rawVar);
          if (decoded is List) {
            parsedVariablePrices = decoded;
          }
        } catch (_) {}
      }
    }

    final int parsedDayStart = json['day_start_hour'] != null 
        ? (int.tryParse(json['day_start_hour'].toString()) ?? 6)
        : (json['dayStartHour'] != null ? (int.tryParse(json['dayStartHour'].toString()) ?? 6) : 6);

    final int parsedNightStart = json['night_start_hour'] != null 
        ? (int.tryParse(json['night_start_hour'].toString()) ?? 18)
        : (json['nightStartHour'] != null ? (int.tryParse(json['nightStartHour'].toString()) ?? 18) : 18);

    final String parsedOwnerEmail = json['owner_email']?.toString() ?? 
        json['ownerEmail']?.toString() ?? 
        json['owner']?.toString() ?? 
        (json['owner_payment'] != null ? json['owner_payment']['owner_email']?.toString() ?? '' : '');

    List<String> parsedFacilities = [];
    final rawFac = json['facilities'];
    if (rawFac != null) {
      if (rawFac is List) {
        parsedFacilities = rawFac.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
      } else if (rawFac is String && rawFac.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(rawFac);
          if (decoded is List) {
            parsedFacilities = decoded.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
          } else if (rawFac.contains(',')) {
            parsedFacilities = rawFac.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
          } else {
            parsedFacilities = [rawFac.trim()];
          }
        } catch (_) {
          if (rawFac.contains(',')) {
            parsedFacilities = rawFac.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
          } else {
            parsedFacilities = [rawFac.trim()];
          }
        }
      }
    }

    return ServiceModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? 'Enjoy a fun and active game on our well-maintained pickleball court, perfect for players of all skill levels.',
      price: json['price']?.toString() ?? '',
      ownerEmail: parsedOwnerEmail,
      address: json['address'] as String? ?? '',
      facilities: parsedFacilities,
      icon: json['icon'] as String? ?? '',
      duration: json['duration']?.toString() ?? '30M',
      category: json['category'] as String? ?? 'General',
      isActive: json['is_active'] as bool? ?? true,
      variablePrices: parsedVariablePrices,
      ownerPayment: json['owner_payment'] as Map<String, dynamic>?,
      latitude: json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null,
      basePrice: json['base_price']?.toString(),
      hourlyPrices: parsedVariablePrices,
      openTime: json['open_time']?.toString(),
      closeTime: json['close_time']?.toString(),
      aboutVenue: json['about_venue']?.toString(),
      bookingPolicy: json['booking_policy']?.toString(),
      faq: json['faq']?.toString(),
      dayStartHour: parsedDayStart,
      nightStartHour: parsedNightStart,
    );
  }
}

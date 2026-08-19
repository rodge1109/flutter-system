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

  ServiceModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
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
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? 'Enjoy a fun and active game on our well-maintained pickleball court, perfect for players of all skill levels.',
      price: json['price']?.toString() ?? '',
      address: json['address'] as String? ?? '',
      facilities: (json['facilities'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      icon: json['icon'] as String? ?? '',
      duration: json['duration']?.toString() ?? '30M',
      category: json['category'] as String? ?? 'General',
      isActive: json['is_active'] as bool? ?? true,
      variablePrices: json['variable_prices'] as List<dynamic>?,
      ownerPayment: json['owner_payment'] as Map<String, dynamic>?,
      latitude: json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null,
      basePrice: json['base_price']?.toString(),
      hourlyPrices: json['variable_prices'] ?? json['hourly_prices'],
      openTime: json['open_time']?.toString(),
      closeTime: json['close_time']?.toString(),
    );
  }
}

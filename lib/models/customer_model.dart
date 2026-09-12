class CustomerModel {
  final dynamic id;
  final String ownerEmail;
  final String fullName;
  final String email;
  final String? phone;
  final bool isMember;
  final int loyaltyPoints;
  final int stampCount;
  final int totalCompletedBookings;
  final String? createdAt;

  CustomerModel({
    required this.id,
    required this.ownerEmail,
    required this.fullName,
    required this.email,
    this.phone,
    this.isMember = false,
    this.loyaltyPoints = 0,
    this.stampCount = 0,
    this.totalCompletedBookings = 0,
    this.createdAt,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id'],
      ownerEmail: json['owner_email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      isMember: json['is_member'] == true || json['is_member'] == 1,
      loyaltyPoints: int.tryParse(json['loyalty_points']?.toString() ?? '0') ?? 0,
      stampCount: int.tryParse(json['stamp_count']?.toString() ?? '0') ?? 0,
      totalCompletedBookings: int.tryParse(json['total_completed_bookings']?.toString() ?? '0') ?? 0,
      createdAt: json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_email': ownerEmail,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'is_member': isMember,
      'loyalty_points': loyaltyPoints,
      'stamp_count': stampCount,
      'total_completed_bookings': totalCompletedBookings,
      'created_at': createdAt,
    };
  }

  bool get isNextBookingFree => stampCount >= 9;
}

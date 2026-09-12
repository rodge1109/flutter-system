class LoyaltySettingsModel {
  final dynamic id;
  final String ownerEmail;
  final String memberDiscountType; // 'PERCENTAGE', 'FIXED_PRICE', 'DISCOUNT_AMOUNT'
  final double memberDiscountValue;
  final int milestoneTarget; // Default 10
  final bool freeRewardEnabled;

  LoyaltySettingsModel({
    this.id,
    required this.ownerEmail,
    this.memberDiscountType = 'PERCENTAGE',
    this.memberDiscountValue = 15.0, // Default 15% off for members
    this.milestoneTarget = 10,
    this.freeRewardEnabled = true,
  });

  factory LoyaltySettingsModel.fromJson(Map<String, dynamic> json) {
    return LoyaltySettingsModel(
      id: json['id'],
      ownerEmail: json['owner_email'] as String? ?? '',
      memberDiscountType: json['member_discount_type'] as String? ?? 'PERCENTAGE',
      memberDiscountValue: double.tryParse(json['member_discount_value']?.toString() ?? '15.0') ?? 15.0,
      milestoneTarget: int.tryParse(json['milestone_target']?.toString() ?? '10') ?? 10,
      freeRewardEnabled: json['free_reward_enabled'] == null ? true : (json['free_reward_enabled'] == true || json['free_reward_enabled'] == 1),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_email': ownerEmail,
      'member_discount_type': memberDiscountType,
      'member_discount_value': memberDiscountValue,
      'milestone_target': milestoneTarget,
      'free_reward_enabled': freeRewardEnabled,
    };
  }

  // Helper method to calculate member price based on regular price
  double calculateMemberPrice(double regularPrice) {
    if (memberDiscountType == 'PERCENTAGE') {
      double discount = regularPrice * (memberDiscountValue / 100.0);
      return (regularPrice - discount).clamp(0.0, double.infinity);
    } else if (memberDiscountType == 'FIXED_PRICE') {
      return memberDiscountValue;
    } else if (memberDiscountType == 'DISCOUNT_AMOUNT') {
      return (regularPrice - memberDiscountValue).clamp(0.0, double.infinity);
    }
    return regularPrice;
  }
}

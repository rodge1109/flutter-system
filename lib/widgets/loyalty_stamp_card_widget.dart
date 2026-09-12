import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import 'pickleball_icon.dart';

class LoyaltyStampCardWidget extends StatelessWidget {
  final int stampCount; // 0 to 10
  final int milestoneTarget; // Default 10
  final String courtOwnerName;
  final bool isMember;
  final VoidCallback? onTapReward;

  const LoyaltyStampCardWidget({
    Key? key,
    required this.stampCount,
    this.milestoneTarget = 10,
    this.courtOwnerName = 'Member Rewards',
    this.isMember = true,
    this.onTapReward,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    int safeStamps = stampCount.clamp(0, milestoneTarget);
    bool isMilestoneReached = safeStamps >= milestoneTarget - 1; // 9th stamp means 10th transaction is next/free!

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F2E1F),
            Color(0xFF1B4332),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isMilestoneReached ? AppColors.accentLime : Colors.white12,
          width: isMilestoneReached ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
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
                    child: const PickleballIcon(
                      size: 20,
                      color: AppColors.accentLime,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        courtOwnerName,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isMember ? 'VIP Member Club' : 'Loyalty Rewards',
                        style: GoogleFonts.outfit(
                          color: AppColors.accentLime,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isMilestoneReached
                      ? AppColors.accentLime
                      : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$safeStamps / $milestoneTarget Stamps',
                  style: GoogleFonts.outfit(
                    color: isMilestoneReached ? AppColors.richBlack : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Stamp Grid (5 per row for 10 total)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: milestoneTarget,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (context, index) {
              bool isFilled = index < safeStamps;
              bool isLastRewardSlot = index == milestoneTarget - 1;

              return Container(
                decoration: BoxDecoration(
                  color: isFilled
                      ? AppColors.accentLime
                      : (isLastRewardSlot ? Colors.amber.withOpacity(0.2) : Colors.white.withOpacity(0.08)),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isFilled
                        ? AppColors.accentLime
                        : (isLastRewardSlot ? Colors.amber : Colors.white30),
                    width: isLastRewardSlot ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: isFilled
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.richBlack,
                          size: 22,
                        )
                      : isLastRewardSlot
                          ? const Icon(
                              Icons.card_giftcard_rounded,
                              color: Colors.amber,
                              size: 22,
                            )
                          : Text(
                              '${index + 1}',
                              style: GoogleFonts.outfit(
                                color: Colors.white60,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                ),
              );
            },
          ),

          const SizedBox(height: 14),

          // Footer Status Banner
          if (isMilestoneReached)
            GestureDetector(
              onTap: onTapReward,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.accentLime,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.stars_rounded, color: AppColors.richBlack, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '🎉 10th Transaction Unlocked: FREE Court Session!',
                      style: GoogleFonts.outfit(
                        color: AppColors.richBlack,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.white60, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Complete ${milestoneTarget - safeStamps} more booking${(milestoneTarget - safeStamps) == 1 ? '' : 's'} to get your 10th transaction FREE!',
                    style: GoogleFonts.outfit(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

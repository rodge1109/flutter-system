import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/customer_model.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/loyalty_stamp_card_widget.dart';
import 'login_screen.dart';

class LoyaltyRewardsScreen extends StatefulWidget {
  const LoyaltyRewardsScreen({super.key});

  @override
  State<LoyaltyRewardsScreen> createState() => _LoyaltyRewardsScreenState();
}

class _LoyaltyRewardsScreenState extends State<LoyaltyRewardsScreen> {
  bool _isLoading = true;
  bool _isLoggedIn = false;
  String _userEmail = '';
  String _userRole = 'user';
  List<CustomerModel> _loyaltyRecords = [];

  @override
  void initState() {
    super.initState();
    _loadUserAndFetchLoyalty();
  }

  Future<void> _loadUserAndFetchLoyalty() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');

    if (userStr != null && userStr.trim().isNotEmpty && userStr != 'null') {
      try {
        final userObj = json.decode(userStr);
        final email = (userObj['email'] ?? '').toString().trim();
        final role = (userObj['role'] ?? 'user').toString().toLowerCase().trim();

        if (email.isNotEmpty && email.contains('@')) {
          _isLoggedIn = true;
          _userEmail = email;
          _userRole = role;
        } else {
          _isLoggedIn = false;
          _userEmail = '';
        }
      } catch (_) {
        _isLoggedIn = false;
        _userEmail = '';
      }
    } else {
      _isLoggedIn = false;
      _userEmail = '';
    }

    if (_isLoggedIn && _userRole != 'owner' && _userRole != 'court_owner' && _userRole != 'super_admin' && _userEmail.isNotEmpty) {
      try {
        final records = await ApiService().fetchAllCustomerLoyalty(_userEmail);
        if (mounted) {
          setState(() {
            _loyaltyRecords = records;
            _isLoading = false;
          });
        }
        return;
      } catch (e) {
        debugPrint('Error fetching loyalty records: $e');
      }
    }

    if (mounted) {
      setState(() {
        _loyaltyRecords.clear();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamWhite,
      appBar: AppBar(
        title: Text(
          'My Rewards & Loyalty',
          style: TextStyle(color: AppColors.richBlack, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.richBlack),
        actions: [
          if (_isLoggedIn)
            IconButton(
              icon: Icon(Icons.refresh, color: AppColors.richBlack),
              tooltip: 'Refresh Stamps',
              onPressed: _loadUserAndFetchLoyalty,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- HEADER INFO CARD ---
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.stars_rounded, color: Colors.amber, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Loyalty Stamp Program',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppColors.richBlack,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Earn 1 stamp per completed booking. Your 10th session is ONE HOUR FREE!',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // --- LOGGED-OUT / GUEST STATE ---
                  if (!_isLoggedIn) ...[
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.lock_outline_rounded, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 14),
                          Text(
                            'Log in to View Your Stamps',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.richBlack,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'You are currently browsing as a guest. Log in to track your loyalty stamps across courts and redeem your free sessions.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                final res = await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => LoginScreen()),
                                );
                                if (res != 'guest') {
                                  _loadUserAndFetchLoyalty();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text(
                                'Log In or Sign Up',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]
                  // --- EMPTY STAMPS STATE ---
                  else if (_loyaltyRecords.isEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.card_giftcard_rounded, color: AppColors.primaryGreen, size: 44),
                          const SizedBox(height: 12),
                          Text(
                            'No Stamps Yet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.richBlack,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Book your first court session using $_userEmail to start earning stamps toward your FREE 10th session!',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ]
                  // --- ACTIVE LOYALTY CARDS ---
                  else ...[
                    Column(
                      children: _loyaltyRecords.map((rec) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: LoyaltyStampCardWidget(
                            stampCount: rec.stampCount,
                            courtOwnerName: rec.ownerEmail.isNotEmpty ? 'Venue (${rec.ownerEmail})' : 'Court Loyalty',
                            isMember: rec.isMember,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

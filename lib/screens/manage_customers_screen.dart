import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/customer_model.dart';
import '../models/loyalty_settings_model.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/pickleball_icon.dart';
import '../widgets/loyalty_stamp_card_widget.dart';

class ManageCustomersScreen extends StatefulWidget {
  final String ownerEmail;

  const ManageCustomersScreen({Key? key, required this.ownerEmail}) : super(key: key);

  @override
  _ManageCustomersScreenState createState() => _ManageCustomersScreenState();
}

class _ManageCustomersScreenState extends State<ManageCustomersScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  bool _isLoading = true;
  List<CustomerModel> _customers = [];
  List<CustomerModel> _filteredCustomers = [];
  LoyaltySettingsModel? _loyaltySettings;

  final TextEditingController _searchController = TextEditingController();
  
  // Controllers for Loyalty Settings Form
  String _discountType = 'PERCENTAGE';
  final TextEditingController _discountValueController = TextEditingController(text: '15.0');
  bool _freeRewardEnabled = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _discountValueController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final customersFuture = _apiService.fetchOwnerCustomers(widget.ownerEmail);
      final settingsFuture = _apiService.fetchLoyaltySettings(widget.ownerEmail);

      final results = await Future.wait([customersFuture, settingsFuture]);

      setState(() {
        _customers = results[0] as List<CustomerModel>;
        _filteredCustomers = List.from(_customers);
        _loyaltySettings = results[1] as LoyaltySettingsModel;
        _discountType = _loyaltySettings?.memberDiscountType ?? 'PERCENTAGE';
        _discountValueController.text = (_loyaltySettings?.memberDiscountValue ?? 15.0).toString();
        _freeRewardEnabled = _loyaltySettings?.freeRewardEnabled ?? true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Failed to load customers or loyalty settings', isError: true);
    }
  }

  void _onSearchChanged() {
    String query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCustomers = List.from(_customers);
      } else {
        _filteredCustomers = _customers.where((c) {
          return c.fullName.toLowerCase().contains(query) ||
              c.email.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.outfit(color: Colors.white)),
        backgroundColor: isError ? Colors.redAccent : AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveLoyaltySettings() async {
    double value = double.tryParse(_discountValueController.text.trim()) ?? 15.0;
    final updated = LoyaltySettingsModel(
      ownerEmail: widget.ownerEmail,
      memberDiscountType: _discountType,
      memberDiscountValue: value,
      milestoneTarget: 10,
      freeRewardEnabled: _freeRewardEnabled,
    );

    bool success = await _apiService.saveLoyaltySettings(updated);
    if (success) {
      setState(() => _loyaltySettings = updated);
      _showSnackBar('Loyalty & Member Price settings updated!');
    } else {
      _showSnackBar('Failed to save loyalty settings', isError: true);
    }
  }

  void _showAddEditCustomerModal({CustomerModel? existingCustomer}) {
    final nameController = TextEditingController(text: existingCustomer?.fullName ?? '');
    final emailController = TextEditingController(text: existingCustomer?.email ?? '');
    final phoneController = TextEditingController(text: existingCustomer?.phone ?? '');
    bool isMember = existingCustomer?.isMember ?? true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          existingCustomer == null ? 'Register New Customer' : 'Edit Customer',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.richBlack,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Full Name *',
                        hintText: 'e.g. Alex Morgan',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email Address *',
                        hintText: 'e.g. alex@example.com',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Phone Number (Optional)',
                        hintText: 'e.g. +1 555 123 4567',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.creamWhite,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SwitchListTile(
                        title: Text(
                          'VIP Member Privileges',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            color: AppColors.richBlack,
                          ),
                        ),
                        subtitle: Text(
                          'Unlocks special member rates & accumulates stamps for 10th free transaction.',
                          style: GoogleFonts.outfit(fontSize: 12, color: Colors.black54),
                        ),
                        activeColor: AppColors.primaryGreen,
                        value: isMember,
                        onChanged: (val) {
                          setModalState(() => isMember = val);
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () async {
                          if (nameController.text.trim().isEmpty || emailController.text.trim().isEmpty) {
                            _showSnackBar('Name and Email are required', isError: true);
                            return;
                          }
                          Navigator.pop(context);
                          bool ok = await _apiService.addOrUpdateCustomer(
                            ownerEmail: widget.ownerEmail,
                            fullName: nameController.text.trim(),
                            email: emailController.text.trim(),
                            phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                            isMember: isMember,
                          );
                          if (ok) {
                            _showSnackBar(existingCustomer == null ? 'Customer registered!' : 'Customer updated!');
                            _loadData();
                          } else {
                            _showSnackBar('Failed to save customer', isError: true);
                          }
                        },
                        child: Text(
                          existingCustomer == null ? 'Save Customer' : 'Update Customer',
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteCustomer(CustomerModel customer) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove Customer?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to remove ${customer.fullName} from your customer directory?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      bool ok = await _apiService.deleteCustomer(customer.id);
      if (ok) {
        _showSnackBar('Customer removed');
        _loadData();
      } else {
        _showSnackBar('Failed to delete customer', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    int totalMembers = _customers.where((c) => c.isMember).length;
    int rewardsEarned = _customers.where((c) => c.stampCount >= 9).length;

    return Scaffold(
      backgroundColor: AppColors.creamWhite,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        elevation: 0,
        title: Text(
          'Customer & Loyalty Hub',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accentLime,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Customers Directory'),
            Tab(text: 'Member Discount & Rules'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCustomerDirectoryTab(totalMembers, rewardsEarned),
                _buildLoyaltySettingsTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryGreen,
        onPressed: () => _showAddEditCustomerModal(),
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: Text('Register Customer', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Widget _buildCustomerDirectoryTab(int totalMembers, int rewardsEarned) {
    return Column(
      children: [
        // Summary Stats Banner
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Total Customers',
                  value: '${_customers.length}',
                  icon: Icons.people_outline,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard(
                  title: 'VIP Members',
                  value: '$totalMembers',
                  icon: Icons.verified_user_outlined,
                  color: const Color(0xFF1E88E5),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard(
                  title: 'Ready for Free 10th',
                  value: '$rewardsEarned',
                  icon: Icons.card_giftcard,
                  color: Colors.amber.shade700,
                ),
              ),
            ],
          ),
        ),

        // Search Field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search customer name or email...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // Customer List
        Expanded(
          child: _filteredCustomers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_outline, size: 60, color: Colors.black26),
                      const SizedBox(height: 10),
                      Text(
                        'No customers found',
                        style: GoogleFonts.outfit(fontSize: 16, color: Colors.black54),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Click "Register Customer" to add full name & email.',
                        style: GoogleFonts.outfit(fontSize: 12, color: Colors.black38),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80),
                  itemCount: _filteredCustomers.length,
                  itemBuilder: (context, index) {
                    final c = _filteredCustomers[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 1.5,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: AppColors.primaryGreen.withOpacity(0.1),
                                      child: Text(
                                        c.fullName.isNotEmpty ? c.fullName[0].toUpperCase() : '?',
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryGreen,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c.fullName,
                                          style: GoogleFonts.outfit(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.richBlack,
                                          ),
                                        ),
                                        Text(
                                          c.email,
                                          style: GoogleFonts.outfit(fontSize: 12, color: Colors.black54),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: c.isMember ? AppColors.accentLime.withOpacity(0.3) : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    c.isMember ? 'VIP Member' : 'Regular',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: c.isMember ? AppColors.primaryGreen : Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const Divider(height: 20),

                            // Stamp counter row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const PickleballIcon(size: 16, color: AppColors.primaryGreen),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Loyalty Stamps: ${c.stampCount} / 10',
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.richBlack,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  'Bookings: ${c.totalCompletedBookings}',
                                  style: GoogleFonts.outfit(fontSize: 12, color: Colors.black54),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            // Mini Stamp progress indicator bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (c.stampCount / 10.0).clamp(0.0, 1.0),
                                backgroundColor: Colors.grey.shade200,
                                color: c.stampCount >= 9 ? Colors.amber : AppColors.primaryGreen,
                                minHeight: 6,
                              ),
                            ),

                            const SizedBox(height: 10),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  icon: const Icon(Icons.edit, size: 16),
                                  label: const Text('Edit'),
                                  onPressed: () => _showAddEditCustomerModal(existingCustomer: c),
                                ),
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                                  label: const Text('Remove', style: TextStyle(color: Colors.redAccent)),
                                  onPressed: () => _deleteCustomer(c),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 10, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildLoyaltySettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Member Pricing Settings
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.local_offer_rounded, color: AppColors.primaryGreen),
                    const SizedBox(width: 10),
                    Text(
                      'Special Member Pricing Rate',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Set the default discount rate automatically unlocked by registered VIP members during checkout.',
                  style: GoogleFonts.outfit(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 16),

                // Discount Type Selector
                DropdownButtonFormField<String>(
                  value: _discountType,
                  decoration: InputDecoration(
                    labelText: 'Discount Calculation Method',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'PERCENTAGE',
                      child: Text('Percentage Discount (e.g. 20% OFF)'),
                    ),
                    DropdownMenuItem(
                      value: 'FIXED_PRICE',
                      child: Text('Fixed Hourly Rate (e.g. \$15.00 / hr)'),
                    ),
                    DropdownMenuItem(
                      value: 'DISCOUNT_AMOUNT',
                      child: Text('Fixed Discount Amount (e.g. \$5.00 OFF)'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _discountType = val);
                  },
                ),

                const SizedBox(height: 14),

                TextField(
                  controller: _discountValueController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: _discountType == 'PERCENTAGE'
                        ? 'Discount Percentage (%)'
                        : (_discountType == 'FIXED_PRICE' ? 'Member Hourly Rate (\$' : 'Discount Amount (\$'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Section 2: 10th Transaction Free Milestone Rule
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.stars_rounded, color: Colors.amber),
                    const SizedBox(width: 10),
                    Text(
                      '10th Transaction Free Milestone',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'When enabled, members accumulate 1 stamp per completed booking. On their 10th booking, the session fee drops to \$0.00 and stamps automatically reset to 0.',
                  style: GoogleFonts.outfit(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: Text(
                    'Enable 10th Transaction Free Reward',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                  ),
                  activeColor: AppColors.primaryGreen,
                  value: _freeRewardEnabled,
                  onChanged: (val) => setState(() => _freeRewardEnabled = val),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Stamp Card Demo Preview Widget
          Text(
            'Member Stamp Card Preview:',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.richBlack),
          ),
          const SizedBox(height: 8),
          const LoyaltyStampCardWidget(
            stampCount: 9,
            milestoneTarget: 10,
            courtOwnerName: 'Your Court VIP Rewards',
          ),

          const SizedBox(height: 24),

          // Save Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.save_rounded, color: Colors.white),
              label: Text(
                'Save Loyalty Settings',
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              onPressed: _saveLoyaltySettings,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

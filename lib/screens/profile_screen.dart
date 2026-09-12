import 'package:flutter_project/theme/app_colors.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'login_screen.dart';
import '../services/api_service.dart';

import '../models/customer_model.dart';
import '../widgets/loyalty_stamp_card_widget.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _gcashController = TextEditingController();
  final _paymayaController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _paymentInstructionsController = TextEditingController();
  String? _paymentQrUrl;
  bool _isUploadingQr = false;
  bool _isOwner = false;
  int? _userId;
  bool _isLoading = true;
  List<CustomerModel> _loyaltyRecords = [];
  bool _isLoadingLoyalty = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    if (userStr != null) {
      final userObj = json.decode(userStr);
      _userId = userObj['id'];
      _isOwner = userObj['role'] == 'owner' || userObj['role'] == 'court_owner';
      _nameController.text = userObj['full_name'] ?? '';
      _emailController.text = userObj['email'] ?? '';
      _phoneController.text = userObj['phone'] ?? '';
      _addressController.text = userObj['address'] ?? '';
      _gcashController.text = userObj['gcash_number'] ?? '';
      _paymayaController.text = userObj['paymaya_number'] ?? userObj['maya_number'] ?? '';
      _bankAccountController.text = userObj['bank_account'] ?? userObj['bank_account_number'] ?? '';
      _bankNameController.text = userObj['bank_account_name'] ?? userObj['bank_name'] ?? '';
      _paymentInstructionsController.text = userObj['payment_instructions'] ?? userObj['instructions'] ?? '';
      _paymentQrUrl = userObj['qr_code_url'] ?? userObj['payment_qr_url'] ?? userObj['qr_code'];
    }
    setState(() => _isLoading = false);
    if (_emailController.text.trim().isNotEmpty) {
      _fetchLoyaltyRecords();
    }
  }

  Future<void> _pickAndUploadQrCode(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 90,
      );

      if (pickedFile != null) {
        setState(() => _isUploadingQr = true);
        final String? uploadedUrl = await ApiService().uploadImageToCloudinary(pickedFile);
        setState(() => _isUploadingQr = false);

        if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
          setState(() {
            _paymentQrUrl = uploadedUrl;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment QR Code uploaded to Cloudinary successfully!'),
              backgroundColor: AppColors.primaryGreen,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload QR Code image to Cloudinary.'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      setState(() => _isUploadingQr = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting QR Code: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showQrSourcePicker() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Upload Payment QR Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.camera_alt, color: AppColors.primaryGreen),
                title: Text('Take Photo with Camera'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadQrCode(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: AppColors.primaryGreen),
                title: Text('Choose from Photo Gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadQrCode(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _fetchLoyaltyRecords() async {
    if (_emailController.text.trim().isEmpty) return;
    setState(() => _isLoadingLoyalty = true);
    final records = await ApiService().fetchAllCustomerLoyalty(_emailController.text.trim());
    if (mounted) {
      setState(() {
        _loyaltyRecords = records;
        _isLoadingLoyalty = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    if (userStr != null) {
      final userObj = json.decode(userStr);
      userObj['full_name'] = _nameController.text;
      userObj['email'] = _emailController.text;
      userObj['phone'] = _phoneController.text;
      userObj['address'] = _addressController.text;
      if (_isOwner) {
        userObj['gcash_number'] = _gcashController.text;
        userObj['paymaya_number'] = _paymayaController.text;
        userObj['bank_account'] = _bankAccountController.text;
        userObj['bank_account_name'] = _bankNameController.text;
        userObj['payment_instructions'] = _paymentInstructionsController.text;
        userObj['qr_code_url'] = _paymentQrUrl;
        userObj['payment_qr_url'] = _paymentQrUrl;
      }
      await prefs.setString('user', json.encode(userObj));
    }
    
    if (_userId != null) {
      final profileData = {
        'full_name': _nameController.text,
        'email': _emailController.text,
        'phone_number': _phoneController.text,
        'gcash_number': _gcashController.text,
        'paymaya_number': _paymayaController.text,
        'bank_account': _bankAccountController.text,
        'bank_account_name': _bankNameController.text,
        'bank_name': _bankNameController.text,
        'payment_instructions': _paymentInstructionsController.text,
        'qr_code_url': _paymentQrUrl,
        'payment_qr_url': _paymentQrUrl,
      };
      await ApiService().updateUserProfile(_userId!, profileData);
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Profile and payment details saved!'), backgroundColor: AppColors.primaryGreen),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamWhite,
      appBar: AppBar(
        title: Text('Edit Profile', style: TextStyle(color: AppColors.richBlack, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.richBlack),
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: AppColors.richBlack))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Color(0xFFFBFBF5),
                      child: Icon(Icons.person, size: 40, color: AppColors.richBlack),
                    ),
                  ),
                  SizedBox(height: 24),

                  // --- MY REWARDS & LOYALTY STAMPS SECTION ---
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.stars_rounded, color: Colors.amber, size: 22),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'My Rewards & Loyalty Stamps',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.richBlack),
                                  ),
                                  Text(
                                    'Earn 1 stamp per booking. 10th session is FREE!',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.refresh, size: 18, color: Colors.grey.shade600),
                              onPressed: _fetchLoyaltyRecords,
                              tooltip: 'Refresh Stamps',
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_isLoadingLoyalty)
                          const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                        else if (_loyaltyRecords.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.card_giftcard_rounded, color: AppColors.primaryGreen, size: 24),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'No stamps yet. Book your first court session to start earning loyalty stamps toward your FREE 10th session!',
                                    style: TextStyle(fontSize: 12, color: AppColors.richBlack.withOpacity(0.8)),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Column(
                            children: _loyaltyRecords.map((rec) {
                              return LoyaltyStampCardWidget(
                                stampCount: rec.stampCount,
                                courtOwnerName: rec.ownerEmail.isNotEmpty ? 'Venue (${rec.ownerEmail})' : 'Court Loyalty',
                                isMember: rec.isMember,
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),

                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (val) => val == null || !val.contains('@') ? 'Invalid email' : null,
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone / Viber Number (Optional)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      labelText: 'Address (Optional)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: Icon(Icons.home_outlined),
                    ),
                  ),
                  if (_isOwner) ...[
                    SizedBox(height: 24),
                    Text('Court Owner Payment Settings & QR Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.richBlack)),
                    SizedBox(height: 4),
                    Text('Upload your payment QR code (hosted on Cloudinary) and enter payment details shown to players during checkout.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    SizedBox(height: 16),
                    
                    // Payment QR Code Card Container
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: Offset(0, 3)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.qr_code_2, color: AppColors.primaryGreen, size: 22),
                              SizedBox(width: 8),
                              Text('Official Payment QR Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                          SizedBox(height: 12),
                          if (_isUploadingQr) ...[
                            Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                children: [
                                  CircularProgressIndicator(color: AppColors.primaryGreen),
                                  SizedBox(height: 10),
                                  Text('Uploading QR Code to Cloudinary...', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                                ],
                              ),
                            ),
                          ] else if (_paymentQrUrl != null && _paymentQrUrl!.trim().isNotEmpty) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                _paymentQrUrl!,
                                height: 180,
                                width: 180,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 150,
                                  width: 150,
                                  color: Colors.grey.shade200,
                                  child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
                                ),
                              ),
                            ),
                            SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  icon: Icon(Icons.edit, size: 16, color: AppColors.primaryGreen),
                                  label: Text('Change QR Code', style: TextStyle(fontSize: 12, color: AppColors.primaryGreen)),
                                  onPressed: _showQrSourcePicker,
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: AppColors.primaryGreen),
                                  ),
                                ),
                                SizedBox(width: 12),
                                OutlinedButton.icon(
                                  icon: Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                  label: Text('Remove', style: TextStyle(fontSize: 12, color: Colors.red)),
                                  onPressed: () {
                                    setState(() {
                                      _paymentQrUrl = '';
                                    });
                                  },
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: Colors.red.shade300),
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            InkWell(
                              onTap: _showQrSourcePicker,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                height: 130,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGreen.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.primaryGreen.withOpacity(0.3), style: BorderStyle.solid),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.cloud_upload_outlined, color: AppColors.primaryGreen, size: 36),
                                    SizedBox(height: 8),
                                    Text('Upload Payment QR Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryGreen)),
                                    SizedBox(height: 4),
                                    Text('Tap to select image (Cloudinary hosted)', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _gcashController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'GCash Number',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: Icon(Icons.account_balance_wallet_outlined, color: Colors.blue.shade700),
                        hintText: 'e.g. 09171234567',
                      ),
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _paymayaController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'PayMaya / Maya Number',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: Icon(Icons.account_balance_wallet_outlined, color: Colors.green.shade700),
                        hintText: 'e.g. 09181234567',
                      ),
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _bankNameController,
                      decoration: InputDecoration(
                        labelText: 'Bank Name (Optional)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: Icon(Icons.account_balance_outlined, color: AppColors.richBlack),
                        hintText: 'e.g. BDO, BPI, UnionBank, Metrobank',
                      ),
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _bankAccountController,
                      decoration: InputDecoration(
                        labelText: 'Bank Account Number / Holder',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: Icon(Icons.badge_outlined, color: AppColors.richBlack),
                        hintText: 'e.g. 1234-5678-90 (Juan Dela Cruz)',
                      ),
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _paymentInstructionsController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Payment Instructions / Notes for Players',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: Icon(Icons.note_alt_outlined, color: AppColors.richBlack),
                        hintText: 'e.g. Please send payment reference screenshot via Viber/WhatsApp after paying.',
                      ),
                    ),
                  ],
                  SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _saveProfile,
                    child: Text('Save Changes'),
                  ),
                  SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('user');
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => LoginScreen()),
                        (Route<dynamic> route) => false,
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.grey.shade400),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                    ),
                    child: Text('Log Out', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                  )
                ],
              ),
            ),
          ),
    );
  }
}

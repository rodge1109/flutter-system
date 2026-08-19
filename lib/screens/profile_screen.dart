import 'package:flutter_project/theme/app_colors.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import '../services/api_service.dart';

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
  bool _isOwner = false;
  int? _userId;
  bool _isLoading = true;

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
      _paymayaController.text = userObj['paymaya_number'] ?? '';
      _bankAccountController.text = userObj['bank_account'] ?? '';
      _bankNameController.text = userObj['bank_account_name'] ?? '';
    }
    setState(() => _isLoading = false);
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
      };
      await ApiService().updateUserProfile(_userId!, profileData);
    }
    
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
                  SizedBox(height: 32),
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
                    Text('Payment Details (For Court Owners)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _gcashController,
                      decoration: InputDecoration(
                        labelText: 'GCash Number',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _paymayaController,
                      decoration: InputDecoration(
                        labelText: 'PayMaya Number',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _bankAccountController,
                      decoration: InputDecoration(
                        labelText: 'Bank Account Number',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: Icon(Icons.account_balance_outlined),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _bankNameController,
                      decoration: InputDecoration(
                        labelText: 'Bank Account Name',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: Icon(Icons.badge_outlined),
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

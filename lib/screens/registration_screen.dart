import 'package:flutter_project/theme/app_colors.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';
import 'owner_dashboard_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

class RegistrationScreen extends StatefulWidget {
  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  String _selectedRole = 'user';
  
  final _apiService = ApiService();
  bool _isLoading = false;
  bool _agreedToTerms = false;

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Court Owner Terms of Service', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('1. Service Charge', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 4),
                Text('By using the Picklebook platform as a court owner, you agree that a 6.5% service charge of the net amount of rent collected for court bookings and open plays will be deducted by Picklebook as a platform fee.'),
                SizedBox(height: 16),
                Text('2. Court Accuracy and Maintenance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 4),
                Text('Owners are responsible for ensuring that all court information, availability, and pricing listed on the app are accurate and up-to-date. The physical court must be maintained in a safe and playable condition.'),
                SizedBox(height: 16),
                Text('3. Payments and Payouts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 4),
                Text('Payouts of the net rental amount (after the 6.5% service charge) will be processed according to our standard payout schedule. You are responsible for providing accurate payout details.'),
                SizedBox(height: 16),
                Text('4. Cancellations and Refunds', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 4),
                Text('Cancellations by players will be handled according to the refund policy selected by you. If you cancel a booking, you must provide a full refund to the player.'),
                SizedBox(height: 16),
                Text('5. Liability', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 4),
                Text('Picklebook acts solely as a booking platform. Court owners assume all liability for incidents, injuries, or disputes occurring at their facilities.'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        );
      }
    );
  }

  void _register() async {
    if (_fullNameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    if (_selectedRole == 'court_owner' && !_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You must agree to the Terms of Service to register as a court owner')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final result = await _apiService.registerUser({
      'fullName': _fullNameController.text.trim(),
      'email': _emailController.text.trim(),
      'phoneNumber': _phoneController.text.trim(),
      'password': _passwordController.text,
      'role': _selectedRole,
    });
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      if (result['user'] != null && result['user']['role'] == 'court_owner') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => OwnerDashboardScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DashboardScreen()),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Registration failed')),
      );
    }
  }

  void _googleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn(
        clientId: '791853418225-nnsmvmfnabhqlevkevbp8549mccha2he.apps.googleusercontent.com',
      ).signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final token = googleAuth.idToken;
      if (token != null) {
        final result = await _apiService.googleSignIn(token, role: _selectedRole);
        if (result['success']) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => result['user']['role'] == 'court_owner' ? OwnerDashboardScreen() : DashboardScreen()
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'])));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Google Sign In failed: $e')));
    }
    setState(() => _isLoading = false);
  }

  void _facebookSignIn() async {
    setState(() => _isLoading = true);
    try {
      final LoginResult fbResult = await FacebookAuth.instance.login();
      if (fbResult.status == LoginStatus.success) {
        final token = fbResult.accessToken!.tokenString;
        final result = await _apiService.facebookSignIn(token, role: _selectedRole);
        if (result['success']) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => result['user']['role'] == 'court_owner' ? OwnerDashboardScreen() : DashboardScreen()
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'])));
        }
      } else if (fbResult.status == LoginStatus.cancelled) {
        // cancelled
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Facebook Sign In failed: ${fbResult.message}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Facebook Sign In failed: $e')));
    }
    setState(() => _isLoading = false);
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamWhite,
      appBar: AppBar(
        title: Text('Sign Up', style: TextStyle(color: AppColors.richBlack, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.richBlack),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 10),
            Text(
              'Create an Account',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.richBlack),
            ),
            SizedBox(height: 8),
            Text(
              'Join Picklebook today!',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            SizedBox(height: 24),
            Text(
              'Register as...',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500, letterSpacing: 0.3),
            ),
            SizedBox(height: 8),
            Stack(
              children: [
                // Background track
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                ),
                // Sliding pill
                AnimatedAlign(
                  duration: Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  alignment: _selectedRole == 'user' ? Alignment.centerLeft : Alignment.centerRight,
                  child: FractionallySizedBox(
                    widthFactor: 0.52,
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen,
                        borderRadius: BorderRadius.circular(50),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryGreen.withAlpha(80),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Labels row
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedRole = 'user'),
                        child: SizedBox(
                          height: 48,
                          child: Center(
                            child: Text(
                              'User',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: _selectedRole == 'user' ? AppColors.softWhite : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedRole = 'court_owner'),
                        child: SizedBox(
                          height: 48,
                          child: Center(
                            child: Text(
                              'Court Owner',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: _selectedRole == 'court_owner' ? AppColors.softWhite : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 24),
            
            _buildTextField(_fullNameController, 'Full Name', Icons.person_outline),
            SizedBox(height: 16),
            _buildTextField(_emailController, 'Email Address', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
            SizedBox(height: 16),
            _buildTextField(_phoneController, 'Mobile Number', Icons.phone_outlined, keyboardType: TextInputType.phone),
            SizedBox(height: 16),
            _buildTextField(_passwordController, 'Password', Icons.lock_outline, obscureText: true),
            SizedBox(height: 16),
            _buildTextField(_confirmPasswordController, 'Confirm Password', Icons.lock_outline, obscureText: true),
            
            if (_selectedRole == 'court_owner') ...[
              SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: _agreedToTerms,
                      activeColor: AppColors.primaryGreen,
                      onChanged: (val) {
                        setState(() {
                          _agreedToTerms = val ?? false;
                        });
                      },
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: _showTermsDialog,
                      child: RichText(
                        text: TextSpan(
                          text: 'I have read and agree to the ',
                          style: TextStyle(fontFamily: 'Poppins', color: AppColors.richBlack, fontSize: 14),
                          children: [
                            TextSpan(
                              text: 'Terms of Service',
                              style: TextStyle(fontFamily: 'Poppins', color: AppColors.primaryGreen, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _register,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isLoading
                  ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: AppColors.softWhite))
                  : Text('Create Account', style: TextStyle(color: AppColors.softWhite, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('OR', style: TextStyle(color: Colors.grey)),
                ),
                Expanded(child: Divider(color: Colors.grey)),
              ],
            ),
            SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _googleSignIn,
                icon: Icon(Icons.g_mobiledata, size: 32),
                label: Text('Continue with Google', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.black87, backgroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade300)),
                ),
              ),
            ),
            SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _facebookSignIn,
                icon: Icon(Icons.facebook, size: 28),
                label: Text('Continue with Facebook', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white, backgroundColor: Color(0xFF1877F2),
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                );
              },
              child: Text(
                "Already have an account? Sign In",
                style: TextStyle(color: AppColors.richBlack, decoration: TextDecoration.underline, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool obscureText = false, TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.richBlack),
        prefixIcon: Icon(icon, color: AppColors.richBlack),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: AppColors.primaryGreen, width: 2),
        ),
      ),
    );
  }
}

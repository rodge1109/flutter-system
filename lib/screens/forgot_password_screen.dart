import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/api_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _otpSent = false;
  
  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please enter your email')));
      return;
    }
    
    setState(() => _isLoading = true);
    final result = await _apiService.requestPasswordReset(email);
    setState(() => _isLoading = false);
    
    if (result['success'] == true) {
      setState(() => _otpSent = true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('OTP sent to your email')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? 'Failed to send OTP')));
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();
    final newPassword = _passwordController.text;
    
    if (otp.isEmpty || newPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please fill all fields')));
      return;
    }
    
    setState(() => _isLoading = true);
    final result = await _apiService.resetPassword(email, otp, newPassword);
    setState(() => _isLoading = false);
    
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Password reset successfully!')));
      Navigator.pop(context); // Go back to login
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? 'Failed to reset password')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: AppColors.creamWhite,
        appBar: AppBar(
          title: Text('Forgot Password', style: TextStyle(color: AppColors.richBlack, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: AppColors.richBlack),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 40),
                  Icon(Icons.lock_reset, size: 80, color: AppColors.primaryGreen),
                  SizedBox(height: 40),
                  
                  if (!_otpSent) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.creamWhite.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Enter your email address and we will send you a 6-digit OTP to reset your password.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.richBlack, fontSize: 16),
                      ),
                    ),
                    SizedBox(height: 24),
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        labelStyle: TextStyle(color: AppColors.richBlack),
                        prefixIcon: Icon(Icons.email_outlined, color: AppColors.richBlack),
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
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: AppColors.richBlack),
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _sendOtp,
                      child: _isLoading 
                          ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: AppColors.softWhite))
                          : Text('Send OTP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.softWhite)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.creamWhite.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Enter the OTP sent to ${_emailController.text} and your new password.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.richBlack, fontSize: 16),
                      ),
                    ),
                    SizedBox(height: 24),
                    TextField(
                      controller: _otpController,
                      decoration: InputDecoration(
                        labelText: '6-Digit OTP',
                        labelStyle: TextStyle(color: AppColors.richBlack),
                        prefixIcon: Icon(Icons.security, color: AppColors.richBlack),
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
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: AppColors.richBlack),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        labelStyle: TextStyle(color: AppColors.richBlack),
                        prefixIcon: Icon(Icons.lock_outline, color: AppColors.richBlack),
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
                      style: TextStyle(color: AppColors.richBlack),
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _resetPassword,
                      child: _isLoading 
                          ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: AppColors.softWhite))
                          : Text('Reset Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.softWhite)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
  }
}

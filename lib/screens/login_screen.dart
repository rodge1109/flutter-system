import 'package:flutter_project/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';
import 'registration_screen.dart';
import 'forgot_password_screen.dart';
import 'dashboard_screen.dart';
import 'owner_dashboard_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import '../services/fcm_service.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiService = ApiService();
  final LocalAuthentication auth = LocalAuthentication();
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  bool _isLoading = false;
  bool _isBiometricAvailable = false;
  bool _rememberMe = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    _checkBiometrics();
  }

  Future<void> _loadSavedCredentials() async {
    String? remember = await secureStorage.read(key: 'rememberMe');
    if (remember == 'true') {
      String? savedEmail = await secureStorage.read(key: 'email');
      String? savedPassword = await secureStorage.read(key: 'password');
      if (savedEmail != null && savedPassword != null && mounted) {
        setState(() {
          _rememberMe = true;
          _emailController.text = savedEmail;
          _passwordController.text = savedPassword;
        });
      }
    }
  }

  Future<void> _checkBiometrics() async {
    if (kIsWeb) return; // Biometrics not supported natively on web for this plugin
    try {
      final bool canCheckBiometrics = await auth.canCheckBiometrics;
      final bool isDeviceSupported = await auth.isDeviceSupported();
      
      String? savedEmail = await secureStorage.read(key: 'email');
      String? savedPassword = await secureStorage.read(key: 'password');
      
      if (mounted) {
        setState(() {
          _isBiometricAvailable = (canCheckBiometrics || isDeviceSupported) && 
                                  savedEmail != null && savedPassword != null;
        });
      }
    } catch (e) {
      print("Biometrics error: $e");
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    if (kIsWeb) return;
    try {
      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Please authenticate to log in',
        options: const AuthenticationOptions(biometricOnly: true),
      );
      if (didAuthenticate) {
        String? email = await secureStorage.read(key: 'email');
        String? password = await secureStorage.read(key: 'password');
        if (email != null && password != null) {
          _emailController.text = email;
          _passwordController.text = password;
          _login();
        }
      }
    } catch (e) {
      print("Authentication error: $e");
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
        final result = await _apiService.googleSignIn(token);
        if (result['success']) {
          await secureStorage.write(key: 'email', value: result['user']['email']);
          if (result['user'] != null && result['user']['role'] == 'court_owner') {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => OwnerDashboardScreen()));
          } else {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => DashboardScreen()));
          }
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
        final result = await _apiService.facebookSignIn(token);
        if (result['success']) {
          await secureStorage.write(key: 'email', value: result['user']['email']);
          if (result['user'] != null && result['user']['role'] == 'court_owner') {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => OwnerDashboardScreen()));
          } else {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => DashboardScreen()));
          }
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

  void _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final result = await _apiService.loginUser(
      _emailController.text.trim(),
      _passwordController.text,
    );
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      if (_rememberMe) {
        await secureStorage.write(key: 'rememberMe', value: 'true');
        await secureStorage.write(key: 'email', value: _emailController.text.trim());
        await secureStorage.write(key: 'password', value: _passwordController.text);
      } else {
        await secureStorage.write(key: 'rememberMe', value: 'false');
        await secureStorage.delete(key: 'email');
        await secureStorage.delete(key: 'password');
      }
      
      // Initialize Push Notifications
      FcmService().init(_emailController.text.trim());

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
        SnackBar(content: Text(result['message'] ?? 'Login failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final trueScreenHeight = mq.size.height + mq.viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top Wavy Image & Back Button
            Stack(
              children: [
                ClipPath(
                  clipper: WavyHeaderClipper(),
                  child: Container(
                    height: trueScreenHeight * 0.45,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/splash.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 50,
                  left: 20,
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 20,
                    child: IconButton(
                      icon: Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.primaryGreen),
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ],
            ),
            
            // Texts
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  Text(
                    'Welcome Back',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Login to your account',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  SizedBox(height: 40),
                  
                  // Email Field
                  TextField(
                    controller: _emailController,
                    style: TextStyle(color: AppColors.richBlack),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Color(0xFFF2F5F0), // Light green matching mockup
                      hintText: 'Email Address',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      prefixIcon: Icon(Icons.person, color: AppColors.primaryGreen),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(color: AppColors.primaryGreen, width: 1.5),
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  SizedBox(height: 16),
                  
                  // Password Field
                  TextField(
                    controller: _passwordController,
                    style: TextStyle(color: AppColors.richBlack),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Color(0xFFF2F5F0),
                      hintText: 'Password',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      prefixIcon: Icon(Icons.lock, color: AppColors.primaryGreen),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          color: AppColors.primaryGreen,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(color: AppColors.primaryGreen, width: 1.5),
                      ),
                    ),
                    obscureText: _obscurePassword,
                  ),
                  SizedBox(height: 16),
                  
                  // Remember me & Forgot Password
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: _rememberMe,
                              onChanged: (val) {
                                setState(() {
                                  _rememberMe = val ?? false;
                                });
                              },
                              activeColor: AppColors.primaryGreen,
                              shape: CircleBorder(),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text('Remember Me', style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500)),
                        ],
                      ),
                      TextButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ForgotPasswordScreen())),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Forgot Password ?',
                          style: TextStyle(
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 40),
                  
                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              'Login',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  
                  if (_isBiometricAvailable) ...[
                    SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _authenticateWithBiometrics,
                        icon: Icon(Icons.fingerprint, color: AppColors.primaryGreen),
                        label: Text('Login with Biometrics', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.primaryGreen),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                    ),
                  ],
                  
                  SizedBox(height: 30),
                  
                  // Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have account? ",
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => RegistrationScreen()),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          "Sign up",
                          style: TextStyle(
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WavyHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 20);
    
    // Smooth asymmetric S-curve matching the mockup
    var cp1 = Offset(size.width * 0.3, size.height + 30); // Convex bulge on the left
    var cp2 = Offset(size.width * 0.7, size.height - 120); // Concave sweep up on the right
    var endPoint = Offset(size.width, size.height - 100); // End high on the right
    
    path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, endPoint.dx, endPoint.dy);
    
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

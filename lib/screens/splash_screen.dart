import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
import '../theme/app_colors.dart';
class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    
    _controller.forward();

    Timer(Duration(seconds: 3), _checkAuthStatus);
  }

  PageRouteBuilder _createCornerTransition(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Starts from bottom-right corner and slides up/left
        const begin = Offset(1.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;
        
        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 700),
    );
  }

  Future<void> _checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Capture Deep Link
    final openplayId = Uri.base.queryParameters['openplay'];
    if (openplayId != null && openplayId.isNotEmpty) {
      await prefs.setString('pending_openplay', openplayId);
    }
    
    final user = prefs.getString('user');
    
    if (user != null) {
      Navigator.of(context).pushReplacement(
        _createCornerTransition(DashboardScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        _createCornerTransition(LoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Typographic logo with ® right above second K
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Image.asset('assets/logo.png', height: 120, filterQuality: FilterQuality.high, isAntiAlias: true),
                ),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentLime),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'screens/splash_screen.dart';
import 'screens/deep_link_handler_screen.dart';
import 'screens/booking_confirmation_screen.dart';
import 'screens/court_pass_screen.dart';
import 'theme/app_colors.dart';

import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    usePathUrlStrategy();
    await FacebookAuth.instance.webAndDesktopInitialize(
      appId: '1788135815163201',
      cookie: true,
      xfbml: true,
      version: 'v16.0',
    );
  }
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print('Failed to initialize Firebase: $e');
  }
  runApp(const PicklebookApp());
}

class PicklebookApp extends StatelessWidget {
  const PicklebookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Picklebook',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.creamWhite,
        primaryColor: AppColors.primaryGreen,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primaryGreen, 
          secondary: AppColors.accentLime,
          surface: AppColors.softWhite,
          error: Colors.redAccent,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.richBlack,
          elevation: 0,
        ),
        fontFamily: 'Poppins',
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentLime,
            foregroundColor: AppColors.richBlack,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 9.5),
            textStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
              height: 1.2,
            ),
            elevation: 0,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.softWhite,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.stoneGray, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.stoneGray, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          labelStyle: const TextStyle(color: AppColors.stoneGray),
          hintStyle: const TextStyle(color: AppColors.stoneGray),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontFamily: 'Poppins', fontSize: 57, fontWeight: FontWeight.w400, color: AppColors.richBlack, letterSpacing: -1.5, height: 1.2),
          displayMedium: TextStyle(fontFamily: 'Poppins', fontSize: 45, fontWeight: FontWeight.w400, color: AppColors.richBlack, letterSpacing: -1.0, height: 1.2),
          displaySmall: TextStyle(fontFamily: 'Poppins', fontSize: 36, fontWeight: FontWeight.w400, color: AppColors.richBlack, letterSpacing: -0.5, height: 1.2),
          headlineLarge: TextStyle(fontFamily: 'Poppins', fontSize: 32, fontWeight: FontWeight.w600, color: AppColors.richBlack, letterSpacing: -0.5, height: 1.2),
          headlineMedium: TextStyle(fontFamily: 'Poppins', fontSize: 28, fontWeight: FontWeight.w600, color: AppColors.richBlack, letterSpacing: -0.3, height: 1.2),
          headlineSmall: TextStyle(fontFamily: 'Poppins', fontSize: 24, fontWeight: FontWeight.w500, color: AppColors.richBlack, letterSpacing: -0.2, height: 1.2),
          titleLarge: TextStyle(fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.richBlack, letterSpacing: -0.2, height: 1.2),
          titleMedium: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.richBlack, letterSpacing: 0, height: 1.2),
          titleSmall: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.richBlack, letterSpacing: 0, height: 1.2),
          bodyLarge: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.stoneGray, letterSpacing: 0, height: 1.2),
          bodyMedium: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.stoneGray, letterSpacing: 0, height: 1.2),
          bodySmall: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.stoneGray, letterSpacing: 0.1, height: 1.2),
          labelLarge: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.richBlack, letterSpacing: 0, height: 1.2),
          labelMedium: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.stoneGray, letterSpacing: 0.2, height: 1.2),
          labelSmall: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.stoneGray, letterSpacing: 0.2, height: 1.2),
        ),
        useMaterial3: true,
      ),
      onGenerateRoute: (settings) {
        String routeName = settings.name ?? '';
        if (kIsWeb && (routeName.isEmpty || routeName == '/')) {
          if (Uri.base.fragment.isNotEmpty && Uri.base.fragment != '/') {
            routeName = Uri.base.fragment;
          } else if (Uri.base.pathSegments.isNotEmpty &&
              Uri.base.pathSegments.first.isNotEmpty &&
              Uri.base.pathSegments.first != 'index.html') {
            routeName = Uri.base.path;
          }
        }

        if (routeName.isNotEmpty && routeName != '/') {
          String rawName = routeName;
          if (rawName.startsWith('/#/')) {
            rawName = rawName.substring(2);
          } else if (rawName.startsWith('#/')) {
            rawName = rawName.substring(1);
          } else if (rawName.startsWith('#')) {
            rawName = rawName.substring(1);
          }
          final uri = Uri.parse(rawName);
          final segments = uri.pathSegments;

          if (segments.isNotEmpty) {
            final slug = segments[0].toLowerCase();
            if (slug == 'preview_confirmation') {
              return MaterialPageRoute(
                builder: (context) => BookingConfirmationScreen(
                  courtName: 'NHP (Soon)',
                  courtAddress: 'Brgy. Cayang, Bogo City',
                  courtImage: 'https://res.cloudinary.com/doxih7ab3/image/upload/v1784821986/queuing-system-uploads/1784821985216-132187.jpg',
                  bookingDate: DateTime(2026, 10, 29),
                  timeSlots: const ['9:00 PM'],
                  courtNumber: 'Court 1',
                  totalPaid: 350.0,
                  bookingId: 'BK-PREVIEW-123',
                  playerName: 'Alex Rivera',
                ),
              );
            }

            // Court pass / booking pass routes: /b, /b/:id, /pass/:id, /courtpass/:id
            if (slug == 'b' || slug == 'pass' || slug == 'courtpass' || slug == 'court-pass') {
              String? bookingId;
              if (segments.length > 1 && segments[1].trim().isNotEmpty) {
                bookingId = segments[1].trim();
              } else if (uri.queryParameters.containsKey('id')) {
                bookingId = uri.queryParameters['id'];
              } else if (uri.queryParameters.containsKey('bookingId')) {
                bookingId = uri.queryParameters['bookingId'];
              } else if (kIsWeb && Uri.base.queryParameters.containsKey('id')) {
                bookingId = Uri.base.queryParameters['id'];
              }

              final queryParams = uri.queryParameters.isNotEmpty
                  ? uri.queryParameters
                  : (kIsWeb && Uri.base.queryParameters.isNotEmpty ? Uri.base.queryParameters : null);

              return MaterialPageRoute(
                builder: (context) => CourtPassScreen(
                  bookingId: bookingId,
                  queryParams: queryParams,
                ),
              );
            }

            return MaterialPageRoute(
              builder: (context) => DeepLinkHandlerScreen(slug: slug),
            );
          }
        }
        return MaterialPageRoute(builder: (context) => SplashScreen());
      },
    );
  }
}

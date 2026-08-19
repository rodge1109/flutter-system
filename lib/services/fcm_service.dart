import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  String? _userEmail;

  Future<void> init(String userEmail) async {
    _userEmail = userEmail;
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized || 
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      
      String? token;
      try {
        if (kIsWeb) {
          token = await messaging.getToken(
            vapidKey: 'BA9NqIegNqdzI_jZ05EKsoJLJmp7mqv8DVIYNNd9nKEbT0Sbr0bPe6CzChE5jUK42pU2EwMx-VrhP24Hzox_eCQ',
          );
        } else {
          token = await messaging.getToken();
        }
      } catch (e) {
        print("Error getting FCM token: $e");
      }

      if (token != null) {
        print("FCM Token: $token");
        await _sendTokenToBackend(userEmail, token);
      }

      // Listen for token refreshes
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        _sendTokenToBackend(userEmail, newToken);
      });
      
      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Got a message whilst in the foreground!');
        print('Message data: ${message.data}');
        if (message.notification != null) {
          print('Message also contained a notification: ${message.notification}');
        }
      });
    }
  }

  Future<void> _sendTokenToBackend(String email, String token) async {
    final String baseUrl = kIsWeb 
        ? 'http://localhost:5000/api'
        : 'https://pickle-system.onrender.com/api';

    try {
      await http.post(
        Uri.parse('$baseUrl/user/fcm-token'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'token': token,
        }),
      );
    } catch (e) {
      print("Failed to save FCM token: $e");
    }
  }
}

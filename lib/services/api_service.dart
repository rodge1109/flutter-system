import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/service_model.dart';

class ApiService {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5001/api';
    }
    return 'https://pickle-system.onrender.com/api'; 
  }

  Future<List<ServiceModel>> fetchServices() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/booking-services'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true && data['services'] != null) {
          final List<dynamic> servicesJson = data['services'];
          return servicesJson.map((json) => ServiceModel.fromJson(json)).toList();
        }
      }
      throw Exception('Failed to load services');
    } catch (e) {
      throw Exception('Error fetching services: $e');
    }
  }

  // Future method for submitting an appointment
  Future<bool> submitAppointment(Map<String, dynamic> appointmentData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/appointments'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(appointmentData),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }
      return false;
    } catch (e) {
      print('Error submitting appointment: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> fetchOwnerEarnings(String email, {String? startDate, String? endDate}) async {
    try {
      String url = '$baseUrl/owner-earnings/${Uri.encodeComponent(email)}';
      if (startDate != null && endDate != null) {
        url += '?startDate=$startDate&endDate=$endDate';
      }
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'success': false, 'message': 'Failed to fetch owner earnings'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==================== PASALO ENDPOINTS ====================
  
  Future<bool> postForPasalo(String appointmentId, String assumePrice, String assumeNotes) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/appointments/$appointmentId/pasalo'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'assumePrice': assumePrice,
          'assumeNotes': assumeNotes,
        }),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('postForPasalo error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchPasaloCourts() async {
    try {
      final t = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(Uri.parse('$baseUrl/pasalo-courts?t=$t'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['pasaloCourts'] != null) {
          return List<Map<String, dynamic>>.from(data['pasaloCourts']);
        }
      }
      return [];
    } catch (e) {
      print('fetchPasaloCourts error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> requestPasalo(String appointmentId, String email, String name, String phone, String proofOfPayment) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/appointments/$appointmentId/accept-pasalo'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'requesterEmail': email,
          'requesterName': name,
          'requesterPhone': phone,
          'proofOfPayment': proofOfPayment,
        }),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'success': false, 'message': 'Failed to request pasalo'};
    } catch (e) {
      print('requestPasalo error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> fetchPasaloRequests(String appointmentId) async {
    try {
      final t = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(Uri.parse('$baseUrl/appointments/$appointmentId/pasalo-requests?t=$t'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['requests'] != null) {
          return List<Map<String, dynamic>>.from(data['requests']);
        }
      }
      return [];
    } catch (e) {
      print('fetchPasaloRequests error: $e');
      return [];
    }
  }

  Future<bool> approvePasaloRequest(String requestId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/pasalo-requests/$requestId/approve'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('approvePasaloRequest error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchOpenPlays(String email) async {
    try {
      final t = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(Uri.parse('$baseUrl/open-plays?email=${Uri.encodeComponent(email)}&t=$t'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['openPlays'] != null) {
          return List<Map<String, dynamic>>.from(data['openPlays']);
        }
      }
      return [];
    } catch (e) {
      print('Error fetching open plays: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> joinOpenPlay(dynamic appointmentId, String userEmail, String? proofOfPayment, [int guestCount = 0]) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/open-plays/join'));
      request.fields['appointmentId'] = appointmentId.toString();
      request.fields['userEmail'] = userEmail;
      request.fields['guestCount'] = guestCount.toString();
      
      if (proofOfPayment != null) {
        // If proof of payment is base64 string
        request.fields['proofOfPayment'] = proofOfPayment;
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      }
      
      try {
        return json.decode(response.body);
      } catch (_) {
        return {'success': false, 'message': 'Server error.'};
      }
    } catch (e) {
      print('Error joining open play: $e');
      return {'success': false, 'message': 'Network error.'};
    }
  }

  Future<bool> updateOpenPlay(int id, Map<String, dynamic> updateData) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/open-plays/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(updateData),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Error updating open play: $e');
      return false;
    }
  }
  Future<List<Map<String, dynamic>>> fetchHostedOpenPlays(String email) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/open-plays/hosted/${Uri.encodeComponent(email)}'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['openPlays'] != null) {
          return List<Map<String, dynamic>>.from(data['openPlays']);
        }
      }
      return [];
    } catch (e) {
      print('Error fetching hosted open plays: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchOpenPlayParticipants(dynamic appointmentId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/open-plays/$appointmentId/participants'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['participants'] != null) {
          return List<Map<String, dynamic>>.from(data['participants']);
        }
      }
      return [];
    } catch (e) {
      print('Error fetching open play participants: $e');
      return [];
    }
  }

  Future<bool> updateOpenPlayParticipantStatus(String userEmail, String appointmentIds, String status) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/open-plays/participants/status'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userEmail': userEmail,
          'appointmentIds': appointmentIds,
          'status': status,
        }),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Error updating participant status: $e');
      return false;
    }
  }

  Future<Map<String, List<String>>> fetchAvailableSlots(String date, String serviceType) async {
    try {
      final t = DateTime.now().millisecondsSinceEpoch;
      final url = Uri.parse('$baseUrl/available-slots?date=$date&serviceType=${Uri.encodeComponent(serviceType)}&t=$t');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> available = data['availableSlots'] ?? [];
          final List<dynamic> booked = data['bookedSlots'] ?? [];
          final List<dynamic> blocked = data['blockedSlots'] ?? [];
          return {
            'availableSlots': available.map((s) => s.toString()).toList(),
            'bookedSlots': booked.map((s) => s.toString()).toList(),
            'blockedSlots': blocked.map((s) => s.toString()).toList(),
          };
        }
      }
      return {'availableSlots': [], 'bookedSlots': [], 'blockedSlots': []};
    } catch (e) {
      print('Error fetching slots: $e');
      return {'availableSlots': [], 'bookedSlots': [], 'blockedSlots': []};
    }
  }

  // --- Authentication Methods ---

  Future<Map<String, dynamic>> loginUser(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', json.encode(data['user']));
        return {'success': true, 'user': data['user']};
      }
      return {'success': false, 'message': data['message'] ?? 'Login failed'};
    } catch (e) {
      print('Login error: $e');
      return {'success': false, 'message': 'Network error'};
    }
  }

  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );
      final data = json.decode(response.body);
      return data;
    } catch (e) {
      print('Forgot password error: $e');
      return {'success': false, 'message': 'Network error'};
    }
  }

  Future<Map<String, dynamic>> resetPassword(String email, String otp, String newPassword) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'otp': otp, 'newPassword': newPassword}),
      );
      final data = json.decode(response.body);
      return data;
    } catch (e) {
      print('Reset password error: $e');
      return {'success': false, 'message': 'Network error'};
    }
  }

  Future<Map<String, dynamic>> registerUser(Map<String, dynamic> userData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(userData),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', json.encode(data['user']));
        return {'success': true, 'user': data['user']};
      }
      return {'success': false, 'message': data['message'] ?? 'Registration failed'};
    } catch (e) {
      print('Registration error: $e');
      return {'success': false, 'message': 'Network error'};
    }
  }

  Future<Map<String, dynamic>> googleSignIn(String token, {String role = 'user'}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'token': token, 'role': role}),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', json.encode(data['user']));
        return {'success': true, 'user': data['user']};
      }
      return {'success': false, 'message': data['message'] ?? 'Google sign in failed'};
    } catch (e) {
      print('Google sign in error: $e');
      return {'success': false, 'message': 'Network error'};
    }
  }

  Future<Map<String, dynamic>> facebookSignIn(String token, {String role = 'user'}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/facebook'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'token': token, 'role': role}),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', json.encode(data['user']));
        return {'success': true, 'user': data['user']};
      }
      return {'success': false, 'message': data['message'] ?? 'Facebook sign in failed'};
    } catch (e) {
      print('Facebook sign in error: $e');
      return {'success': false, 'message': 'Network error'};
    }
  }

  Future<List<dynamic>> fetchUserBookings(String email) async {
    try {
      final t = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(Uri.parse('$baseUrl/user/bookings/${Uri.encodeComponent(email)}?t=$t'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['bookings'] ?? [];
        }
      }
      return [];
    } catch (e) {
      print('Fetch bookings error: $e');
      return [];
    }
  }


  Future<bool> cancelUserBooking(int bookingId, String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user/bookings/cancel'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'bookingId': bookingId,
          'email': email,
        }),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Error cancelling user booking: $e');
      return false;
    }
  }
  Future<Map<String, dynamic>> activateBookingAssistant(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user/booking-assistant'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      return json.decode(response.body);
    } catch (e) {
      print('Activate booking assistant error: $e');
      return {'success': false, 'message': 'Network error'};
    }
  }


  Future<List<dynamic>> fetchOwnerBookingsAPI(String email) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/owner/bookings/${Uri.encodeComponent(email)}'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['bookings'] ?? [];
        }
      }
      return [];
    } catch (e) {
      print('Fetch owner bookings error: $e');
      return [];
    }
  }

  Future<bool> blockCourtSlot(String ownerEmail, String courtName, String date, String time, {String? playerName}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/owner/slots/block'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'ownerEmail': ownerEmail,
          'courtName': courtName,
          'date': date,
          'time': time,
          'playerName': playerName ?? '',
        }),
      );
      final data = json.decode(response.body);
      return response.statusCode == 200 && data['success'] == true;
    } catch (e) {
      print('Error blocking slot: $e');
      return false;
    }
  }

  Future<bool> unblockCourtSlot(String courtName, String date, String time) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/owner/slots/unblock'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'courtName': courtName,
          'date': date,
          'time': time,
        }),
      );
      final data = json.decode(response.body);
      return response.statusCode == 200 && data['success'] == true;
    } catch (e) {
      print('Error unblocking slot: $e');
      return false;
    }
  }

  Future<bool> cancelCourtReservation(String courtName, String date, String time) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/owner/appointments/cancel'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'courtName': courtName,
          'date': date,
          'time': time,
        }),
      );
      final data = json.decode(response.body);
      return response.statusCode == 200 && data['success'] == true;
    } catch (e) {
      print('Error cancelling reservation: $e');
      return false;
    }
  }

  Future<String> fetchRainChance(String dateString) async {
    try {
      final url = Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=14.5995&longitude=120.9842&daily=precipitation_probability_max&timezone=auto&start_date=$dateString&end_date=$dateString');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['daily'] != null && data['daily']['precipitation_probability_max'] != null && data['daily']['precipitation_probability_max'].isNotEmpty) {
          final prob = data['daily']['precipitation_probability_max'][0];
          return prob != null ? '$prob%' : 'N/A';
        }
      }
      return 'N/A';
    } catch (e) {
      print('Weather fetch error: $e');
      return 'N/A';
    }
  }
  Future<Map<String, dynamic>> addCourt(Map<String, dynamic> courtData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/courts'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(courtData),
      );
      if (response.statusCode == 201) {
        return {'success': true};
      }
      return {'success': false, 'message': 'Failed to add court'};
    } catch (e) {
      print('Add court error: $e');
      return {'success': false, 'message': 'Network error'};
    }
  }

  Future<Map<String, dynamic>> updateCourt(dynamic id, Map<String, dynamic> courtData) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/courts/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(courtData),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'success': false, 'message': 'Failed to update court'};
    } catch (e) {
      print('Update court error: $e');
      return {'success': false, 'message': 'Network error'};
    }
  }

  Future<bool> deleteCourt(dynamic id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/courts/$id'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Delete court error: $e');
      return false;
    }
  }

  Future<List<dynamic>> fetchOwnerCourts(String email) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/courts/${Uri.encodeComponent(email)}'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['courts'] ?? [];
        }
      }
      return [];
    } catch (e) {
      print('Fetch courts error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> updateUserProfile(int id, Map<String, dynamic> profileData) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/user/profile/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(profileData),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', json.encode(data['user']));
        return {'success': true, 'user': data['user']};
      }
      return {'success': false, 'message': data['message'] ?? 'Profile update failed'};
    } catch (e) {
      print('Profile update error: $e');
      return {'success': false, 'message': 'Network error'};
    }
  }
  
  // ==================== NOTIFICATIONS ====================

  Future<List<dynamic>> fetchNotifications(String email) async {
    try {
      final t = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(Uri.parse('$baseUrl/notifications/${Uri.encodeComponent(email)}?t=$t'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['notifications'] ?? [];
        }
      }
      return [];
    } catch (e) {
      print('Fetch notifications error: $e');
      return [];
    }
  }

  Future<bool> clearNotifications(String email) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/notifications/${Uri.encodeComponent(email)}'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Clear notifications error: $e');
      return false;
    }
  }

  Future<bool> triggerBookingSummary(String email) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/user/booking-assistant/trigger/${Uri.encodeComponent(email)}'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Trigger booking summary error: $e');
      return false;
    }
  }

  Future<bool> sendNotification(String userEmail, String senderEmail, String title, String message) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/notifications'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_email': userEmail,
          'sender_email': senderEmail,
          'title': title,
          'message': message,
        }),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Send notification error: $e');
      return false;
    }
  }

  Future<bool> markNotificationAsRead(int id) async {
    try {
      final response = await http.put(Uri.parse('$baseUrl/notifications/$id/read'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Mark notification read error: $e');
      return false;
    }
  }
  Future<String> getOwnerEmailByCourt(String courtName) async {
    const String fallbackOwner = 'rodge1109@yahoo.com';
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/courts/owner-by-name?name=${Uri.encodeComponent(courtName)}'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['owner_email'] != null && (data['owner_email'] as String).isNotEmpty) {
          return data['owner_email'] as String;
        }
      }
      return fallbackOwner;
    } catch (e) {
      print('Get owner email error: $e');
      return fallbackOwner;
    }
  }

  // ==================== MESSAGING ====================

  Future<bool> sendMessage(String senderEmail, String receiverEmail, String courtName, String message) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/messages'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'senderEmail': senderEmail,
          'receiverEmail': receiverEmail,
          'courtName': courtName,
          'message': message,
        }),
      );
      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Send message error: $e');
      return false;
    }
  }

  Future<List<dynamic>> fetchInbox(String email) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/messages/inbox/${Uri.encodeComponent(email)}'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['inbox'] ?? [];
        }
      }
      return [];
    } catch (e) {
      print('Fetch inbox error: $e');
      return [];
    }
  }

  Future<List<dynamic>> fetchChatHistory(String email1, String email2) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/messages/chat/${Uri.encodeComponent(email1)}/${Uri.encodeComponent(email2)}'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['messages'] ?? [];
        }
      }
      return [];
    } catch (e) {
      print('Fetch chat history error: $e');
      return [];
    }
  }

  Future<int> fetchUnreadMessagesCount(String email) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/messages/unread/${Uri.encodeComponent(email)}'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['count'] ?? 0;
        }
      }
      return 0;
    } catch (e) {
      print('Fetch unread messages count error: $e');
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> fetchOpenChallenges(String email) async {
    try {
      final t = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(Uri.parse('$baseUrl/open-challenges?email=${Uri.encodeComponent(email)}&t=$t'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['challenges'] != null) {
          return List<Map<String, dynamic>>.from(data['challenges']);
        }
      }
      return [];
    } catch (e) {
      print('Error fetching open challenges: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> applyToChallenge(int appointmentId, String email, String name) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/challenges/apply'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'appointmentId': appointmentId,
          'challengerEmail': email,
          'challengerName': name,
        }),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to apply: $e'};
    }
  }

  Future<List<Map<String, dynamic>>> fetchChallengeRequests(int appointmentId) async {
    try {
      final t = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(Uri.parse('$baseUrl/challenges/$appointmentId/requests?t=$t'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['requests'] != null) {
          return List<Map<String, dynamic>>.from(data['requests']);
        }
      }
      return [];
    } catch (e) {
      print('Error fetching challenge requests: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> acceptChallenger(int requestId, int appointmentId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/challenges/accept'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'requestId': requestId,
          'appointmentId': appointmentId,
        }),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to accept: $e'};
    }
  }

  Future<Map<String, dynamic>> redoChallenge(int appointmentId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/challenges/redo'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'appointmentId': appointmentId,
        }),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to redo challenge: $e'};
    }
  }

  Future<String?> getAgoraToken(String channelName) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/agora/token?channelName=$channelName'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['token'];
        }
      }
      return null;
    } catch (e) {
      print('Error fetching Agora token: $e');
      return null;
    }
  }
}

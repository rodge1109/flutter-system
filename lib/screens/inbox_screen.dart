import 'package:flutter_project/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/api_service.dart';
import 'chat_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;

class InboxScreen extends StatefulWidget {
  @override
  _InboxScreenState createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final ApiService _apiService = ApiService();
  String _userEmail = '';
  List<dynamic> _inbox = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserAndInbox();
  }

  Future<void> _loadUserAndInbox() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    if (userStr != null) {
      final userObj = json.decode(userStr);
      _userEmail = userObj['email'];
      await _fetchInbox();
    }
  }

  Future<void> _fetchInbox() async {
    setState(() => _isLoading = true);
    final inboxData = await _apiService.fetchInbox(_userEmail);
    setState(() {
      _inbox = inboxData;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7F7F7),
      appBar: AppBar(
        title: Text('Messages', style: TextStyle(fontFamily: 'Poppins', color: AppColors.richBlack, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.softWhite,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.richBlack),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _inbox.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _fetchInbox,
                  child: ListView.builder(
                    itemCount: _inbox.length,
                    itemBuilder: (context, index) {
                      final item = _inbox[index];
                      final partnerEmail = item['partner_email'];
                      final partnerName = item['partner_name'] ?? partnerEmail;
                      final lastMessage = item['message'] ?? '';
                      final unreadCount = item['unread_count'] is int ? item['unread_count'] : int.tryParse(item['unread_count'].toString()) ?? 0;
                      final date = DateTime.tryParse(item['created_at'].toString()) ?? DateTime.now();

                      return Container(
                        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.softWhite,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: AppColors.richBlack.withOpacity(0.02), blurRadius: 8, offset: Offset(0, 2)),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.all(16),
                          leading: CircleAvatar(
                            radius: 28,
                            backgroundColor: AppColors.primaryGreen.withOpacity(0.1),
                            child: Text(partnerName[0].toUpperCase(), style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold, fontSize: 20)),
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  partnerName,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                timeago.format(date, locale: 'en_short'),
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    lastMessage,
                                    style: TextStyle(color: unreadCount > 0 ? AppColors.richBlack : Colors.grey.shade600, fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal),
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (unreadCount > 0)
                                  Container(
                                    margin: EdgeInsets.only(left: 8),
                                    padding: EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryGreen,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      unreadCount.toString(),
                                      style: TextStyle(color: AppColors.softWhite, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  userEmail: _userEmail,
                                  partnerEmail: partnerEmail,
                                  partnerName: partnerName,
                                ),
                              ),
                            );
                            _fetchInbox(); // Refresh after coming back
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey.shade300),
          SizedBox(height: 16),
          Text(
            'No messages yet',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
          ),
          SizedBox(height: 8),
          Text(
            'When you contact a court owner,\nyour conversation will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

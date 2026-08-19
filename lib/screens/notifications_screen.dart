import 'package:flutter_project/theme/app_colors.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'booking_screen.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String _userEmail = '';
  List<dynamic> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    if (userStr != null) {
      final userObj = json.decode(userStr);
      setState(() {
        _userEmail = userObj['email'] ?? '';
      });
      _fetchNotifications();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchNotifications() async {
    if (_userEmail.isEmpty) return;
    final notifications = await _apiService.fetchNotifications(_userEmail);
    setState(() {
      _notifications = notifications;
      _isLoading = false;
    });
  }

  Future<void> _markAsRead(int id, int index) async {
    if (_notifications[index]['is_read'] == true) return;
    
    // Optimistic update
    setState(() {
      _notifications[index]['is_read'] = true;
    });
    
    final success = await _apiService.markNotificationAsRead(id);
    if (!success) {
      // Revert if failed
      setState(() {
        _notifications[index]['is_read'] = false;
      });
    }
  }

  void _showReplySheet(BuildContext context, Map<dynamic, dynamic> notif) {
    final String toEmail = notif['sender_email'] ?? '';
    if (toEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot reply — no sender info available.')),
      );
      return;
    }

    final TextEditingController _replyCtrl = TextEditingController();
    bool _isSending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.softWhite,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                SizedBox(height: 20),

                // Header
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.reply_rounded, color: AppColors.primaryGreen, size: 22),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Reply', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('To: $toEmail',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.grey.shade600),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),

                SizedBox(height: 12),

                // Original message preview
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    notif['message'] ?? '',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                SizedBox(height: 16),

                // Reply field
                TextField(
                  controller: _replyCtrl,
                  maxLines: 4,
                  minLines: 3,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Write your reply...',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primaryGreen, width: 2),
                    ),
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),

                SizedBox(height: 16),

                // Send button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSending
                        ? null
                        : () async {
                            final msg = _replyCtrl.text.trim();
                            if (msg.isEmpty) return;
                            setSheetState(() => _isSending = true);
                            try {
                              await _apiService.sendNotification(
                                toEmail,
                                _userEmail,
                                '↩️ Reply from court owner',
                                msg,
                              );
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Reply sent!'),
                                  backgroundColor: AppColors.primaryGreen,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            } catch (e) {
                              setSheetState(() => _isSending = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to send reply.'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: AppColors.softWhite,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isSending
                        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.softWhite, strokeWidth: 2))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.send_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('Send Reply', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      DateTime dt = DateTime.parse(dateStr).toLocal();
      return '${dt.month}/${dt.day}/${dt.year} at ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamWhite,
      appBar: AppBar(
        backgroundColor: AppColors.softWhite,
        elevation: 1,
        centerTitle: true,
        title: Text(
          'Notifications',
          style: TextStyle(color: AppColors.richBlack, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: AppColors.richBlack),
        actions: [
          IconButton(
            icon: Icon(Icons.travel_explore_rounded, color: AppColors.primaryGreen),
            tooltip: 'Find Available Slots',
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Scanning for available slots...'),
                  duration: Duration(seconds: 1),
                ),
              );
              bool success = await _apiService.triggerBookingSummary(_userEmail);
              if (success && mounted) {
                _fetchNotifications();
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('No active Booking Assistant or no new slots found.')),
                );
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
            tooltip: 'Clear All',
            onPressed: () async {
              if (_notifications.isEmpty) return;
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Clear Notifications'),
                  content: Text('Are you sure you want to delete all your notifications?'),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false), 
                      child: Text('Cancel', style: TextStyle(color: Colors.grey.shade700))
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true), 
                      child: Text('Clear All', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                setState(() => _isLoading = true);
                await _apiService.clearNotifications(_userEmail);
                _fetchNotifications();
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.richBlack),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _fetchNotifications();
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.richBlack))
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey[400]),
                      SizedBox(height: 16),
                      Text("No notifications yet", style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: _notifications.length,
                  separatorBuilder: (context, index) => Divider(height: 1, thickness: 0.5, color: AppColors.primaryGreen.withOpacity(0.2), indent: 72, endIndent: 16),
                  itemBuilder: (context, index) {
                    final notif = _notifications[index];
                    final bool isRead = notif['is_read'] == true;
                    final bool canReply = (notif['sender_email'] ?? '').toString().isNotEmpty;
                    
                    return InkWell(
                      onTap: () => _markAsRead(notif['id'], index),
                      child: Container(
                        padding: EdgeInsets.all(16),
                        color: isRead ? Colors.transparent : Colors.blue.withValues(alpha: 0.05),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.chat_bubble_outline_rounded,
                                color: AppColors.primaryGreen,
                                size: 24,
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          notif['title'] ?? 'Notification',
                                          style: TextStyle(
                                            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      if (!isRead)
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: Colors.blue,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                  Builder(
                                    builder: (context) {
                                      String message = notif['message'] ?? '';
                                      if (notif['action_data'] != null && message.contains(':\n')) {
                                        message = message.split(':\n')[0] + ':';
                                      }
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(height: 4),
                                          Text(
                                            message,
                                            style: TextStyle(
                                              color: Colors.grey[800],
                                              height: 1.2,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                  if (notif['action_data'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 12.0),
                                      child: Builder(
                                        builder: (context) {
                                          List<dynamic> actions = [];
                                          if (notif['action_data'] is String) {
                                            try {
                                              actions = json.decode(notif['action_data']);
                                            } catch (e) {}
                                          } else if (notif['action_data'] is List) {
                                            actions = notif['action_data'];
                                          }

                                          if (actions.isEmpty) return SizedBox.shrink();

                                          Map<String, List<dynamic>> groupedActions = {};
                                          for (var action in actions) {
                                            final court = action['court'] ?? 'Unknown Court';
                                            if (!groupedActions.containsKey(court)) {
                                              groupedActions[court] = [];
                                            }
                                            groupedActions[court]!.add(action);
                                          }

                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: groupedActions.entries.map((entry) {
                                              return Padding(
                                                padding: const EdgeInsets.only(bottom: 12.0),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(entry.key, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade700)),
                                                    SizedBox(height: 6),
                                                    Wrap(
                                                      spacing: 8,
                                                      runSpacing: 8,
                                                      children: entry.value.map<Widget>((action) {
                                                        String timeStr = action['time'] ?? '';
                                                        if (timeStr.contains(':')) {
                                                          final parts = timeStr.split(':');
                                                          int h = int.tryParse(parts[0]) ?? 0;
                                                          String ampm = h >= 12 ? 'PM' : 'AM';
                                                          h = h % 12;
                                                          if (h == 0) h = 12;
                                                          timeStr = '$h:${parts[1]} $ampm';
                                                        }

                                                        return ActionChip(
                                                          backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.1),
                                                          side: BorderSide(color: AppColors.primaryGreen),
                                                          label: Text(
                                                            '${DateFormat('MMM d, yyyy').format(DateTime.parse(action['date']))} $timeStr',
                                                            style: TextStyle(color: AppColors.primaryGreen, fontSize: 12, fontWeight: FontWeight.bold),
                                                          ),
                                                          onPressed: () {
                                                            Navigator.push(
                                                              context,
                                                              MaterialPageRoute(
                                                                builder: (context) => BookingScreen(
                                                                  initialServiceName: action['court'],
                                                                  initialDate: action['date'],
                                                                  initialTime: action['time'],
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                        );
                                                      }).toList(),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                          );
                                        },
                                      ),
                                    ),
                                  SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatDate(notif['created_at']),
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (canReply)
                                        GestureDetector(
                                          onTap: () {
                                            _markAsRead(notif['id'], index);
                                            _showReplySheet(context, notif);
                                          },
                                          child: Container(
                                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryGreen.withOpacity(0.08),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: AppColors.primaryGreen.withOpacity(0.3)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.reply_rounded, size: 13, color: AppColors.primaryGreen),
                                                SizedBox(width: 4),
                                                Text('Reply',
                                                  style: TextStyle(fontSize: 12, color: AppColors.primaryGreen, fontWeight: FontWeight.w600),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

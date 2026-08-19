import 'package:flutter_project/theme/app_colors.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:google_fonts/google_fonts.dart';

class ChatScreen extends StatefulWidget {
  final String userEmail;
  final String partnerEmail;
  final String partnerName;

  ChatScreen({required this.userEmail, required this.partnerEmail, required this.partnerName});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
    _pollTimer = Timer.periodic(Duration(minutes: 10), (_) {
      _pollHistory();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchHistory() async {
    final history = await _apiService.fetchChatHistory(widget.userEmail, widget.partnerEmail);
    if (!mounted) return;
    setState(() {
      _messages = history;
      _isLoading = false;
    });
    _scrollToBottom();
  }

  Future<void> _pollHistory() async {
    final history = await _apiService.fetchChatHistory(widget.userEmail, widget.partnerEmail);
    if (!mounted) return;
    if (history.length != _messages.length) {
      setState(() {
        _messages = history;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      Future.delayed(Duration(milliseconds: 100), () {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    final success = await _apiService.sendMessage(widget.userEmail, widget.partnerEmail, '', text);
    if (success) {
      _msgCtrl.clear();
      await _fetchHistory();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send message')));
    }

    setState(() {
      _isSending = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7F7F7),
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primaryGreen.withOpacity(0.1),
              child: Text(widget.partnerName[0].toUpperCase(), style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
            ),
            SizedBox(width: 12),
            Expanded(child: Text(widget.partnerName, style: TextStyle(fontFamily: 'Poppins', color: AppColors.richBlack, fontWeight: FontWeight.bold, fontSize: 18), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
        ),
        backgroundColor: AppColors.softWhite,
        elevation: 1,
        iconTheme: IconThemeData(color: AppColors.richBlack),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = msg['sender_email'] == widget.userEmail;
                      return _buildMessageBubble(msg['message'], isMe);
                    },
                  ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 12, left: isMe ? 50 : 0, right: isMe ? 0 : 50),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primaryGreen : AppColors.softWhite,
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomRight: isMe ? Radius.circular(0) : Radius.circular(20),
            bottomLeft: isMe ? Radius.circular(20) : Radius.circular(0),
          ),
          boxShadow: [
            BoxShadow(color: AppColors.richBlack.withOpacity(0.05), blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(color: isMe ? AppColors.softWhite : AppColors.richBlack, fontSize: 15),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12).copyWith(bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 12 : 24),
      decoration: BoxDecoration(
        color: AppColors.softWhite,
        boxShadow: [
          BoxShadow(color: AppColors.richBlack.withOpacity(0.05), blurRadius: 10, offset: Offset(0, -2)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgCtrl,
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                filled: true,
                fillColor: Color(0xFFF0F0F0),
                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ),
          SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.primaryGreen,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: _isSending ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.softWhite, strokeWidth: 2)) : Icon(Icons.send, color: AppColors.softWhite),
              onPressed: _isSending ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}

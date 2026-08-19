import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_project/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class ManageChallengesScreen extends StatefulWidget {
  @override
  _ManageChallengesScreenState createState() => _ManageChallengesScreenState();
}

class _ManageChallengesScreenState extends State<ManageChallengesScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _myChallenges = [];
  bool _isLoading = true;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    if (userStr != null) {
      try {
        final userObj = json.decode(userStr);
        _userEmail = userObj['email'] ?? '';
      } catch (e) {
        _userEmail = '';
      }
    } else {
      _userEmail = '';
    }
    
    if (_userEmail!.isNotEmpty) {
      final plays = await _apiService.fetchUserBookings(_userEmail!);
      if (mounted) {
        setState(() {
          _myChallenges = plays.where((p) => p['is_open_challenge'] == true && p['status'] != 'cancelled').cast<Map<String, dynamic>>().toList();
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _viewRequests(Map<String, dynamic> challenge) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
    );

    final requests = await _apiService.fetchChallengeRequests(challenge['id']);
    
    if (!mounted) return;
    Navigator.pop(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: AppColors.softWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Challengers', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.richBlack)),
              SizedBox(height: 16),
              Expanded(
                child: requests.isEmpty
                    ? Center(child: Text('No requests yet.', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: requests.length,
                        itemBuilder: (context, index) {
                          final req = requests[index];
                          final isPending = req['status'] == 'pending';
                          
                          return Card(
                            margin: EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              title: Text(req['challenger_name'] ?? 'Unknown'),
                              subtitle: Text(req['status'].toString().toUpperCase()),
                              trailing: isPending
                                  ? ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
                                      onPressed: () => _acceptChallenger(req['id'], challenge['id']),
                                      child: Text('Accept', style: TextStyle(color: Colors.white)),
                                    )
                                  : (req['status'] == 'accepted' 
                                      ? ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                          onPressed: () => _redoChallenge(challenge['id']),
                                          child: Text('Redo', style: TextStyle(color: Colors.white)),
                                        )
                                      : null),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _acceptChallenger(int requestId, int appointmentId) async {
    Navigator.pop(context); // Close bottom sheet
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
    );

    final result = await _apiService.acceptChallenger(requestId, appointmentId);
    
    if (!mounted) return;
    Navigator.pop(context); // close loading

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Challenger accepted!'), backgroundColor: AppColors.primaryGreen));
      _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to accept.'), backgroundColor: Colors.red));
    }
  }

  void _redoChallenge(int appointmentId) async {
    Navigator.pop(context); // Close bottom sheet
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
    );

    final result = await _apiService.redoChallenge(appointmentId);
    
    if (!mounted) return;
    Navigator.pop(context); // close loading

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Challenge reset! You can now choose another challenger.'), backgroundColor: AppColors.primaryGreen));
      _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to redo challenge.'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        backgroundColor: AppColors.softWhite,
        elevation: 0,
        title: Text('Manage Challenges', style: TextStyle(color: AppColors.richBlack, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: AppColors.richBlack),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : _myChallenges.isEmpty
              ? Center(child: Text('You have not posted any open challenges.', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: _myChallenges.length,
                  itemBuilder: (context, index) {
                    final challenge = _myChallenges[index];
                    return Card(
                      child: ListTile(
                        title: Text('${challenge['service_type']} - ${challenge['challenge_type']}'),
                        subtitle: Text('${challenge['preferred_date']} at ${challenge['preferred_time']}'),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => _viewRequests(challenge),
                      ),
                    );
                  },
                ),
    );
  }
}

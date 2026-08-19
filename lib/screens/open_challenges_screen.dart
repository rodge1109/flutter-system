import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_project/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class OpenChallengesScreen extends StatefulWidget {
  @override
  _OpenChallengesScreenState createState() => _OpenChallengesScreenState();
}

class _OpenChallengesScreenState extends State<OpenChallengesScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _challenges = [];
  bool _isLoading = true;
  String? _userEmail;
  String? _userName;

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
        _userName = userObj['full_name'] ?? '';
      } catch (e) {
        _userEmail = '';
        _userName = '';
      }
    } else {
      _userEmail = '';
      _userName = '';
    }
    
    if (_userEmail!.isNotEmpty) {
      final challenges = await _apiService.fetchOpenChallenges(_userEmail!);
      if (mounted) {
        setState(() {
          _challenges = challenges;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _applyToChallenge(Map<String, dynamic> challenge) async {
    if (_userEmail == null || _userEmail!.isEmpty) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
    );

    final result = await _apiService.applyToChallenge(challenge['id'], _userEmail!, _userName!);
    
    if (!mounted) return;
    Navigator.pop(context); // Close loading dialog

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully applied to the challenge!'), backgroundColor: AppColors.primaryGreen),
      );
      _loadData(); // Refresh list to remove it if we don't want to show it, or just keep it
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Failed to apply.'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        backgroundColor: AppColors.softWhite,
        elevation: 0,
        title: Text('Open Challenges', style: TextStyle(color: AppColors.richBlack, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: AppColors.richBlack),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : _challenges.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      'No open challenges right now. Be the first to post one!',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: _challenges.length,
                  itemBuilder: (context, index) {
                    final challenge = _challenges[index];
                    final isDoubles = challenge['challenge_type'] == 'doubles';
                    final hostDisplay = isDoubles && challenge['host_tandem_name'] != null && challenge['host_tandem_name'].isNotEmpty
                        ? challenge['host_tandem_name']
                        : challenge['host_name'];

                    return Card(
                      elevation: 4,
                      margin: EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: Colors.white,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentLime,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    (challenge['challenge_type'] ?? 'singles').toUpperCase(),
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.richBlack),
                                  ),
                                ),
                                Text(
                                  challenge['preferred_date'] ?? '',
                                  style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Host: $hostDisplay',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.richBlack),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Court: ${challenge['service_type']}',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                            ),
                            Text(
                              'Time: ${challenge['preferred_time']}',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                            ),
                            if (challenge['challenge_description'] != null && challenge['challenge_description'].toString().isNotEmpty) ...[
                              SizedBox(height: 8),
                              Text(
                                'Details: ${challenge['challenge_description']}',
                                style: TextStyle(color: Colors.grey.shade800, fontSize: 14, fontStyle: FontStyle.italic),
                              ),
                            ],
                            SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: challenge['accepted_challenger_name'] != null ? Colors.grey.shade400 : AppColors.primaryGreen,
                                  foregroundColor: AppColors.softWhite,
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: challenge['accepted_challenger_name'] != null ? null : () => _applyToChallenge(challenge),
                                child: Text(
                                  challenge['accepted_challenger_name'] != null 
                                      ? 'Accepted: ${challenge['accepted_challenger_name']}'
                                      : 'Challenge!', 
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                                ),
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

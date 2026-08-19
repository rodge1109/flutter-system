import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';

class PasaloCourtsScreen extends StatefulWidget {
  @override
  _PasaloCourtsScreenState createState() => _PasaloCourtsScreenState();
}

class _PasaloCourtsScreenState extends State<PasaloCourtsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _allPasaloCourts = [];
  List<Map<String, dynamic>> _filteredCourts = [];
  
  String? _userEmail;
  String? _userName;
  String? _userPhone;

  String _filterCourt = 'All Courts';
  List<String> _courtNames = ['All Courts'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    if (userStr != null) {
      final userObj = json.decode(userStr);
      _userEmail = userObj['email'];
      _userName = userObj['full_name'];
      _userPhone = userObj['phone_number'];
    }

    try {
      final courts = await _apiService.fetchPasaloCourts();
      
      Set<String> courtNamesSet = {'All Courts'};
      for (var c in courts) {
        if (c['court_name'] != null) {
          courtNamesSet.add(c['court_name']);
        }
      }

      setState(() {
        _allPasaloCourts = courts;
        _filteredCourts = courts;
        _courtNames = courtNamesSet.toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error: $e');
    }
  }

  void _applyFilter(String courtName) {
    setState(() {
      _filterCourt = courtName;
      if (courtName == 'All Courts') {
        _filteredCourts = List.from(_allPasaloCourts);
      } else {
        _filteredCourts = _allPasaloCourts.where((c) => c['court_name'] == courtName).toList();
      }
    });
  }

  Future<void> _showAcceptPasaloDialog(Map<String, dynamic> court) async {
    if (_userEmail == null) return;
    if (court['current_owner_email'] == _userEmail) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('You cannot pasalo your own court.')));
      return;
    }

    String? base64Image;
    bool isSubmitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setStateSB) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Assume Court', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 16),
                  Text('Host: ${court['current_owner_name'] ?? 'Unknown'}'),
                  Text('Price: ₱${court['assume_price'] ?? '0'}'),
                  if (court['assume_notes'] != null && court['assume_notes'].isNotEmpty) ...[
                    SizedBox(height: 8),
                    Text('Notes / Payment Details:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(court['assume_notes']),
                  ],
                  SizedBox(height: 16),
                  Text('Please send payment and upload the receipt.', style: TextStyle(color: Colors.grey.shade700)),
                  SizedBox(height: 16),
                  
                  GestureDetector(
                    onTap: () async {
                      final ImagePicker _picker = ImagePicker();
                      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
                      if (image != null) {
                        final bytes = await image.readAsBytes();
                        setStateSB(() {
                          base64Image = base64Encode(bytes);
                        });
                      }
                    },
                    child: Container(
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: base64Image != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(base64Decode(base64Image!), fit: BoxFit.cover),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.upload_file, size: 40, color: Colors.grey.shade400),
                                SizedBox(height: 8),
                                Text('Tap to upload receipt', style: TextStyle(color: Colors.grey.shade600)),
                              ],
                            ),
                    ),
                  ),
                  
                  SizedBox(height: 24),
                  if (isSubmitting)
                    Center(child: CircularProgressIndicator())
                  else
                    ElevatedButton(
                      onPressed: () async {
                        if (base64Image == null) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please upload a proof of payment')));
                          return;
                        }
                        
                        setStateSB(() => isSubmitting = true);
                        final result = await _apiService.requestPasalo(
                          court['id'].toString(), 
                          _userEmail!, 
                          _userName ?? 'Unknown', 
                          _userPhone ?? 'Unknown', 
                          base64Image!
                        );
                        
                        if (mounted) {
                          if (result['success'] == true) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Request sent! The owner will review it.'), backgroundColor: AppColors.primaryGreen));
                            _loadData();
                          } else {
                            setStateSB(() => isSubmitting = false);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? 'Failed to send request'), backgroundColor: Colors.red));
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 16)),
                      child: Text('Submit Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamWhite,
      appBar: AppBar(
        title: Text('Pasalo Courts', style: TextStyle(color: AppColors.richBlack, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.softWhite,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.richBlack),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.accentLime))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _filterCourt,
                        items: _courtNames.map((name) {
                          return DropdownMenuItem(value: name, child: Text(name));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) _applyFilter(val);
                        },
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _filteredCourts.isEmpty
                      ? Center(child: Text('No courts available for pasalo.', style: TextStyle(color: Colors.grey)))
                      : ListView.separated(
                          padding: EdgeInsets.all(16),
                          itemCount: _filteredCourts.length,
                          separatorBuilder: (context, index) => SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final court = _filteredCourts[index];
                            final date = court['preferred_date']?.split('T')[0] ?? '';
                            final time = court['preferred_time'] ?? '';
                            
                            return Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(child: Text(court['court_name'] ?? 'Court', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.deepTeal))),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                          child: Text('₱${court['assume_price'] ?? '0'}', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                                        SizedBox(width: 8),
                                        Text(date, style: TextStyle(color: Colors.grey.shade800)),
                                      ],
                                    ),
                                    SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.access_time, size: 16, color: Colors.grey),
                                        SizedBox(width: 8),
                                        Text(time, style: TextStyle(color: Colors.grey.shade800)),
                                      ],
                                    ),
                                    SizedBox(height: 12),
                                    Text('Owner: ${court['current_owner_name'] ?? 'Unknown'}', style: TextStyle(color: Colors.grey.shade600)),
                                    SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: () => _showAcceptPasaloDialog(court),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        child: Text('Assume Court', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_project/theme/app_colors.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class BookingAssistantScreen extends StatefulWidget {
  final String userEmail;

  const BookingAssistantScreen({Key? key, required this.userEmail}) : super(key: key);

  @override
  _BookingAssistantScreenState createState() => _BookingAssistantScreenState();
}

class _BookingAssistantScreenState extends State<BookingAssistantScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  
  DateTime? _selectedDate;
  TimeOfDay _startTime = TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _endTime = TimeOfDay(hour: 20, minute: 0);
  String _selectedCourt = 'Any';
  final _paymentRefController = TextEditingController();
  bool _isLoading = false;

  final List<String> _courtOptions = ['Any', 'Court 1', 'Court 2', 'Court 3'];

  @override
  void dispose() {
    _paymentRefController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 60)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primaryGreen,
              onPrimary: Colors.white,
              onSurface: AppColors.richBlack,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primaryGreen,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _activateAssistant() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_paymentRefController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please enter your GCash Reference Number')));
      return;
    }

    setState(() => _isLoading = true);

    String formatTimeOfDay(TimeOfDay time) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';
    }

    final data = {
      'email': widget.userEmail,
      'preferredDate': _selectedDate != null ? DateFormat('yyyy-MM-dd').format(_selectedDate!) : null,
      'preferredTimeStart': formatTimeOfDay(_startTime),
      'preferredTimeEnd': formatTimeOfDay(_endTime),
      'courtPreference': _selectedCourt,
      'paymentReference': _paymentRefController.text
    };

    try {
      final response = await _apiService.activateBookingAssistant(data);
      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Booking Assistant Activated!')));
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response['message'] ?? 'Failed to activate assistant')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('An error occurred')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        title: Text('Quick Booking Assistant', style: TextStyle(color: AppColors.richBlack, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.softWhite,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.richBlack),
      ),
      body: _isLoading 
          ? Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.bolt, color: AppColors.primaryGreen, size: 32),
                          SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Never miss a slot! Set your preferences and we will alert you the moment a matching timeslot becomes vacant.',
                              style: TextStyle(color: AppColors.richBlack, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 32),
                    
                    Text('Preferred Date', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.richBlack)),
                    SizedBox(height: 8),
                    InkWell(
                      onTap: () => _selectDate(context),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_selectedDate == null ? 'Any Date' : DateFormat('MMMM dd, yyyy').format(_selectedDate!), style: TextStyle(fontSize: 16, color: _selectedDate == null ? Colors.grey : AppColors.richBlack)),
                            Icon(Icons.calendar_today, color: AppColors.primaryGreen),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 24),

                    Text('Time Range', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.richBlack)),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectTime(context, true),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('From', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  SizedBox(height: 4),
                                  Text(_startTime.format(context), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.richBlack)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectTime(context, false),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('To', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  SizedBox(height: 4),
                                  Text(_endTime.format(context), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.richBlack)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),

                    Text('Court Preference', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.richBlack)),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCourt,
                          isExpanded: true,
                          items: _courtOptions.map((String court) {
                            return DropdownMenuItem<String>(
                              value: court,
                              child: Text(court),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() => _selectedCourt = newValue);
                            }
                          },
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 32),
                    Divider(),
                    SizedBox(height: 16),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Assistant Fee', style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                        Text('₱100.00 / month', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
                      ],
                    ),
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primaryGreen.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pay via GCash', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text.rich(
                            TextSpan(
                              text: 'Send exactly ₱100.00 to ',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                              children: [
                                TextSpan(text: '09276230491', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
                                TextSpan(text: ' and enter the Reference Number below to activate. Valid for 30 days.'),
                              ],
                            ),
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _paymentRefController,
                            decoration: InputDecoration(
                              labelText: 'GCash Reference No.',
                              filled: true,
                              fillColor: AppColors.softWhite,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade200)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.primaryGreen)),
                            ),
                            validator: (value) => value == null || value.isEmpty ? 'Please enter Ref No.' : null,
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _activateAssistant,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Activate Assistant', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.softWhite)),
                      ),
                    ),
                    SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }
}

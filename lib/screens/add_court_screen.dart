import 'package:flutter_project/theme/app_colors.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';
import 'map_picker_screen.dart';

class AddCourtScreen extends StatefulWidget {
  final String userEmail;
  final Map<String, dynamic>? court;

  const AddCourtScreen({Key? key, required this.userEmail, this.court}) : super(key: key);

  @override
  _AddCourtScreenState createState() => _AddCourtScreenState();
}

class _AddCourtScreenState extends State<AddCourtScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _numberCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _dayRateCtrl = TextEditingController();
  final _nightRateCtrl = TextEditingController();
  final _openTimeCtrl = TextEditingController(text: '00:00');
  final _closeTimeCtrl = TextEditingController(text: '23:59');
  final _logoUrlCtrl = TextEditingController();
  final ApiService _apiService = ApiService();
  
  final List<String> _availableFacilities = [
    'Covered Court',
    'Restrooms',
    'Water Station',
    'Parking',
    'Equipment Rental',
    'Seating'
  ];
  List<String> _selectedFacilities = [];
  
  bool _isSaving = false;
  bool _isUploadingLogo = false;

  @override
  void initState() {
    super.initState();
    if (widget.court != null) {
      _nameCtrl.text = widget.court!['name'] ?? '';
      _numberCtrl.text = widget.court!['court_number']?.toString() ?? '';
      _addressCtrl.text = widget.court!['address'] ?? '';
      _latCtrl.text = widget.court!['latitude']?.toString() ?? '';
      _lngCtrl.text = widget.court!['longitude']?.toString() ?? '';
      _descCtrl.text = widget.court!['description'] ?? 'Enjoy a fun and active game on our well-maintained pickleball court, perfect for players of all skill levels.';
      _dayRateCtrl.text = widget.court!['base_price']?.toString() ?? '';
      _nightRateCtrl.text = widget.court!['base_price']?.toString() ?? '';
      _openTimeCtrl.text = widget.court!['open_time'] ?? '00:00';
      _closeTimeCtrl.text = widget.court!['close_time'] ?? '23:59';
      _logoUrlCtrl.text = widget.court!['logo_url'] ?? widget.court!['logo'] ?? '';

      final rawFacilities = widget.court!['facilities'];
      if (rawFacilities != null) {
        if (rawFacilities is List) {
          _selectedFacilities = rawFacilities.map((e) => e.toString()).toList();
        } else if (rawFacilities is String) {
          try {
            _selectedFacilities = List<String>.from(json.decode(rawFacilities));
          } catch (_) {}
        }
      }

      final rawHourly = widget.court!['hourly_prices'];
      if (rawHourly != null) {
        List<dynamic> hourlyList = [];
        if (rawHourly is List) {
          hourlyList = rawHourly;
        } else if (rawHourly is String) {
          try {
            hourlyList = json.decode(rawHourly);
          } catch (_) {}
        }
        for (var item in hourlyList) {
          if (item is Map && item['time'] != null && item['price'] != null) {
            final String timeStr = item['time'].toString();
            final int hour = int.tryParse(timeStr.split(':')[0]) ?? -1;
            // 6 AM is part of Day Rate
            if (hour == 6) {
              _dayRateCtrl.text = item['price'].toString();
            }
            // 6 PM is part of Night Rate
            else if (hour == 18) {
              _nightRateCtrl.text = item['price'].toString();
            }
          }
        }
      }
    } else {
      _descCtrl.text = 'Enjoy a fun and active game on our well-maintained pickleball court, perfect for players of all skill levels.';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _numberCtrl.dispose();
    _addressCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _descCtrl.dispose();
    _dayRateCtrl.dispose();
    _nightRateCtrl.dispose();
    _openTimeCtrl.dispose();
    _closeTimeCtrl.dispose();
    _logoUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadLogo() async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() => _isUploadingLogo = true);
        final String? uploadedUrl = await _apiService.uploadImageToCloudinary(pickedFile);
        setState(() => _isUploadingLogo = false);

        if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
          setState(() {
            _logoUrlCtrl.text = uploadedUrl;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Logo uploaded to Cloudinary successfully!'), backgroundColor: AppColors.primaryGreen)
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload image to Cloudinary.'), backgroundColor: Colors.red)
          );
        }
      }
    } catch (e) {
      setState(() => _isUploadingLogo = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e'), backgroundColor: Colors.red)
      );
    }
  }

  Future<void> _saveCourt() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);

    List<Map<String, dynamic>> hourlyPrices = [];
    final dayRate = double.tryParse(_dayRateCtrl.text) ?? 0;
    final nightRate = double.tryParse(_nightRateCtrl.text) ?? 0;

    for (int i = 0; i < 24; i++) {
      // Day Rate from 6 AM (inclusive) to 6 PM (exclusive)
      final isDay = (i >= 6 && i < 18);
      final price = isDay ? dayRate : nightRate;
      final timeString = '${i.toString().padLeft(2, '0')}:00';
      
      hourlyPrices.add({
        'time': timeString,
        'price': price
      });
    }

    final courtData = {
      'ownerEmail': widget.userEmail,
      'name': _nameCtrl.text,
      'courtNumber': _numberCtrl.text,
      'address': _addressCtrl.text,
      'latitude': double.tryParse(_latCtrl.text),
      'longitude': double.tryParse(_lngCtrl.text),
      'description': _descCtrl.text,
      'basePrice': dayRate, // Storing day rate as base price
      'hourlyPrices': hourlyPrices,
      'facilities': _selectedFacilities,
      'openTime': _openTimeCtrl.text,
      'closeTime': _closeTimeCtrl.text,
      'logoUrl': _logoUrlCtrl.text.trim(),
    };

    final Map<String, dynamic> res;
    if (widget.court != null) {
      res = await _apiService.updateCourt(widget.court!['id'], courtData);
    } else {
      res = await _apiService.addCourt(courtData);
    }
    
    setState(() => _isSaving = false);

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.court != null ? 'Court updated successfully!' : 'Court added successfully!'))
      );
      Navigator.pop(context, true); // Return true to indicate success
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Error saving court')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.court != null;
    return Scaffold(
      backgroundColor: Color(0xFFF7F7F7),
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Court' : 'Add New Court', style: TextStyle(color: AppColors.richBlack, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.softWhite,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.richBlack),
      ),
      body: _isSaving 
          ? Center(child: CircularProgressIndicator()) 
          : SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Basic Information'),
                    Row(
                      children: [
                        Expanded(flex: 3, child: _buildTextField('Court Name', _nameCtrl, required: true)),
                        SizedBox(width: 16),
                        Expanded(flex: 2, child: _buildTextField('Court #', _numberCtrl, required: true, isNumber: true)),
                      ],
                    ),
                    SizedBox(height: 16),
                    _buildTextField('Court Address', _addressCtrl, required: true),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('Latitude', _latCtrl, isNumber: true, required: false)),
                        SizedBox(width: 16),
                        Expanded(child: _buildTextField('Longitude', _lngCtrl, isNumber: true, required: false)),
                      ],
                    ),
                    SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final lat = double.tryParse(_latCtrl.text);
                        final lng = double.tryParse(_lngCtrl.text);
                        LatLng? initialLocation;
                        if (lat != null && lng != null) {
                          initialLocation = LatLng(lat, lng);
                        }
                        final LatLng? pickedLocation = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => MapPickerScreen(initialLocation: initialLocation)),
                        );
                        if (pickedLocation != null) {
                          setState(() {
                            _latCtrl.text = pickedLocation.latitude.toString();
                            _lngCtrl.text = pickedLocation.longitude.toString();
                          });
                        }
                      },
                      icon: Icon(Icons.map, color: AppColors.softWhite),
                      label: Text('Pick Location on Map', style: TextStyle(color: AppColors.softWhite)),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
                    ),
                    SizedBox(height: 16),
                    _buildTextField('Description', _descCtrl, maxLines: 3),
                    SizedBox(height: 24),
                    _buildSectionTitle('Court / Business Logo'),
                    Text('Upload your court or business logo from your phone or device directly to your Cloudinary account.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _isUploadingLogo ? null : _pickAndUploadLogo,
                      icon: _isUploadingLogo 
                        ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.softWhite))
                        : Icon(Icons.cloud_upload, color: AppColors.softWhite),
                      label: Text(_isUploadingLogo ? 'Uploading to Cloudinary...' : 'Upload Logo from Phone / Device', style: TextStyle(color: AppColors.softWhite, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    SizedBox(height: 12),
                    _buildTextField('Logo Image URL', _logoUrlCtrl),
                    if (_logoUrlCtrl.text.trim().isNotEmpty) ...[
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.primaryGreen, width: 2),
                              boxShadow: [
                                BoxShadow(color: Colors.black12, blurRadius: 4),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.network(
                                _logoUrlCtrl.text.trim(),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(Icons.broken_image, size: 20, color: Colors.grey),
                              ),
                            ),
                          ),
                          SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Logo Active', style: TextStyle(color: AppColors.primaryGreen, fontSize: 12, fontWeight: FontWeight.bold)),
                              Text('Hosted on Cloudinary', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ],
                    SizedBox(height: 16),
                    _buildSectionTitle('Pricing Setup'),
                    Text('Set your standard rates. The system will automatically apply the correct price based on the booked time.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('Day Rate (6AM-6PM)', _dayRateCtrl, isNumber: true, required: true)),
                        SizedBox(width: 16),
                        Expanded(child: _buildTextField('Night Rate (6PM-6AM)', _nightRateCtrl, isNumber: true, required: true)),
                      ],
                    ),
                    
                    SizedBox(height: 32),
                    _buildSectionTitle('Operating Hours'),
                    Text('Set your opening and closing time (24-hour format, e.g. 08:00 and 22:00). Enter 00:00 to 23:59 for 24-hour operation.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('Open Time', _openTimeCtrl, required: true, isNumber: false)),
                        SizedBox(width: 16),
                        Expanded(child: _buildTextField('Close Time', _closeTimeCtrl, required: true, isNumber: false)),
                      ],
                    ),

                    SizedBox(height: 32),
                    _buildSectionTitle('Facilities'),
                    Text('Select the amenities available at this court.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    SizedBox(height: 16),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 4.0,
                      children: _availableFacilities.map((facility) {
                        final isSelected = _selectedFacilities.contains(facility);
                        return FilterChip(
                          label: Text(facility),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedFacilities.add(facility);
                              } else {
                                _selectedFacilities.remove(facility);
                              }
                            });
                          },
                          selectedColor: Color(0xFFE2F999),
                          checkmarkColor: AppColors.primaryGreen,
                          labelStyle: TextStyle(
                            color: isSelected ? AppColors.primaryGreen : AppColors.richBlack,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    ),
                    
                    SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveCourt,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(isEditing ? 'Save Changes' : 'Add Court', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.softWhite)),
                      ),
                    ),
                    SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 8.0),
      child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.richBlack)),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool isNumber = false, bool required = false, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      maxLines: maxLines,
      validator: required ? (value) {
        if (value == null || value.trim().isEmpty) return 'This field is required';
        return null;
      } : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.richBlack.withOpacity(0.54), fontSize: 14),
        filled: true,
        fillColor: AppColors.softWhite,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.primaryGreen, width: 1.5)),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

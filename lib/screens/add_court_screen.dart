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
  final _dayDiscountCtrl = TextEditingController();
  final _nightDiscountCtrl = TextEditingController();
  final _openTimeCtrl = TextEditingController(text: '00:00');
  final _closeTimeCtrl = TextEditingController(text: '23:59');
  final _logoUrlCtrl = TextEditingController();
  final _customFacilityCtrl = TextEditingController();
  final _bookingPolicyCtrl = TextEditingController();
  final _aboutVenueCtrl = TextEditingController();
  final _faqCtrl = TextEditingController();
  final ApiService _apiService = ApiService();
  
  bool _enableDayDiscount = false;
  bool _enableNightDiscount = false;
  
  final List<String> _availableFacilities = [
    'Covered Court',
    'Restrooms',
    'Water Station',
    'Parking',
    'Equipment Rental',
    'Seating'
  ];
  List<String> _selectedFacilities = [];
  List<String> _courtPhotos = [];
  
  bool _isSaving = false;
  bool _isUploadingLogo = false;
  bool _isUploadingPhoto = false;

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
      
      _enableDayDiscount = widget.court!['is_day_discount_active'] == true || widget.court!['is_day_discount_active'] == 'true' || widget.court!['is_day_discount_active'] == 1;
      _dayDiscountCtrl.text = widget.court!['day_discount_rate']?.toString() ?? '';
      
      _enableNightDiscount = widget.court!['is_night_discount_active'] == true || widget.court!['is_night_discount_active'] == 'true' || widget.court!['is_night_discount_active'] == 1;
      _nightDiscountCtrl.text = widget.court!['night_discount_rate']?.toString() ?? '';

      final rawImages = widget.court!['images'] ?? widget.court!['photos'] ?? [];
      List<dynamic> parsedImages = [];
      if (rawImages is String) {
        try { parsedImages = json.decode(rawImages); } catch (_) {}
      } else if (rawImages is List) {
        parsedImages = rawImages;
      }
      _courtPhotos = parsedImages.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();

      const String defaultPolicy = '• Reservation & Payment: All bookings must be completed and confirmed prior to court entry.\n• Cancellation Policy: Free cancellation up to 24 hours before your reserved start time. Cancellations within 24 hours are non-refundable.\n• Arrival & Check-In: Please arrive 10-15 minutes before your scheduled slot. Late arrivals will not extend your reserved time.\n• Court Etiquette: Non-marking athletic shoes are strictly required to maintain court surface quality.';
      const String defaultAbout = 'Welcome to our premier pickleball facility! Designed for players of all skill levels, our venue features professional-grade court surfaces, high-intensity LED lighting for evening games, spacious spectator seating, clean restrooms, and a welcoming community atmosphere.';
      const String defaultFaq = 'Q: Are paddles and balls available for rent or purchase?\nA: Yes! High-quality rental paddles and pickleballs are available at the front desk.\n\nQ: Is on-site parking available for players?\nA: Yes, we provide free dedicated parking directly adjacent to the venue.\n\nQ: What footwear is allowed on the courts?\nA: Only non-marking court or athletic shoes are permitted.\n\nQ: Can I host Open Plays or Pasalo transfers here?\nA: Absolutely! You can post Open Plays or offer Pasalo slots directly through the app.';

      final pol = (widget.court!['booking_policy'] ?? widget.court!['bookingPolicy'] ?? '').toString().trim();
      _bookingPolicyCtrl.text = pol.isNotEmpty ? pol : defaultPolicy;

      final abt = (widget.court!['about_venue'] ?? widget.court!['aboutVenue'] ?? '').toString().trim();
      _aboutVenueCtrl.text = abt.isNotEmpty ? abt : defaultAbout;

      final faqVal = (widget.court!['faq'] ?? widget.court!['faqText'] ?? '').toString().trim();
      _faqCtrl.text = faqVal.isNotEmpty ? faqVal : defaultFaq;
    } else {
      _descCtrl.text = 'Enjoy a fun and active game on our well-maintained pickleball court, perfect for players of all skill levels.';
      _bookingPolicyCtrl.text = '• Reservation & Payment: All bookings must be completed and confirmed prior to court entry.\n• Cancellation Policy: Free cancellation up to 24 hours before your reserved start time. Cancellations within 24 hours are non-refundable.\n• Arrival & Check-In: Please arrive 10-15 minutes before your scheduled slot. Late arrivals will not extend your reserved time.\n• Court Etiquette: Non-marking athletic shoes are strictly required to maintain court surface quality.';
      _aboutVenueCtrl.text = 'Welcome to our premier pickleball facility! Designed for players of all skill levels, our venue features professional-grade court surfaces, high-intensity LED lighting for evening games, spacious spectator seating, clean restrooms, and a welcoming community atmosphere.';
      _faqCtrl.text = 'Q: Are paddles and balls available for rent or purchase?\nA: Yes! High-quality rental paddles and pickleballs are available at the front desk.\n\nQ: Is on-site parking available for players?\nA: Yes, we provide free dedicated parking directly adjacent to the venue.\n\nQ: What footwear is allowed on the courts?\nA: Only non-marking court or athletic shoes are permitted.\n\nQ: Can I host Open Plays or Pasalo transfers here?\nA: Absolutely! You can post Open Plays or offer Pasalo slots directly through the app.';
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
    _dayDiscountCtrl.dispose();
    _nightDiscountCtrl.dispose();
    _openTimeCtrl.dispose();
    _closeTimeCtrl.dispose();
    _logoUrlCtrl.dispose();
    _customFacilityCtrl.dispose();
    _bookingPolicyCtrl.dispose();
    _aboutVenueCtrl.dispose();
    _faqCtrl.dispose();
    super.dispose();
  }

  void _showImageSourceActionSheet({required bool isLogo}) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext ctx) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(isLogo ? Icons.business : Icons.photo_camera, color: AppColors.primaryGreen),
                  SizedBox(width: 10),
                  Text(
                    isLogo ? 'Select Logo Source' : 'Select Court Photo Source',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.richBlack),
                  ),
                ],
              ),
              SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Color(0xFFE2F999), shape: BoxShape.circle),
                  child: Icon(Icons.camera_alt, color: AppColors.primaryGreen),
                ),
                title: Text('Take Photo with Camera', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Snap a new photo directly from your phone camera', style: TextStyle(fontSize: 12, color: Colors.grey)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadImage(ImageSource.camera, isLogo: isLogo);
                },
              ),
              Divider(),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                  child: Icon(Icons.photo_library, color: Colors.blue.shade700),
                ),
                title: Text('Choose from Photo Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Select existing photos from your phone album', style: TextStyle(fontSize: 12, color: Colors.grey)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadImage(ImageSource.gallery, isLogo: isLogo);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadImage(ImageSource source, {required bool isLogo}) async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        if (isLogo) {
          setState(() => _isUploadingLogo = true);
        } else {
          setState(() => _isUploadingPhoto = true);
        }

        final String? uploadedUrl = await _apiService.uploadImageToCloudinary(pickedFile);

        if (isLogo) {
          setState(() => _isUploadingLogo = false);
        } else {
          setState(() => _isUploadingPhoto = false);
        }

        if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
          setState(() {
            if (isLogo) {
              _logoUrlCtrl.text = uploadedUrl;
            } else {
              _courtPhotos.add(uploadedUrl);
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isLogo ? 'Logo uploaded successfully!' : 'Court photo uploaded successfully!'),
              backgroundColor: AppColors.primaryGreen,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload image to Cloudinary.'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (isLogo) {
        setState(() => _isUploadingLogo = false);
      } else {
        setState(() => _isUploadingPhoto = false);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _addCustomFacility() {
    final text = _customFacilityCtrl.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        if (!_availableFacilities.contains(text)) {
          _availableFacilities.add(text);
        }
        if (!_selectedFacilities.contains(text)) {
          _selectedFacilities.add(text);
        }
        _customFacilityCtrl.clear();
      });
    }
  }

  Future<void> _saveCourt() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);

    List<Map<String, dynamic>> hourlyPrices = [];
    final dayStandard = double.tryParse(_dayRateCtrl.text) ?? 0;
    final dayDiscount = double.tryParse(_dayDiscountCtrl.text) ?? 0;
    final isDayDiscountActive = _enableDayDiscount && dayDiscount > 0;
    final effectiveDayRate = isDayDiscountActive ? dayDiscount : dayStandard;

    final nightStandard = double.tryParse(_nightRateCtrl.text) ?? 0;
    final nightDiscount = double.tryParse(_nightDiscountCtrl.text) ?? 0;
    final isNightDiscountActive = _enableNightDiscount && nightDiscount > 0;
    final effectiveNightRate = isNightDiscountActive ? nightDiscount : nightStandard;

    for (int i = 0; i < 24; i++) {
      // Day Rate from 6 AM (inclusive) to 6 PM (exclusive)
      final isDay = (i >= 6 && i < 18);
      final standard = isDay ? dayStandard : nightStandard;
      final discount = isDay ? dayDiscount : nightDiscount;
      final isActive = isDay ? isDayDiscountActive : isNightDiscountActive;
      final effectivePrice = isDay ? effectiveDayRate : effectiveNightRate;
      final timeString = '${i.toString().padLeft(2, '0')}:00';
      
      hourlyPrices.add({
        'time': timeString,
        'price': effectivePrice,
        'standardPrice': standard,
        'discountPrice': discount,
        'isDiscountActive': isActive,
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
      'basePrice': effectiveDayRate,
      'hourlyPrices': hourlyPrices,
      'facilities': _selectedFacilities,
      'openTime': _openTimeCtrl.text,
      'closeTime': _closeTimeCtrl.text,
      'logoUrl': _logoUrlCtrl.text.trim(),
      'images': _courtPhotos,
      'photos': _courtPhotos,
      'dayRate': dayStandard,
      'dayDiscountRate': dayDiscount,
      'isDayDiscountActive': isDayDiscountActive,
      'nightRate': nightStandard,
      'nightDiscountRate': nightDiscount,
      'isNightDiscountActive': isNightDiscountActive,
      'bookingPolicy': _bookingPolicyCtrl.text.trim(),
      'aboutVenue': _aboutVenueCtrl.text.trim(),
      'faq': _faqCtrl.text.trim(),
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
                    Text('Upload your court or business logo from your phone camera or photo gallery directly to Cloudinary.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _isUploadingLogo ? null : () => _showImageSourceActionSheet(isLogo: true),
                      icon: _isUploadingLogo 
                        ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.softWhite))
                        : Icon(Icons.add_a_photo, color: AppColors.softWhite),
                      label: Text(_isUploadingLogo ? 'Uploading to Cloudinary...' : 'Upload Logo from Phone', style: TextStyle(color: AppColors.softWhite, fontWeight: FontWeight.bold)),
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

                    SizedBox(height: 24),
                    _buildSectionTitle('Court / Venue Photos'),
                    Text('Add photos of your pickleball court surface, lighting, and facilities from your phone camera or gallery.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _isUploadingPhoto ? null : () => _showImageSourceActionSheet(isLogo: false),
                      icon: _isUploadingPhoto
                          ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.softWhite))
                          : Icon(Icons.photo_camera_back, color: AppColors.softWhite),
                      label: Text(
                        _isUploadingPhoto ? 'Uploading Court Photo...' : 'Add Court Photo from Phone',
                        style: TextStyle(color: AppColors.softWhite, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    if (_courtPhotos.isNotEmpty) ...[
                      SizedBox(height: 14),
                      Container(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _courtPhotos.length,
                          itemBuilder: (context, index) {
                            final photoUrl = _courtPhotos[index];
                            return Container(
                              margin: EdgeInsets.only(right: 12),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      photoUrl,
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 100,
                                        height: 100,
                                        color: Colors.grey.shade300,
                                        child: Icon(Icons.broken_image, color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _courtPhotos.removeAt(index);
                                        });
                                      },
                                      child: Container(
                                        padding: EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.7),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.close, color: Colors.white, size: 14),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],

                    SizedBox(height: 24),
                    _buildSectionTitle('Pricing Setup'),
                    Text('Set standard rates and optionally enable promotional discounted rates for Day and Night hours.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    SizedBox(height: 16),

                    // DAY RATE CARD
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.softWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _enableDayDiscount ? AppColors.primaryGreen : Colors.grey.shade200, width: _enableDayDiscount ? 1.5 : 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.wb_sunny, color: Colors.orange.shade700, size: 20),
                                  SizedBox(width: 8),
                                  Text('Day Rate (6AM - 6PM)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.richBlack)),
                                ],
                              ),
                              Row(
                                children: [
                                  Text(_enableDayDiscount ? 'Discount ON' : 'Discount OFF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _enableDayDiscount ? AppColors.primaryGreen : Colors.grey)),
                                  Switch(
                                    value: _enableDayDiscount,
                                    activeColor: AppColors.primaryGreen,
                                    onChanged: (val) => setState(() => _enableDayDiscount = val),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _buildTextField('Standard Rate (P/hr)', _dayRateCtrl, isNumber: true, required: true)),
                              if (_enableDayDiscount) ...[
                                SizedBox(width: 12),
                                Expanded(child: _buildTextField('Discounted Rate (P/hr)', _dayDiscountCtrl, isNumber: true, required: true)),
                              ],
                            ],
                          ),
                          if (_enableDayDiscount)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text('PROMO ACTIVE: Players will book at the discounted day rate.', style: TextStyle(color: AppColors.primaryGreen, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                    ),

                    SizedBox(height: 16),

                    // NIGHT RATE CARD
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.softWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _enableNightDiscount ? AppColors.primaryGreen : Colors.grey.shade200, width: _enableNightDiscount ? 1.5 : 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.nights_stay, color: Colors.indigo.shade700, size: 20),
                                  SizedBox(width: 8),
                                  Text('Night Rate (6PM - 6AM)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.richBlack)),
                                ],
                              ),
                              Row(
                                children: [
                                  Text(_enableNightDiscount ? 'Discount ON' : 'Discount OFF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _enableNightDiscount ? AppColors.primaryGreen : Colors.grey)),
                                  Switch(
                                    value: _enableNightDiscount,
                                    activeColor: AppColors.primaryGreen,
                                    onChanged: (val) => setState(() => _enableNightDiscount = val),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _buildTextField('Standard Rate (P/hr)', _nightRateCtrl, isNumber: true, required: true)),
                              if (_enableNightDiscount) ...[
                                SizedBox(width: 12),
                                Expanded(child: _buildTextField('Discounted Rate (P/hr)', _nightDiscountCtrl, isNumber: true, required: true)),
                              ],
                            ],
                          ),
                          if (_enableNightDiscount)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text('PROMO ACTIVE: Players will book at the discounted night rate.', style: TextStyle(color: AppColors.primaryGreen, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionTitle('About This Venue'),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _aboutVenueCtrl.text = 'Welcome to our premier pickleball facility! Designed for players of all skill levels, our venue features professional-grade court surfaces, high-intensity LED lighting for evening games, spacious spectator seating, clean restrooms, and a welcoming community atmosphere.';
                            });
                          },
                          icon: Icon(Icons.refresh, size: 14, color: AppColors.primaryGreen),
                          label: Text('Use Default Template', style: TextStyle(color: AppColors.primaryGreen, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    Text('Provide players with background details, rules, and highlights of your court facility.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    SizedBox(height: 12),
                    _buildTextField('Venue Overview & Highlights', _aboutVenueCtrl, maxLines: 4),

                    SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionTitle('Booking Policy'),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _bookingPolicyCtrl.text = '• Reservation & Payment: All bookings must be completed and confirmed prior to court entry.\n• Cancellation Policy: Free cancellation up to 24 hours before your reserved start time. Cancellations within 24 hours are non-refundable.\n• Arrival & Check-In: Please arrive 10-15 minutes before your scheduled slot. Late arrivals will not extend your reserved time.\n• Court Etiquette: Non-marking athletic shoes are strictly required to maintain court surface quality.';
                            });
                          },
                          icon: Icon(Icons.refresh, size: 14, color: AppColors.primaryGreen),
                          label: Text('Use Default Template', style: TextStyle(color: AppColors.primaryGreen, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    Text('Specify rules, cancellation windows, and player guidelines for reservations.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    SizedBox(height: 12),
                    _buildTextField('Rules & Cancellation Policy', _bookingPolicyCtrl, maxLines: 4),

                    SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionTitle('Frequently Asked Questions (FAQ)'),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _faqCtrl.text = 'Q: Are paddles and balls available for rent or purchase?\nA: Yes! High-quality rental paddles and pickleballs are available at the front desk.\n\nQ: Is on-site parking available for players?\nA: Yes, we provide free dedicated parking directly adjacent to the venue.\n\nQ: What footwear is allowed on the courts?\nA: Only non-marking court or athletic shoes are permitted.\n\nQ: Can I host Open Plays or Pasalo transfers here?\nA: Absolutely! You can post Open Plays or offer Pasalo slots directly through the app.';
                            });
                          },
                          icon: Icon(Icons.refresh, size: 14, color: AppColors.primaryGreen),
                          label: Text('Use Default Template', style: TextStyle(color: AppColors.primaryGreen, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    Text('Add common questions and answers for players (e.g., parking, equipment, attire).', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    SizedBox(height: 12),
                    _buildTextField('Questions & Answers (e.g. Q: Parking? A: Yes)', _faqCtrl, maxLines: 5),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _customFacilityCtrl,
                            decoration: InputDecoration(
                              hintText: 'Add custom facility (e.g. Pro Shop, Showers)',
                              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                              filled: true,
                              fillColor: AppColors.softWhite,
                              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.primaryGreen, width: 1.5)),
                            ),
                            onSubmitted: (_) => _addCustomFacility(),
                          ),
                        ),
                        SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _addCustomFacility,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('+ Add', style: TextStyle(color: AppColors.softWhite, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
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

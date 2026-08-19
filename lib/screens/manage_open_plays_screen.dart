import 'package:flutter_project/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import 'dart:convert';
import 'dart:typed_data';

class ManageOpenPlaysScreen extends StatefulWidget {
  final String userEmail;
  const ManageOpenPlaysScreen({Key? key, required this.userEmail}) : super(key: key);

  @override
  _ManageOpenPlaysScreenState createState() => _ManageOpenPlaysScreenState();
}

class _ManageOpenPlaysScreenState extends State<ManageOpenPlaysScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _openPlays = [];

  @override
  void initState() {
    super.initState();
    _loadOpenPlays();
  }

  String _normalizeTime(String t) {
    if (t.toUpperCase().contains('AM') || t.toUpperCase().contains('PM')) {
      if (t.startsWith('0')) return t.substring(1);
      return t;
    }
    if (t.contains(':')) {
      final parts = t.split(':');
      if (parts.length >= 2) {
        int h = int.tryParse(parts[0]) ?? 0;
        String min = parts[1];
        String ampm = h < 12 ? 'AM' : 'PM';
        int displayH = h % 12;
        if (displayH == 0) displayH = 12;
        return '$displayH:$min $ampm';
      }
    }
    return t;
  }

  Future<void> _loadOpenPlays() async {
    setState(() => _isLoading = true);
    final plays = await _apiService.fetchHostedOpenPlays(widget.userEmail);
    
    Map<String, Map<String, dynamic>> grouped = {};
    for (var play in plays) {
      String key = '${play['preferred_date']}_${play['service_type']}';
      if (!grouped.containsKey(key)) {
        grouped[key] = Map<String, dynamic>.from(play);
        grouped[key]!['appointment_ids'] = [play['id'].toString()];
        grouped[key]!['times'] = [play['preferred_time']];
      } else {
        grouped[key]!['appointment_ids'].add(play['id'].toString());
        grouped[key]!['times'].add(play['preferred_time']);
        
        int currentCount = int.tryParse(grouped[key]!['current_participants']?.toString() ?? '0') ?? 0;
        int playCount = int.tryParse(play['current_participants']?.toString() ?? '0') ?? 0;
        grouped[key]!['current_participants'] = currentCount > playCount ? currentCount : playCount;

        int currentMax = int.tryParse(grouped[key]!['open_play_max_players']?.toString() ?? '0') ?? 0;
        int playMax = int.tryParse(play['open_play_max_players']?.toString() ?? '0') ?? 0;
        grouped[key]!['open_play_max_players'] = currentMax > playMax ? currentMax : playMax;
      }
    }

    List<Map<String, dynamic>> finalOpenPlays = grouped.values.map((g) {
      List<String> times = List<String>.from(g['times']);
      times.sort();
      if (times.length > 1) {
        g['preferred_time'] = '${_normalizeTime(times.first)} - ${_normalizeTime(times.last)}';
      } else {
        g['preferred_time'] = _normalizeTime(times.first);
      }
      g['id'] = g['appointment_ids'].join(','); 
      return g;
    }).toList();

    if (mounted) {
      setState(() {
        _openPlays = finalOpenPlays;
        _isLoading = false;
      });
    }
  }

  void _showParticipantsSheet(Map<String, dynamic> play) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ParticipantsBottomSheet(
          play: play,
          apiService: _apiService,
          onStatusChanged: () {
            setState(() {});
          },
        );
      },
    ).then((_) {
      _loadOpenPlays();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Open Plays', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, color: AppColors.richBlack)),
        backgroundColor: AppColors.softWhite,
        foregroundColor: AppColors.richBlack,
        elevation: 0,
      ),
      backgroundColor: Colors.grey.shade50,
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _openPlays.isEmpty
              ? Center(child: Text("You haven't hosted any Open Plays yet.", style: TextStyle(color: Colors.grey.shade600)))
              : RefreshIndicator(
                  onRefresh: _loadOpenPlays,
                  child: ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: _openPlays.length,
                    itemBuilder: (context, index) {
                      final play = _openPlays[index];
                      int currentParticipants = int.tryParse(play['current_participants']?.toString() ?? '0') ?? 0;
                      int maxPlayers = int.tryParse(play['open_play_max_players']?.toString() ?? '4') ?? 4;
                      final bool isFull = currentParticipants >= maxPlayers;
                      
                      return Card(
                        margin: EdgeInsets.only(bottom: 16),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: InkWell(
                          onTap: () => _showParticipantsSheet(play),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        play['service_type'] ?? 'Open Play',
                                        style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.share, color: AppColors.primaryGreen),
                                          onPressed: () {
                                            final String playId = play['id'].toString();
                                            final String url = '${Uri.base.toString().split('?')[0]}?openplay=$playId';
                                            Clipboard.setData(ClipboardData(text: url));
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Share link copied to clipboard!'),
                                                backgroundColor: AppColors.primaryGreen,
                                                duration: Duration(seconds: 3),
                                              ),
                                            );
                                          },
                                        ),
                                        Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isFull ? Colors.red.shade50 : Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        isFull ? 'FULL' : 'OPEN',
                                        style: TextStyle(
                                          color: isFull ? Colors.red.shade700 : Colors.green.shade700,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Date: ${play['preferred_date']?.split('T')[0] ?? ''} • ${play['preferred_time'] ?? ''}',
                                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Joiners: $currentParticipants / $maxPlayers',
                                  style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primaryGreen),
                                ),
                                SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => _showEditOpenPlaySheet(play),
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(color: AppColors.primaryGreen),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        child: Text('Edit Details', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () => _showParticipantsSheet(play),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primaryGreen,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          elevation: 0,
                                        ),
                                        child: Text('View Joiners', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  void _showEditOpenPlaySheet(Map<String, dynamic> play) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _EditOpenPlaySheet(
          play: play,
          apiService: _apiService,
          onUpdated: _loadOpenPlays,
        );
      },
    );
  }
}


class _ParticipantsBottomSheet extends StatefulWidget {
  final Map<String, dynamic> play;
  final ApiService apiService;
  final VoidCallback onStatusChanged;

  const _ParticipantsBottomSheet({Key? key, required this.play, required this.apiService, required this.onStatusChanged}) : super(key: key);

  @override
  __ParticipantsBottomSheetState createState() => __ParticipantsBottomSheetState();
}

class __ParticipantsBottomSheetState extends State<_ParticipantsBottomSheet> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _participants = [];

  @override
  void initState() {
    super.initState();
    _loadParticipants();
  }

  Future<void> _loadParticipants() async {
    final participants = await widget.apiService.fetchOpenPlayParticipants(widget.play['id']);
    if (mounted) {
      setState(() {
        _participants = participants;
        _isLoading = false;
      });
    }
  }

  Future<void> _updateStatus(String email, String status, int index) async {
    final success = await widget.apiService.updateOpenPlayParticipantStatus(email, widget.play['id'].toString(), status);
    if (success && mounted) {
      setState(() {
        String oldStatus = _participants[index]['status'] ?? 'pending';
        _participants[index]['status'] = status;
        
        int guestCount = int.tryParse(_participants[index]['guest_count']?.toString() ?? '0') ?? 0;
        int currentParticipants = int.tryParse(widget.play['current_participants']?.toString() ?? '0') ?? 0;
        
        if (oldStatus != 'rejected' && status == 'rejected') {
           widget.play['current_participants'] = (currentParticipants - (1 + guestCount)).clamp(0, 9999).toString();
           widget.onStatusChanged();
        } else if (oldStatus == 'rejected' && status != 'rejected') {
           widget.play['current_participants'] = (currentParticipants + (1 + guestCount)).toString();
           widget.onStatusChanged();
        }
      });
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update status')));
    }
  }

  void _showReceiptDialog(String base64Image) {
    if (base64Image.isEmpty) return;
    
    // Check if it has a data URI scheme and strip it
    String b64 = base64Image;
    if (b64.contains(',')) {
      b64 = b64.split(',').last;
    }

    try {
      final Uint8List imageBytes = base64Decode(b64);
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: Text('Payment Receipt', style: TextStyle(fontSize: 16)),
                automaticallyImplyLeading: false,
                actions: [IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.pop(context))],
              ),
              Image.memory(imageBytes, fit: BoxFit.contain),
            ],
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load image.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.softWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Joiners', style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Divider(height: 1),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _participants.isEmpty
                    ? Center(child: Text("No one has joined yet.", style: TextStyle(color: Colors.grey.shade600)))
                    : ListView.separated(
                        itemCount: _participants.length,
                        separatorBuilder: (context, index) => Divider(),
                        itemBuilder: (context, index) {
                          final p = _participants[index];
                          final String name = p['full_name'] ?? 'Unknown User';
                          final bool hasProof = p['payment_proof'] != null && p['payment_proof'].toString().isNotEmpty;

                          final String status = p['status'] ?? 'pending';
                          final int guestCount = int.tryParse(p['guest_count']?.toString() ?? '0') ?? 0;
                          final String guestText = guestCount > 0 ? ' (+$guestCount Guests)' : '';

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primaryGreen.withOpacity(0.1),
                              child: Icon(Icons.person, color: AppColors.primaryGreen),
                            ),
                            title: Text('$name$guestText', style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p['user_email'] ?? ''),
                                SizedBox(height: 4),
                                if (status == 'pending')
                                  Row(
                                    children: [
                                      ElevatedButton(
                                        onPressed: () => _updateStatus(p['user_email'], 'approved', index),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: EdgeInsets.symmetric(horizontal: 12), minimumSize: Size(0, 30)),
                                        child: Text('Approve', style: TextStyle(fontSize: 12, color: AppColors.softWhite)),
                                      ),
                                      SizedBox(width: 8),
                                      OutlinedButton(
                                        onPressed: () => _updateStatus(p['user_email'], 'rejected', index),
                                        style: OutlinedButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 12), minimumSize: Size(0, 30), side: BorderSide(color: Colors.red)),
                                        child: Text('Reject', style: TextStyle(fontSize: 12, color: Colors.red)),
                                      ),
                                    ],
                                  )
                                else
                                  Text(
                                    status.toUpperCase(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: status == 'approved' ? Colors.green : Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Ref No.', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                Text(hasProof ? p['payment_proof'].toString() : 'N/A', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
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



class _EditOpenPlaySheet extends StatefulWidget {
  final Map<String, dynamic> play;
  final ApiService apiService;
  final VoidCallback onUpdated;

  const _EditOpenPlaySheet({
    Key? key,
    required this.play,
    required this.apiService,
    required this.onUpdated,
  }) : super(key: key);

  @override
  __EditOpenPlaySheetState createState() => __EditOpenPlaySheetState();
}

class __EditOpenPlaySheetState extends State<_EditOpenPlaySheet> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  late String _openPlayType;
  late TextEditingController _maxPlayersController;
  late TextEditingController _priceController;
  late TextEditingController _instructionsController;
  late TextEditingController _paymentDetailsController;

  @override
  void initState() {
    super.initState();
    _openPlayType = widget.play['open_play_type'] ?? 'DOUBLES';
    _maxPlayersController = TextEditingController(text: widget.play['open_play_max_players']?.toString() ?? '4');
    final String existingPrice = widget.play['open_play_price']?.toString() ?? '';
    final String existingInstructions = widget.play['open_play_instructions'] ?? '';
    
    _priceController = TextEditingController(
      text: existingPrice.isNotEmpty && existingPrice != '0' && existingPrice != '0.00' && existingPrice != '0.0' ? existingPrice : '150.00'
    );
    _instructionsController = TextEditingController(
      text: existingInstructions.isNotEmpty ? existingInstructions : 'Bring your own paddle and wear proper court shoes. See you on the court!'
    );
    _paymentDetailsController = TextEditingController(text: widget.play['open_play_payment_details'] ?? '');
  }

  @override
  void dispose() {
    _maxPlayersController.dispose();
    _priceController.dispose();
    _instructionsController.dispose();
    _paymentDetailsController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    List<String> ids = widget.play['id'].toString().split(',');
    bool allSuccess = true;
    
    for (String idStr in ids) {
      final int id = int.tryParse(idStr) ?? 0;
      if (id > 0) {
        final success = await widget.apiService.updateOpenPlay(id, {
          'openPlayType': _openPlayType,
          'openPlayMaxPlayers': int.tryParse(_maxPlayersController.text) ?? 4,
          'openPlayPrice': double.tryParse(_priceController.text) ?? 0.0,
          'openPlayInstructions': _instructionsController.text,
          'openPlayPaymentDetails': _paymentDetailsController.text,
        });
        if (!success) {
          allSuccess = false;
        }
      }
    }
    
    setState(() => _isSaving = false);
    
    if (allSuccess) {
      Navigator.pop(context);
      widget.onUpdated();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Open Play updated successfully!'), backgroundColor: AppColors.primaryGreen),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update Open Play.'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Edit Open Play', style: TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.richBlack)),
                    IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                SizedBox(height: 16),
                _buildLabel('Game Format'),
                DropdownButtonFormField<String>(
                  value: _openPlayType,
                  decoration: _inputDecoration(),
                  items: ['SINGLES', 'DOUBLES', 'MIXED'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _openPlayType = newValue!;
                    });
                  },
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Max Players'),
                          TextFormField(
                            controller: _maxPlayersController,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration(),
                            validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Price (₱) per player'),
                          TextFormField(
                            controller: _priceController,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            decoration: _inputDecoration(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                _buildLabel('Instructions (Optional)'),
                TextFormField(
                  controller: _instructionsController,
                  maxLines: 3,
                  decoration: _inputDecoration().copyWith(hintText: 'e.g., Bring your own paddle'),
                ),
                SizedBox(height: 16),
                _buildLabel('Payment Details (Optional)'),
                TextFormField(
                  controller: _paymentDetailsController,
                  maxLines: 2,
                  decoration: _inputDecoration().copyWith(hintText: 'e.g., GCash: 09123456789'),
                ),
                SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSaving 
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.primaryGreen)),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}

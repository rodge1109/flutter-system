import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class BookingLogsWidget extends StatefulWidget {
  final String? venueFilter;
  final String? ownerEmailFilter;

  const BookingLogsWidget({
    Key? key,
    this.venueFilter,
    this.ownerEmailFilter,
  }) : super(key: key);

  @override
  State<BookingLogsWidget> createState() => _BookingLogsWidgetState();
}

class _BookingLogsWidgetState extends State<BookingLogsWidget> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _logs = [];
  bool _isLoading = true;
  String _selectedStage = 'ALL'; // ALL, PAYMENT_VIEWED, FAILED, CONFIRMED, SUBMITTING

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchLogs() async {
    setState(() => _isLoading = true);
    final logs = await _apiService.fetchBookingLogs(
      venue: widget.venueFilter,
      limit: 150,
    );
    if (mounted) {
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    }
  }

  List<dynamic> get _filteredLogs {
    final query = _searchController.text.trim().toLowerCase();
    return _logs.where((log) {
      final stage = (log['stage'] ?? '').toString().toUpperCase();
      if (_selectedStage != 'ALL' && stage != _selectedStage) {
        return false;
      }
      if (query.isEmpty) return true;

      final name = (log['customer_name'] ?? '').toString().toLowerCase();
      final email = (log['customer_email'] ?? '').toString().toLowerCase();
      final phone = (log['customer_phone'] ?? '').toString().toLowerCase();
      final ref = (log['reference_number'] ?? '').toString().toLowerCase();
      final courts = (log['court_names'] ?? '').toString().toLowerCase();
      final venue = (log['venue_name'] ?? '').toString().toLowerCase();

      return name.contains(query) ||
          email.contains(query) ||
          phone.contains(query) ||
          ref.contains(query) ||
          courts.contains(query) ||
          venue.contains(query);
    }).toList();
  }

  Color _getStageColor(String stage) {
    switch (stage.toUpperCase()) {
      case 'CONFIRMED':
        return Colors.green;
      case 'PAYMENT_VIEWED':
        return Colors.amber.shade800;
      case 'SUBMITTING':
        return Colors.blue;
      case 'FAILED':
        return Colors.red;
      default:
        return Colors.grey.shade700;
    }
  }

  String _formatStageLabel(String stage) {
    switch (stage.toUpperCase()) {
      case 'CONFIRMED':
        return 'Confirmed';
      case 'PAYMENT_VIEWED':
        return 'Payment Viewed (Unconfirmed)';
      case 'SUBMITTING':
        return 'Submitting';
      case 'FAILED':
        return 'Failed';
      default:
        return stage;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour % 12 == 0 ? 12 : dt.hour % 12}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? "PM" : "AM"}';
    } catch (_) {
      return dateStr;
    }
  }

  Future<void> _callPhone(String phone) async {
    if (phone.isEmpty) return;
    final uri = Uri.parse('tel:${phone.replaceAll(RegExp(r'[^0-9+]'), '')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _sendSms(String phone) async {
    if (phone.isEmpty) return;
    final uri = Uri.parse('sms:${phone.replaceAll(RegExp(r'[^0-9+]'), '')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _manualCreateBooking(Map<String, dynamic> log) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Manual Confirm Booking'),
        content: Text(
          'Do you want to confirm this booking for ${log['customer_name'] ?? 'the customer'} on ${log['court_names']} at ${log['time_slots']} (${log['booking_date']?.toString().split("T")[0]})?\n\n'
          'Total Amount: ₱${log['total_amount']}\n'
          'GCash Ref: ${log['reference_number'] ?? "N/A"}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Confirm & Save Booking', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final appointmentData = {
      'fullName': log['customer_name'] ?? '',
      'phoneNumber': log['customer_phone'] ?? '',
      'email': log['customer_email'] ?? '',
      'serviceType': log['court_names'] ?? '',
      'preferredDate': log['booking_date']?.toString().split('T')[0] ?? '',
      'preferredTime': log['time_slots'] ?? '',
      'paymentMethod': log['payment_method'] ?? 'GCash',
      'totalAmount': double.tryParse(log['total_amount']?.toString() ?? '0') ?? 0.0,
      'proofOfPayment': log['reference_number'] != null ? 'MANUAL: ${log['reference_number']}' : 'MANUAL_CONFIRMED',
      'notes': 'Manually approved from Booking Audit Log #${log['id']}',
    };

    final success = await _apiService.submitAppointment(appointmentData);
    if (success) {
      await _apiService.logBookingAttempt(
        logId: log['id'],
        customerName: log['customer_name'] ?? '',
        customerEmail: log['customer_email'] ?? '',
        customerPhone: log['customer_phone'] ?? '',
        venueName: log['venue_name'] ?? '',
        courtNames: log['court_names'] ?? '',
        bookingDate: log['booking_date']?.toString().split('T')[0] ?? '',
        timeSlots: log['time_slots'] ?? '',
        totalAmount: double.tryParse(log['total_amount']?.toString() ?? '0') ?? 0.0,
        paymentMethod: log['payment_method'] ?? 'GCash',
        referenceNumber: log['reference_number'],
        stage: 'CONFIRMED',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking manually confirmed and added to calendar!'),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
        _fetchLogs();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to confirm booking. Timeslot might be blocked.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Search & Refresh Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by Name, Phone, Email, or Ref #...',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                    prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey.shade600),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.richBlack),
                onPressed: _fetchLogs,
                tooltip: 'Refresh Logs',
              ),
            ],
          ),
        ),

        // Filter Stage Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
          child: Row(
            children: [
              _buildFilterChip('ALL', 'All (${_logs.length})'),
              const SizedBox(width: 8),
              _buildFilterChip('PAYMENT_VIEWED', '🟡 Unconfirmed (${_logs.where((l) => (l['stage'] ?? '').toString().toUpperCase() == 'PAYMENT_VIEWED').length})'),
              const SizedBox(width: 8),
              _buildFilterChip('FAILED', '🔴 Failed (${_logs.where((l) => (l['stage'] ?? '').toString().toUpperCase() == 'FAILED').length})'),
              const SizedBox(width: 8),
              _buildFilterChip('CONFIRMED', '🟢 Confirmed (${_logs.where((l) => (l['stage'] ?? '').toString().toUpperCase() == 'CONFIRMED').length})'),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Logs List
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(40.0),
            child: Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
          )
        else if (_filteredLogs.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40.0),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.history_toggle_off_rounded, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text('No booking attempt logs found.', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredLogs.length,
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            itemBuilder: (context, index) {
              final log = _filteredLogs[index];
              final stage = (log['stage'] ?? 'UNKNOWN').toString().toUpperCase();
              final stageColor = _getStageColor(stage);
              final String customerName = log['customer_name'] ?? 'Unknown Customer';
              final String phone = log['customer_phone'] ?? '';
              final String email = log['customer_email'] ?? '';
              final String courtNames = log['court_names'] ?? 'Court';
              final String timeSlots = log['time_slots'] ?? '-';
              final String bDate = log['booking_date']?.toString().split('T')[0] ?? '-';
              final String amount = log['total_amount'] != null ? '₱${log['total_amount']}' : '₱0.00';
              final String? refNo = log['reference_number'];
              final String? errorMsg = log['error_message'];
              final String createdAtStr = _formatDate(log['created_at']);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: stage == 'PAYMENT_VIEWED' 
                        ? Colors.amber.shade300 
                        : (stage == 'FAILED' ? Colors.red.shade300 : Colors.grey.shade200),
                    width: stage == 'PAYMENT_VIEWED' || stage == 'FAILED' ? 1.5 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stage Header & Time
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: stageColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: stageColor.withOpacity(0.4)),
                          ),
                          child: Text(
                            _formatStageLabel(stage),
                            style: TextStyle(
                              color: stageColor,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          createdAtStr,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Customer Name & Court
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                customerName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.richBlack),
                              ),
                              if (email.isNotEmpty) ...[
                                const SizedBox(height: 1),
                                Text(
                                  email,
                                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                                ),
                              ],
                              const SizedBox(height: 2),
                              Text(
                                '$courtNames • $bDate',
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                              ),
                              Text(
                                'Timeslot(s): $timeSlots',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              amount,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.primaryGreen),
                            ),
                            Text(
                              log['payment_method'] ?? 'GCash',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Reference Number
                    if (refNo != null && refNo.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.tag, size: 14, color: Colors.grey.shade700),
                            const SizedBox(width: 4),
                            Text(
                              'GCash Ref: $refNo',
                              style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.richBlack),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Error message banner
                    if (errorMsg != null && errorMsg.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          'Error: $errorMsg',
                          style: TextStyle(color: Colors.red.shade800, fontSize: 11.5),
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),
                    Divider(height: 1, color: Colors.grey.shade200),
                    const SizedBox(height: 8),

                    // Actions Row
                    Row(
                      children: [
                        if (phone.isNotEmpty) ...[
                          Text(phone, style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.call, size: 18, color: AppColors.primaryGreen),
                            onPressed: () => _callPhone(phone),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                            tooltip: 'Call Customer',
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.message, size: 18, color: Colors.blue),
                            onPressed: () => _sendSms(phone),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                            tooltip: 'SMS Customer',
                          ),
                        ],
                        const Spacer(),
                        if (stage != 'CONFIRMED')
                          ElevatedButton.icon(
                            icon: const Icon(Icons.check_circle_outline, size: 14, color: Colors.white),
                            label: const Text('Confirm Booking', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _manualCreateBooking(log),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildFilterChip(String stage, String label) {
    final isSelected = _selectedStage == stage;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primaryGreen.withOpacity(0.15),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppColors.primaryGreen : AppColors.richBlack,
      ),
      side: BorderSide(color: isSelected ? AppColors.primaryGreen : Colors.grey.shade300),
      onSelected: (val) {
        if (val) setState(() => _selectedStage = stage);
      },
    );
  }
}

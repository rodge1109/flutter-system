import 'package:flutter_project/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/api_service.dart';

class ManageCourtScheduleScreen extends StatefulWidget {
  final Map<String, dynamic> court;
  final String ownerEmail;

  const ManageCourtScheduleScreen({
    Key? key,
    required this.court,
    required this.ownerEmail,
  }) : super(key: key);

  @override
  _ManageCourtScheduleScreenState createState() => _ManageCourtScheduleScreenState();
}

class _ManageCourtScheduleScreenState extends State<ManageCourtScheduleScreen> {
  final ApiService _apiService = ApiService();
  
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();
  
  List<String> _availableSlots = [];
  List<String> _bookedSlots = [];
  List<String> _blockedSlots = [];
  bool _isLoadingSlots = false;

  @override
  void initState() {
    super.initState();
    _fetchSlotsForDate(_selectedDay!);
  }

  Future<void> _fetchSlotsForDate(DateTime date) async {
    setState(() => _isLoadingSlots = true);
    final dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final slots = await _apiService.fetchAvailableSlots(dateString, widget.court['name'] ?? '');
    
    if (mounted) {
      setState(() {
        _availableSlots = slots['availableSlots'] ?? [];
        _bookedSlots = slots['bookedSlots'] ?? [];
        _blockedSlots = slots['blockedSlots'] ?? [];
        _isLoadingSlots = false;
      });
    }
  }

  void _showSlotOptions(String time, String status) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Manage $time',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Current Status: ${status.toUpperCase()}',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              SizedBox(height: 24),
              if (status == 'booked') ...[
                _buildOptionButton(
                  icon: Icons.cancel_outlined,
                  label: 'Cancel Reservation',
                  color: Colors.red,
                  onTap: () => _handleCancelReservation(time),
                ),
              ] else if (status == 'available') ...[
                _buildOptionButton(
                  icon: Icons.build_circle_outlined,
                  label: 'Block Slot / Offline Booking',
                  color: Colors.orange,
                  onTap: () => _handleBlockSlot(time),
                ),
              ] else if (status == 'blocked') ...[
                _buildOptionButton(
                  icon: Icons.check_circle_outline,
                  label: 'Make Available for Rent',
                  color: Colors.green,
                  onTap: () => _handleUnblockSlot(time),
                ),
              ],
              SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: () {
        Navigator.pop(context); // Close bottom sheet
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(12),
          color: color.withOpacity(0.05),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCancelReservation(String time) async {
    final dateString = '${_selectedDay!.year}-${_selectedDay!.month.toString().padLeft(2, '0')}-${_selectedDay!.day.toString().padLeft(2, '0')}';
    final success = await _apiService.cancelCourtReservation(widget.court['name'] ?? '', dateString, time);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reservation cancelled')));
      _fetchSlotsForDate(_selectedDay!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to cancel reservation')));
    }
  }

  Future<void> _handleBlockSlot(String time) async {
    final TextEditingController _nameController = TextEditingController();
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Block Slot'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter player name for offline booking, or leave blank for maintenance.'),
            SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Player Name (Optional)',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: AppColors.softWhite),
            child: Text('Block Slot')
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final dateString = '${_selectedDay!.year}-${_selectedDay!.month.toString().padLeft(2, '0')}-${_selectedDay!.day.toString().padLeft(2, '0')}';
    final success = await _apiService.blockCourtSlot(
      widget.ownerEmail, 
      widget.court['name'] ?? '', 
      dateString, 
      time,
      playerName: _nameController.text.trim(),
    );
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Slot blocked successfully')));
      _fetchSlotsForDate(_selectedDay!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to block slot')));
    }
  }

  Future<void> _handleUnblockSlot(String time) async {
    final dateString = '${_selectedDay!.year}-${_selectedDay!.month.toString().padLeft(2, '0')}-${_selectedDay!.day.toString().padLeft(2, '0')}';
    final success = await _apiService.unblockCourtSlot(widget.court['name'] ?? '', dateString, time);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Slot is now available')));
      _fetchSlotsForDate(_selectedDay!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to make slot available')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamWhite,
      appBar: AppBar(
        title: Text('Manage ${widget.court['name'] ?? 'Court'}', style: TextStyle(color: AppColors.richBlack, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.softWhite,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.richBlack),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.softWhite,
            child: TableCalendar(
              firstDay: DateTime.now(),
              lastDay: DateTime.now().add(Duration(days: 90)),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                if (!isSameDay(_selectedDay, selectedDay)) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                  _fetchSlotsForDate(selectedDay);
                }
              },
              calendarStyle: CalendarStyle(
                selectedDecoration: BoxDecoration(
                  color: Color(0xFFE2F999),
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: TextStyle(color: AppColors.richBlack, fontWeight: FontWeight.bold),
                todayDecoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                todayTextStyle: TextStyle(color: AppColors.richBlack),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: _isLoadingSlots
                ? Center(child: CircularProgressIndicator())
                : _buildTimeSlots(),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSlots() {
    List<String> allSlots = [];
    for (int i = 0; i < 24; i++) {
      int h = i % 12 == 0 ? 12 : i % 12;
      String ampm = i < 12 ? 'AM' : 'PM';
      allSlots.add('$h:00 $ampm');
    }
    
    // Create a time mapping based on current time to gray out past slots today
    final now = DateTime.now();
    final isToday = isSameDay(_selectedDay, now);
    
    return GridView.builder(
      padding: EdgeInsets.all(24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: allSlots.length,
      itemBuilder: (context, index) {
        final time = allSlots[index];
        
        bool isPast = false;
        if (isToday) {
          int hour = index;
          if (hour < now.hour) {
            isPast = true;
          } else if (hour == now.hour && now.minute > 0) {
            isPast = true;
          }
        }

        String status = 'available';
        if (_bookedSlots.contains(time)) {
          status = 'booked';
        } else if (_blockedSlots.contains(time)) {
          status = 'blocked';
        }
        
        Color bgColor = AppColors.softWhite;
        Color textColor = AppColors.richBlack;
        Color borderColor = Colors.grey.shade300;
        
        if (isPast) {
          bgColor = Colors.grey.shade100;
          textColor = Colors.grey.shade400;
          borderColor = Colors.grey.shade200;
        } else if (status == 'booked') {
          bgColor = Colors.red.shade50;
          textColor = Colors.red.shade700;
          borderColor = Colors.red.shade200;
        } else if (status == 'blocked') {
          bgColor = Colors.orange.shade50;
          textColor = Colors.orange.shade700;
          borderColor = Colors.orange.shade200;
        } else {
          bgColor = AppColors.softWhite;
          textColor = AppColors.richBlack;
          borderColor = Colors.grey.shade300;
        }

        return InkWell(
          onTap: isPast ? null : () => _showSlotOptions(time, status),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                time,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

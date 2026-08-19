import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_project/theme/app_colors.dart';
import '../widgets/custom_paddle_icon.dart';

class AllOpenPlaysScreen extends StatefulWidget {
  final List<dynamic> openPlays;
  final Function(Map<String, dynamic>) onJoinPlay;
  final Function(Map<String, dynamic>) onViewJoiners;

  const AllOpenPlaysScreen({
    Key? key,
    required this.openPlays,
    required this.onJoinPlay,
    required this.onViewJoiners,
  }) : super(key: key);

  @override
  _AllOpenPlaysScreenState createState() => _AllOpenPlaysScreenState();
}

class _AllOpenPlaysScreenState extends State<AllOpenPlaysScreen> {
  DateTime? _selectedDate;
  
  @override
  void initState() {
    super.initState();
    // Default to 'All' (null)
    _selectedDate = null;
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

  List<dynamic> get _filteredPlays {
    if (_selectedDate == null) return widget.openPlays;
    
    return widget.openPlays.where((play) {
      final dateStr = play['preferred_date']?.split('T')[0];
      if (dateStr == null) return false;
      try {
        final playDate = DateTime.parse(dateStr);
        return playDate.year == _selectedDate!.year &&
               playDate.month == _selectedDate!.month &&
               playDate.day == _selectedDate!.day;
      } catch (e) {
        return false;
      }
    }).toList();
  }

  Widget _buildDateSelector() {
    final now = DateTime.now();
    final List<DateTime?> dates = [null]; // null represents 'All'
    for (int i = 0; i < 14; i++) {
      dates.add(now.add(Duration(days: i)));
    }

    const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

    final displayDate = _selectedDate ?? now;
    final String monthYearStr = '${months[displayDate.month - 1]} ${displayDate.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Text(
            monthYearStr,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.deepTeal,
              letterSpacing: -0.5,
            ),
          ),
        ),
        Container(
          height: 85,
          margin: EdgeInsets.only(bottom: 16),
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: 24),
            scrollDirection: Axis.horizontal,
            itemCount: dates.length,
            separatorBuilder: (context, index) => SizedBox(width: 12),
            itemBuilder: (context, index) {
              final date = dates[index];
              
              bool isSelected = false;
              if (_selectedDate == null && date == null) {
                isSelected = true;
              } else if (_selectedDate != null && date != null) {
                isSelected = _selectedDate!.year == date.year &&
                             _selectedDate!.month == date.month &&
                             _selectedDate!.day == date.day;
              }
              
              if (date == null) {
                return GestureDetector(
                  onTap: () => setState(() => _selectedDate = null),
                  child: Container(
                    width: 55,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primaryGreen : AppColors.softWhite,
                      borderRadius: BorderRadius.circular(40), // Pill shape
                      border: Border.all(color: isSelected ? Colors.transparent : Colors.grey.shade300),
                      boxShadow: isSelected ? [BoxShadow(color: AppColors.primaryGreen.withOpacity(0.3), blurRadius: 8, offset: Offset(0, 4))] : null,
                    ),
                    child: Center(
                      child: Text('All', style: TextStyle(
                        color: isSelected ? AppColors.softWhite : AppColors.richBlack,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      )),
                    ),
                  ),
                );
              }

              final dayStr = weekdays[date.weekday - 1];
              final dayNum = date.day.toString();
              
              return GestureDetector(
                onTap: () => setState(() => _selectedDate = date),
                child: Container(
                  width: 55,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryGreen : AppColors.softWhite,
                    borderRadius: BorderRadius.circular(40), // Pill shape
                    border: Border.all(color: isSelected ? Colors.transparent : Colors.grey.shade300),
                    boxShadow: isSelected ? [BoxShadow(color: AppColors.primaryGreen.withOpacity(0.3), blurRadius: 8, offset: Offset(0, 4))] : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(dayStr, style: TextStyle(
                        color: isSelected ? AppColors.softWhite.withOpacity(0.8) : Colors.grey.shade500,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      )),
                      SizedBox(height: 6),
                      Text(dayNum, style: TextStyle(
                        color: isSelected ? AppColors.softWhite : AppColors.richBlack,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      )),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayedPlays = _filteredPlays;

    return Scaffold(
      backgroundColor: AppColors.creamWhite,
      appBar: AppBar(
        title: Text('All Open Plays', style: TextStyle(color: AppColors.richBlack, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.richBlack),
      ),
      body: Column(
        children: [
          _buildDateSelector(),
          Expanded(
            child: displayedPlays.isEmpty
                ? Center(
                    child: Text(
                      'No open plays found for this date.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: displayedPlays.length,
                    separatorBuilder: (context, index) => Divider(
                      indent: 72,
                      height: 1,
                      thickness: 0.5,
                      color: Colors.grey.shade300,
                    ),
                    itemBuilder: (context, index) {
                      final play = displayedPlays[index];
                      final bool isFull = (play['spots_left'] ?? 0) <= 0;
                      final String rawTimeStr = _normalizeTime(play['preferred_time'] ?? '');
                      final String timeStr = rawTimeStr.replaceAll(':00', '').replaceAll(' AM', 'AM').replaceAll(' PM', 'PM');
                      
                      String month = '';
                      String day = '';
                      try {
                        final date = DateTime.parse(play['preferred_date']?.split('T')[0] ?? '');
                        const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
                        month = months[date.month - 1];
                        day = date.day.toString();
                      } catch(e) {
                        month = 'TBA';
                        day = '-';
                      }

                      final content = Container(
                        color: Colors.grey.shade50,
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryGreen.withOpacity(0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: CustomPaddleIcon(color: AppColors.deepTeal, size: 22),
                                ),
                                if (!isFull)
                                  Positioned(
                                    top: -4,
                                    left: -4,
                                    child: Container(
                                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.accentLime,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text('NEW', style: TextStyle(color: AppColors.richBlack, fontSize: 8, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                if (isFull)
                                  Positioned(
                                    top: -4,
                                    left: -4,
                                    child: Container(
                                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text('FULL', style: TextStyle(color: AppColors.softWhite, fontSize: 8, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(play['service_type'] ?? 'Court', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey.shade800), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ),
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Icon(Icons.person, size: 14, color: AppColors.richBlack),
                                          SizedBox(height: 2),
                                          Builder(
                                            builder: (context) {
                                              int maxP = int.tryParse(play['open_play_max_players']?.toString() ?? '4') ?? 4;
                                              int spotsL = int.tryParse(play['spots_left']?.toString() ?? '0') ?? 0;
                                              int joinedP = maxP - spotsL;
                                              if (joinedP < 0) joinedP = 0;
                                              return Text(isFull ? 'FULL' : '$joinedP/$maxP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12));
                                            }
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Text('Host: ${play['host_name'] ?? 'Unknown'}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                  SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade600),
                                      SizedBox(width: 4),
                                      Text('$month $day at $timeStr', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                    ],
                                  ),
                                  SizedBox(height: 2),
                                  Row(
                                    children: [
                                      if (play['open_play_type'] != null && play['open_play_type'].toString().isNotEmpty)
                                        Container(
                                          margin: EdgeInsets.only(right: 8),
                                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryGreen.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(play['open_play_type'].toString().toUpperCase(), style: TextStyle(color: AppColors.primaryGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ),
                                      Icon(Icons.location_on, size: 12, color: Colors.grey.shade600),
                                      SizedBox(width: 4),
                                      Expanded(child: Text(play['address'] ?? 'Cayang', style: TextStyle(color: Colors.grey.shade600, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                      // Share button
                                      GestureDetector(
                                        onTap: () {
                                          final String playId = play['id'].toString().split(',').first;
                                          final String url = '${Uri.base.toString().split('?')[0]}?openplay=$playId';
                                          Clipboard.setData(ClipboardData(text: url));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Share link copied to clipboard!'), backgroundColor: AppColors.primaryGreen, duration: Duration(seconds: 3)),
                                          );
                                        },
                                        child: Container(
                                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                                          child: Row(
                                            children: [
                                              Icon(Icons.share, color: Colors.grey.shade600, size: 12),
                                              SizedBox(width: 4),
                                              Text('Share', style: TextStyle(color: Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                      
                      return GestureDetector(
                        onTap: () {
                          widget.onViewJoiners(play);
                        },
                        child: content,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

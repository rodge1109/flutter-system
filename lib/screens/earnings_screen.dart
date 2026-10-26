import 'package:flutter_project/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';
import 'statement_of_account_screen.dart';

class EarningsScreen extends StatefulWidget {
  final String? ownerEmail;
  final String? venueName;

  EarningsScreen({this.ownerEmail, this.venueName});

  @override
  _EarningsScreenState createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  
  DateTimeRange? _selectedDateRange;
  
  double _grossEarnings = 0;
  double _totalServiceFee = 0;
  double _totalNetEarnings = 0;
  List<dynamic> _transactions = [];

  @override
  void initState() {
    super.initState();
    _fetchEarnings();
  }

  Future<void> _fetchEarnings() async {
    String? email = widget.ownerEmail;
    
    if (email == null || email.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final userStr = prefs.getString('user');
      if (userStr != null) {
        try {
          final userObj = json.decode(userStr);
          email = userObj['email'];
        } catch (e) {
          print('Error parsing user data: $e');
        }
      }
    }
    
    if (email != null && email.isNotEmpty) {
      String? startDate;
      String? endDate;
      if (_selectedDateRange != null) {
        startDate = DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start);
        endDate = DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end);
      }

      // Fetch owner courts to map court names to venue names (e.g. "Court N" -> "7ten Pickleyard")
      final Map<String, String> courtToVenueMap = {};
      final Set<String> ownerVenueNames = {};
      try {
        final courts = await _apiService.fetchOwnerCourts(email);
        for (var c in courts) {
          if (c is Map) {
            String cName = (c['name'] ?? '').toString().trim().toLowerCase();
            String vName = (c['venue_name'] ?? c['venue'] ?? c['name'] ?? '').toString().trim().toLowerCase();
            String cleanC = cName.replaceAll(RegExp(r'\s*\([^)]*\)'), '').split('-')[0].trim();
            String cleanV = vName.replaceAll(RegExp(r'\s*\([^)]*\)'), '').split('-')[0].trim();
            if (cName.isNotEmpty && vName.isNotEmpty) {
              courtToVenueMap[cName] = vName;
              courtToVenueMap[cleanC] = cleanV;
            }
            if (vName.isNotEmpty) ownerVenueNames.add(vName);
            if (cleanV.isNotEmpty) ownerVenueNames.add(cleanV);
          }
        }
      } catch (_) {}

      final data = await _apiService.fetchOwnerEarnings(email, startDate: startDate, endDate: endDate);
      if (data['success'] == true) {
        final List rawTransactions = data['transactions'] ?? [];

        // Filter transactions to selected venueName if provided, and exclude cancelled bookings
        final List filteredRaw = rawTransactions.where((tx) {
          final status = (tx['status'] ?? '').toString().toLowerCase().trim();
          if (status == 'cancelled') return false;

          if (widget.venueName == null || widget.venueName!.trim().isEmpty) return true;

          String targetV = widget.venueName!.trim().toLowerCase();
          String cleanTarget = targetV.replaceAll(RegExp(r'\s*\([^)]*\)'), '').split('-')[0].trim();

          // 1. Direct venue_name field match (from backend or merged data)
          String txVenue = (tx['venue_name'] ?? '').toString().trim().toLowerCase();
          String cleanTxVenue = txVenue.replaceAll(RegExp(r'\s*\([^)]*\)'), '').split('-')[0].trim();
          if (txVenue.isNotEmpty) {
            if (txVenue == targetV || cleanTxVenue == cleanTarget || txVenue.contains(cleanTarget) || targetV.contains(cleanTxVenue)) {
              return true;
            }
          }

          // 2. Direct court_name / service_type match
          String txCourt = (tx['court_name'] ?? tx['service_type'] ?? '').toString().trim().toLowerCase();
          String cleanTxCourt = txCourt.replaceAll(RegExp(r'\s*\([^)]*\)'), '').split('-')[0].trim();
          if (txCourt.isNotEmpty) {
            if (txCourt == targetV || cleanTxCourt == cleanTarget || txCourt.contains(cleanTarget) || targetV.contains(cleanTxCourt)) {
              return true;
            }
          }

          // 3. Match via owner's registered courts (e.g. "Court N" / "Court S" mapped to "7ten Pickleyard")
          if (courtToVenueMap.containsKey(txCourt) || courtToVenueMap.containsKey(cleanTxCourt)) {
            String mappedVenue = (courtToVenueMap[txCourt] ?? courtToVenueMap[cleanTxCourt] ?? '').toLowerCase();
            String cleanMapped = mappedVenue.replaceAll(RegExp(r'\s*\([^)]*\)'), '').split('-')[0].trim();
            if (mappedVenue == targetV || cleanMapped == cleanTarget || mappedVenue.contains(cleanTarget) || targetV.contains(cleanMapped)) {
              return true;
            }
          }

          // 4. If the owner only has courts for this target venue
          if (ownerVenueNames.contains(targetV) || ownerVenueNames.contains(cleanTarget)) {
            return true;
          }

          // 5. If this screen was opened specifically for an owner's email, all transactions from fetchOwnerEarnings belong to this owner
          if (widget.ownerEmail != null && widget.ownerEmail!.trim().isNotEmpty) {
            return true;
          }

          return false;
        }).toList();
        
        // Group transactions placed in the same checkout session
        Map<String, Map<String, dynamic>> groupedMap = {};

        for (var item in filteredRaw) {
          Map<String, dynamic> tx = Map<String, dynamic>.from(item);
          String player = (tx['player_name'] ?? tx['full_name'] ?? 'Player').toString().trim();
          String court = (tx['court_name'] ?? tx['service_type'] ?? 'Court').toString().trim();
          String date = (tx['preferred_date'] ?? tx['appointment_date'] ?? tx['date'] ?? '').toString().trim();
          String createdAt = (tx['created_at'] ?? '').toString().trim();
          String createdMinute = createdAt.length >= 16 ? createdAt.substring(0, 16) : createdAt;

          String groupKey = '${player}_${court}_${date}_$createdMinute';

          if (!groupedMap.containsKey(groupKey)) {
            groupedMap[groupKey] = {
              'id': tx['id'],
              'all_ids': <dynamic>[],
              'player_name': player,
              'court_name': court,
              'created_at': tx['created_at'],
              'preferred_date': tx['preferred_date'] ?? tx['appointment_date'] ?? tx['date'],
              'time_list': <String>[],
              'amount': 0.0,
              'total_amount': tx['total_amount'],
              'is_open_play': tx['is_open_play'] == true,
              'payment_reference': tx['payment_reference'],
              'proof_of_payment': tx['proof_of_payment'],
              'payment_ref': tx['payment_ref'],
              'ref_no': tx['ref_no'],
              'agent_code': tx['agent_code'],
              'order_number': tx['order_number'],
              'booking_type': tx['booking_type'],
              'status': tx['status'],
              'payment_method': tx['payment_method'],
              'payment_type': tx['payment_type'],
            };
          } else {
            for (var key in ['payment_reference', 'proof_of_payment', 'payment_ref', 'ref_no', 'agent_code', 'order_number', 'booking_type', 'status', 'payment_method', 'payment_type', 'total_amount']) {
              if (tx[key] != null && tx[key].toString().trim().isNotEmpty) {
                if ((groupedMap[groupKey]![key] ?? '').toString().trim().isEmpty) {
                  groupedMap[groupKey]![key] = tx[key];
                }
              }
            }
          }

          List<dynamic> ids = groupedMap[groupKey]!['all_ids'];
          if (tx['id'] != null && !ids.contains(tx['id'])) {
            ids.add(tx['id']);
          }

          double slotAmount = (tx['total_amount'] != null && tx['total_amount'].toString().trim().isNotEmpty)
              ? (double.tryParse(tx['total_amount'].toString()) ?? 0.0)
              : (tx['amount'] ?? tx['gross'] ?? tx['price'] ?? 0).toDouble();
          groupedMap[groupKey]!['amount'] = (groupedMap[groupKey]!['amount'] as double) + slotAmount;

          String slotTime = (tx['preferred_time'] ?? tx['time'] ?? tx['timeslot'] ?? tx['slot'] ?? '').toString().trim();
          if (slotTime.isNotEmpty && !(groupedMap[groupKey]!['time_list'] as List<String>).contains(slotTime)) {
            (groupedMap[groupKey]!['time_list'] as List<String>).add(slotTime);
          }
        }

        List<Map<String, dynamic>> processedTransactions = [];
        double grossSum = 0;
        double feeSum = 0;
        double netSum = 0;

        for (var groupedTx in groupedMap.values) {
          List<String> times = List<String>.from(groupedTx['time_list']);
          int hours = times.isNotEmpty ? times.length : 1;

          // Fee rule: ₱15 per 5-hour block for the consolidated booking checkout transaction
          double fee = (hours / 5.0).ceil() * 15.0;
          double courtAmount = (groupedTx['amount'] as double);

          final bType = (groupedTx['booking_type'] ?? '').toString().toLowerCase().trim();
          final status = (groupedTx['status'] ?? '').toString().toLowerCase().trim();
          final pName = (groupedTx['player_name'] ?? groupedTx['full_name'] ?? '').toString().toLowerCase().trim();
          final pMethod = (groupedTx['payment_method'] ?? groupedTx['payment_type'] ?? '').toString().toLowerCase().trim();
          final pRef = (groupedTx['payment_reference'] ?? groupedTx['payment_ref'] ?? groupedTx['ref_no'] ?? '').toString().toLowerCase().trim();

          bool isOfflineBlock = bType == 'owner_block' ||
              bType == 'offline' ||
              bType == 'walkin' ||
              bType == 'walk-in' ||
              bType == 'maintenance' ||
              bType == 'maintenance_block' ||
              bType == 'block' ||
              bType.contains('offline') ||
              bType.contains('block') ||
              bType.contains('maintenance') ||
              bType.contains('walk') ||
              status == 'blocked' ||
              status == 'maintenance' ||
              status.contains('block') ||
              status.contains('maintenance') ||
              pName.contains('offline') ||
              pName.contains('walk-in') ||
              pName.contains('walkin') ||
              pName.contains('maintenance') ||
              pName.contains('block') ||
              pMethod == 'cash' ||
              pMethod == 'offline' ||
              pRef == 'offline';

          double gross;
          double net;

          if (isOfflineBlock) {
            // Offline booking or maintenance block: gross and net are zero
            gross = 0.0;
            net = 0.0;
            groupedTx['amount'] = 0.0;
            groupedTx['booking_type'] = 'owner_block';
          } else {
            // Gross = total amount received from player (Court Amount + ₱15 Service Fee = e.g. ₱215.00 / ₱815.00)
            gross = courtAmount + fee;
            // Net = net payout to court owner (e.g. ₱200.00 / ₱800.00)
            net = courtAmount;
          }

          groupedTx['grossAmount'] = gross;
          groupedTx['gross_amount'] = gross;
          groupedTx['serviceFee'] = fee;
          groupedTx['service_fee'] = fee;
          groupedTx['netEarnings'] = net;
          groupedTx['net_amount'] = net;
          groupedTx['court_net'] = net;
          groupedTx['hours'] = hours;

          if (times.isNotEmpty) {
            groupedTx['preferred_time'] = times.join(', ');
          }

          List<dynamic> ids = groupedTx['all_ids'];
          if (ids.length > 1) {
            groupedTx['id'] = '${ids.last} - #${ids.first} (${ids.length} hrs)';
          } else if (ids.isNotEmpty) {
            groupedTx['id'] = ids.first;
          }

          processedTransactions.add(groupedTx);
          grossSum += gross;
          feeSum += fee;
          netSum += net;
        }

        setState(() {
          _grossEarnings = processedTransactions.isNotEmpty ? grossSum : (data['grossEarnings'] ?? 0).toDouble();
          _totalServiceFee = feeSum;
          _totalNetEarnings = processedTransactions.isNotEmpty ? netSum : (data['totalNetEarnings'] ?? 0).toDouble();
          _transactions = processedTransactions;
          
          _transactions.sort((a, b) {
            try {
              String sA = (a['created_at'] ?? a['preferred_date'] ?? '').toString();
              String sB = (b['created_at'] ?? b['preferred_date'] ?? '').toString();
              DateTime dateA = _parseDateStandard(sA);
              DateTime dateB = _parseDateStandard(sB);
              return dateB.compareTo(dateA);
            } catch (e) {
              return 0;
            }
          });
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Failed to load earnings')),
          );
        }
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  DateTime _parseDateStandard(dynamic dateRaw) {
    if (dateRaw == null) return DateTime.now();
    String s = dateRaw.toString().trim();
    if (s.isEmpty) return DateTime.now();
    try {
      String clean = s.replaceAll(RegExp(r'Z$|[+-]\d{2}:?\d{2}$'), '');
      return DateTime.parse(clean);
    } catch (_) {
      try {
        return DateTime.parse(s);
      } catch (_) {
        return DateTime.now();
      }
    }
  }

  String _formatCurrency(double amount) {
    final format = NumberFormat.currency(locale: 'en_PH', symbol: 'P');
    return format.format(amount);
  }
  
  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return '';
    try {
      final date = _parseDateStandard(dateStr);
      return DateFormat('MMM dd, yyyy h:mm a').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return '';
    try {
      final date = _parseDateStandard(dateStr);
      return DateFormat('h:mm a').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  Map<String, List<dynamic>> _groupTransactionsByDate() {
    final Map<String, List<dynamic>> grouped = {};
    for (var tx in _transactions) {
      String dateStr = (tx['created_at'] ?? tx['preferred_date'] ?? '').toString();
      String dateOnly = '';
      try {
        final date = _parseDateStandard(dateStr);
        dateOnly = DateFormat('MMM dd, yyyy').format(date);
      } catch (e) {
        dateOnly = 'Unknown Date';
      }
      if (!grouped.containsKey(dateOnly)) {
        grouped[dateOnly] = [];
      }
      grouped[dateOnly]!.add(tx);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Earnings Dashboard', style: TextStyle(color: AppColors.richBlack, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: AppColors.softWhite,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.richBlack),
        actions: [
          IconButton(
            tooltip: 'Statement of Account',
            icon: const Icon(Icons.receipt_long_rounded, color: AppColors.primaryGreen),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StatementOfAccountScreen(
                    venueName: widget.venueName,
                    ownerEmail: widget.ownerEmail,
                    dateRange: _selectedDateRange,
                    grossEarnings: _grossEarnings,
                    totalServiceFee: _totalServiceFee,
                    totalNetEarnings: _totalNetEarnings,
                    transactions: _transactions,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.date_range, color: AppColors.primaryGreen),
            onPressed: () async {
              final DateTimeRange? picked = await showDateRangePicker(
                context: context,
                initialDateRange: _selectedDateRange,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
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
              if (picked != null && picked != _selectedDateRange) {
                setState(() {
                  _selectedDateRange = picked;
                });
                _fetchEarnings();
              }
            },
          ),
          if (_selectedDateRange != null)
            IconButton(
              icon: Icon(Icons.clear, color: Colors.redAccent),
              onPressed: () {
                setState(() {
                  _selectedDateRange = null;
                });
                _fetchEarnings();
              },
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : RefreshIndicator(
              onRefresh: _fetchEarnings,
              color: AppColors.primaryGreen,
              child: ListView(
                padding: EdgeInsets.all(16),
                children: [
                  if (_selectedDateRange != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        'Showing earnings for: ${DateFormat("MMM dd, yyyy").format(_selectedDateRange!.start)} - ${DateFormat("MMM dd, yyyy").format(_selectedDateRange!.end)}',
                        style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primaryGreen),
                      ),
                    ),
                  _buildSummaryCards(),
                  SizedBox(height: 24),
                  Text(
                    'Transaction History',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.richBlack),
                  ),
                  SizedBox(height: 12),
                  _transactions.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              children: [
                                Icon(Icons.receipt_long, size: 48, color: Colors.grey.shade400),
                                SizedBox(height: 16),
                                Text('No earnings yet', style: TextStyle(color: Colors.grey.shade500)),
                              ],
                            ),
                          ),
                        )
                      : Builder(
                          builder: (context) {
                            final grouped = _groupTransactionsByDate();
                            final keys = grouped.keys.toList();
                            return ListView.builder(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              itemCount: keys.length,
                              itemBuilder: (context, index) {
                                final dateKey = keys[index];
                                final dailyTxs = grouped[dateKey]!;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 24.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        dateKey,
                                        style: TextStyle(color: Colors.grey.shade700, fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                      SizedBox(height: 8),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: Colors.grey.shade200),
                                          boxShadow: [
                                            BoxShadow(color: AppColors.richBlack.withOpacity(0.02), blurRadius: 8, offset: Offset(0, 2))
                                          ],
                                        ),
                                        child: ListView.separated(
                                          shrinkWrap: true,
                                          physics: NeverScrollableScrollPhysics(),
                                          itemCount: dailyTxs.length,
                                          separatorBuilder: (context, idx) => Divider(height: 1, color: Colors.grey.shade200),
                                          itemBuilder: (context, idx) {
                                            return _buildTransactionCard(dailyTxs[idx]);
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          }
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCards() {
    return Column(
      children: [
        // Main Net Earnings Card
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryGreen, Color(0xFF168065)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: AppColors.primaryGreen.withOpacity(0.3), blurRadius: 12, offset: Offset(0, 6))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Net Earnings', style: TextStyle(color: AppColors.softWhite.withOpacity(0.70), fontSize: 14, fontWeight: FontWeight.w500)),
              SizedBox(height: 8),
              Text(
                _formatCurrency(_totalNetEarnings),
                style: TextStyle(fontFamily: 'Poppins', color: AppColors.softWhite, fontSize: 36, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        // Breakdown Row
        Row(
          children: [
            Expanded(
              child: _buildMiniCard('Gross Revenue', _grossEarnings, Icons.account_balance_wallet, Colors.blue),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _buildMiniCard('Service Fees', _totalServiceFee, Icons.money_off, Colors.red),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniCard(String title, double amount, IconData icon, Color iconColor) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.softWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: AppColors.richBlack.withOpacity(0.02), blurRadius: 8, offset: Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              SizedBox(width: 8),
              Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
          SizedBox(height: 12),
          Text(
            _formatCurrency(amount),
            style: TextStyle(fontFamily: 'Poppins', color: AppColors.richBlack, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> tx) {
    final gross = (tx['grossAmount'] ?? tx['amount'] ?? 0).toDouble();
    final net = (tx['netEarnings'] ?? 0).toDouble();
    final fee = (tx['serviceFee'] ?? 0).toDouble();
    final isTypeOpenPlay = tx['is_open_play'] == true;

    String bookingDate = '';
    dynamic rawDate = tx['preferred_date'] ?? tx['appointment_date'] ?? tx['date'];
    if (rawDate != null && rawDate.toString().trim().isNotEmpty) {
      try {
        DateTime parsed = DateTime.parse(rawDate.toString().split('T')[0]);
        bookingDate = DateFormat('MMM dd, yyyy').format(parsed);
      } catch (_) {
        bookingDate = rawDate.toString();
      }
    }

    String bookingTime = (tx['preferred_time'] ?? tx['time'] ?? tx['timeslot'] ?? tx['slot'] ?? '').toString().trim();

    bool isOfflineBlock = (tx['booking_type'] == 'owner_block') ||
                          (tx['player_name'] ?? tx['full_name'] ?? '').toString().toLowerCase().contains('offline');

    String _firstNonEmpty(List<dynamic> candidates) {
      for (var c in candidates) {
        if (c != null) {
          String s = c.toString().trim();
          if (s.isNotEmpty && s != 'null') {
            return s;
          }
        }
      }
      return '';
    }

    String paymentRef = '';
    if (!isOfflineBlock) {
      String rawRef = _firstNonEmpty([
        tx['payment_reference'],
        tx['ref_no'],
        tx['payment_ref'],
        tx['proof_of_payment'],
        tx['agent_code'],
      ]);
      if (rawRef.startsWith('data:') || rawRef.length > 60) {
        rawRef = _firstNonEmpty([
          tx['payment_reference'],
          tx['ref_no'],
          tx['payment_ref'],
          tx['agent_code'],
        ]);
      }
      if (rawRef.isEmpty && tx['order_number'] != null && tx['order_number'].toString().startsWith('ORD-')) {
        rawRef = tx['order_number'].toString();
      }
      paymentRef = rawRef;
    }

    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Date Created: ${_formatDate(tx['created_at'])}',
            style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx['court_name'] ?? 'Court',
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${tx['player_name']} • ${isTypeOpenPlay ? 'Open Play' : 'Booking'}',
                      style: TextStyle(color: Colors.black, fontSize: 12),
                    ),
                    if (bookingDate.isNotEmpty || bookingTime.isNotEmpty) ...[
                      SizedBox(height: 4),
                      Text(
                        '${bookingDate.isNotEmpty ? bookingDate : ''}${bookingDate.isNotEmpty && bookingTime.isNotEmpty ? ' • ' : ''}${bookingTime.isNotEmpty ? bookingTime : ''}',
                        style: TextStyle(color: AppColors.primaryGreen, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                    if (paymentRef.isNotEmpty) ...[
                      SizedBox(height: 2),
                      Text(
                        'Payment Ref No: ${paymentRef.replaceAll(RegExp(r'^REF:\s*', caseSensitive: false), '')}',
                        style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                    SizedBox(height: 2),
                    Text(
                      'Txn ID: #${tx['id']}',
                      style: TextStyle(color: Colors.black, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '+${_formatCurrency(net)}',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
          Divider(height: 24, color: Colors.grey.shade100),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Gross: ${_formatCurrency(gross)}', style: TextStyle(color: Colors.black, fontSize: 12)),
              Text('Fee: -${_formatCurrency(fee)}', style: TextStyle(color: AppColors.primaryGreen, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

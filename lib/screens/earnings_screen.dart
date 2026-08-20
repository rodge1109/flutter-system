import 'package:flutter_project/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';

class EarningsScreen extends StatefulWidget {
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
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    String? email;
    
    if (userStr != null) {
      try {
        final userObj = json.decode(userStr);
        email = userObj['email'];
      } catch (e) {
        print('Error parsing user data: $e');
      }
    }
    
    if (email != null) {
      String? startDate;
      String? endDate;
      if (_selectedDateRange != null) {
        startDate = DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start);
        endDate = DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end);
      }
      final data = await _apiService.fetchOwnerEarnings(email, startDate: startDate, endDate: endDate);
      if (data['success'] == true) {
        setState(() {
          _grossEarnings = (data['grossEarnings'] ?? 0).toDouble();
          _totalServiceFee = (data['totalServiceFee'] ?? 0).toDouble();
          _totalNetEarnings = (data['totalNetEarnings'] ?? 0).toDouble();
          _transactions = data['transactions'] ?? [];
          
          _transactions.sort((a, b) {
            try {
              DateTime dateA = DateTime.parse(a['created_at']);
              DateTime dateB = DateTime.parse(b['created_at']);
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

  String _formatCurrency(double amount) {
    final format = NumberFormat.currency(locale: 'en_PH', symbol: 'P');
    return format.format(amount);
  }
  
  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM dd, yyyy h:mm a').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('h:mm a').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  Map<String, List<dynamic>> _groupTransactionsByDate() {
    final Map<String, List<dynamic>> grouped = {};
    for (var tx in _transactions) {
      String dateStr = tx['created_at'] ?? '';
      String dateOnly = '';
      try {
        final date = DateTime.parse(dateStr);
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
              SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.check_circle_outline, color: AppColors.softWhite.withOpacity(0.70), size: 16),
                  SizedBox(width: 4),
                  Text('After 6.5% Service Charge', style: TextStyle(color: AppColors.softWhite.withOpacity(0.70), fontSize: 12)),
                ],
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
    final amount = (tx['amount'] ?? 0).toDouble();
    final net = (tx['netEarnings'] ?? 0).toDouble();
    final fee = (tx['serviceFee'] ?? 0).toDouble();
    final isTypeOpenPlay = tx['is_open_play'] == true;

    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatTime(tx['created_at']),
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
              Text('Gross: ${_formatCurrency(amount)}', style: TextStyle(color: Colors.black, fontSize: 12)),
              Text('Fee: -${_formatCurrency(fee)}', style: TextStyle(color: AppColors.primaryGreen, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

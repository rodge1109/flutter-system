import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ledger_entry_model.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class CourtOwnerLedgerScreen extends StatefulWidget {
  final bool isSuperAdmin;
  final String? initialOwnerEmail;
  final String? initialVenueName;
  final bool embedded; // true if used as a tab inside super/owner dashboard
  final List<dynamic>? allCourts;

  const CourtOwnerLedgerScreen({
    Key? key,
    this.isSuperAdmin = false,
    this.initialOwnerEmail,
    this.initialVenueName,
    this.embedded = false,
    this.allCourts,
  }) : super(key: key);

  @override
  _CourtOwnerLedgerScreenState createState() => _CourtOwnerLedgerScreenState();
}

class _CourtOwnerLedgerScreenState extends State<CourtOwnerLedgerScreen> {
  final ApiService _apiService = ApiService();
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');

  bool _isLoadingOwners = false;
  bool _isLoadingLedger = false;
  String? _errorMessage;

  List<LedgerOwnerSummary> _owners = [];
  LedgerOwnerSummary? _selectedOwner;
  String _selectedOwnerEmail = '';
  String _selectedVenueName = '';

  List<LedgerEntryModel> _entries = [];
  double _totalCharges = 0.0;
  double _totalPayments = 0.0;
  double _currentBalance = 0.0;

  // Filters
  String _dateFilterMode = 'ALL'; // 'ALL', 'THIS_MONTH', 'LAST_30_DAYS', 'CUSTOM'
  DateTimeRange? _customDateRange;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  String _currentUserName = 'Super Admin';
  String _currentUserEmail = '';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _selectedOwnerEmail = widget.initialOwnerEmail ?? '';
    _selectedVenueName = widget.initialVenueName ?? '';

    if (widget.allCourts != null) {
      _populateOwnersFromCourts(widget.allCourts);
    }

    if (_selectedOwnerEmail.isNotEmpty) {
      _ensureOwnerInList(_selectedOwnerEmail, _selectedVenueName);
    }

    if (widget.isSuperAdmin) {
      _loadOwnersAndLedger();
    } else {
      if (_selectedOwnerEmail.isNotEmpty) {
        _fetchOwnerLedgerData();
      }
    }
  }

  @override
  void didUpdateWidget(covariant CourtOwnerLedgerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.allCourts != oldWidget.allCourts) {
      _populateOwnersFromCourts(widget.allCourts);
    }
    if (widget.initialOwnerEmail != oldWidget.initialOwnerEmail &&
        widget.initialOwnerEmail != null &&
        widget.initialOwnerEmail!.isNotEmpty) {
      setState(() {
        _selectedOwnerEmail = widget.initialOwnerEmail!;
        _selectedVenueName = widget.initialVenueName ?? '';
        _ensureOwnerInList(_selectedOwnerEmail, _selectedVenueName);
        _selectedOwner = _owners.firstWhere(
          (o) => o.ownerEmail.toLowerCase() == _selectedOwnerEmail.toLowerCase(),
          orElse: () => _owners.first,
        );
      });
      _fetchOwnerLedgerData();
    }
  }

  void _ensureOwnerInList(String email, String venue) {
    if (email.trim().isEmpty) return;
    final cleanEmail = email.trim();
    final exists = _owners.any((o) => o.ownerEmail.toLowerCase() == cleanEmail.toLowerCase());
    if (!exists) {
      _owners.insert(
        0,
        LedgerOwnerSummary(
          ownerEmail: cleanEmail,
          venueName: venue.isNotEmpty ? venue : 'Court Venue',
          ownerName: venue.isNotEmpty ? venue : cleanEmail.split('@')[0],
          totalCharges: 0,
          totalPayments: 0,
          currentBalance: 0,
          transactionCount: 0,
        ),
      );
    }
  }

  void _populateOwnersFromCourts(List<dynamic>? courts) {
    if (courts == null || courts.isEmpty) return;
    for (var c in courts) {
      if (c is! Map) continue;
      final email = (c['owner_email'] ?? c['ownerEmail'] ?? '').toString().trim();
      if (email.isEmpty) continue;
      final rawVenue = (c['venue_name'] ?? c['venue'] ?? c['name'] ?? 'Court Venue').toString().trim();
      final cleanVenue = rawVenue.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
      final venue = cleanVenue.isNotEmpty ? cleanVenue : rawVenue;
      final ownerName = (c['owner_name'] ?? c['ownerName'] ?? venue).toString().trim();

      if (!_owners.any((o) => o.ownerEmail.toLowerCase() == email.toLowerCase())) {
        _owners.add(
          LedgerOwnerSummary(
            ownerEmail: email,
            venueName: venue,
            ownerName: ownerName.isNotEmpty ? ownerName : email.split('@')[0],
            totalCharges: 0,
            totalPayments: 0,
            currentBalance: 0,
            transactionCount: 0,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    if (userStr != null) {
      try {
        final u = json.decode(userStr);
        _currentUserName = u['name'] ?? u['full_name'] ?? (widget.isSuperAdmin ? 'Super Admin' : 'Court Owner');
        _currentUserEmail = u['email'] ?? '';
        if (!widget.isSuperAdmin && _selectedOwnerEmail.isEmpty) {
          _selectedOwnerEmail = _currentUserEmail;
          _fetchOwnerLedgerData();
        }
      } catch (_) {}
    }
  }

  Future<void> _loadOwnersAndLedger() async {
    setState(() {
      _isLoadingOwners = true;
      _errorMessage = null;
    });

    try {
      final remoteOwners = await _apiService.fetchLedgerOwners();

      // Merge remote owners with local list (from allCourts or initialOwnerEmail)
      final Map<String, LedgerOwnerSummary> ownerMap = {};
      for (var o in _owners) {
        ownerMap[o.ownerEmail.toLowerCase()] = o;
      }
      for (var o in remoteOwners) {
        ownerMap[o.ownerEmail.toLowerCase()] = o;
      }

      final combined = ownerMap.values.toList();

      setState(() {
        _owners = combined;
        _isLoadingOwners = false;
      });

      if (_selectedOwnerEmail.isNotEmpty) {
        _ensureOwnerInList(_selectedOwnerEmail, _selectedVenueName);
        _selectedOwner = _owners.firstWhere(
          (o) => o.ownerEmail.toLowerCase() == _selectedOwnerEmail.toLowerCase(),
          orElse: () => _owners.first,
        );
        _selectedOwnerEmail = _selectedOwner!.ownerEmail;
        _selectedVenueName = _selectedOwner!.venueName;
        await _fetchOwnerLedgerData();
      } else if (_owners.isNotEmpty) {
        final first = _owners.first;
        _selectedOwner = first;
        _selectedOwnerEmail = first.ownerEmail;
        _selectedVenueName = first.venueName;
        await _fetchOwnerLedgerData();
      } else {
        setState(() {
          _entries = [];
          _isLoadingLedger = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingOwners = false;
        _errorMessage = 'Failed to load owners: $e';
      });
      if (_selectedOwnerEmail.isNotEmpty) {
        await _fetchOwnerLedgerData();
      }
    }
  }

  Future<void> _fetchOwnerLedgerData() async {
    if (_selectedOwnerEmail.trim().isEmpty) return;

    setState(() {
      _isLoadingLedger = true;
      _errorMessage = null;
    });

    String? startDate;
    String? endDate;

    final now = DateTime.now();
    if (_dateFilterMode == 'THIS_MONTH') {
      startDate = DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month, 1));
      endDate = DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month + 1, 0));
    } else if (_dateFilterMode == 'LAST_30_DAYS') {
      startDate = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 30)));
      endDate = DateFormat('yyyy-MM-dd').format(now);
    } else if (_dateFilterMode == 'CUSTOM' && _customDateRange != null) {
      startDate = DateFormat('yyyy-MM-dd').format(_customDateRange!.start);
      endDate = DateFormat('yyyy-MM-dd').format(_customDateRange!.end);
    }

    try {
      final res = await _apiService.fetchOwnerLedger(
        _selectedOwnerEmail,
        startDate: startDate,
        endDate: endDate,
        search: _searchQuery,
      );

      if (res['success'] == true) {
        final List<LedgerEntryModel> fetched = res['entries'] ?? [];
        final double charges = (res['total_charges'] ?? 0.0).toDouble();
        final double payments = (res['total_payments'] ?? 0.0).toDouble();
        final double balance = (res['current_balance'] ?? 0.0).toDouble();

        setState(() {
          _entries = fetched;
          _totalCharges = charges;
          _totalPayments = payments;
          _currentBalance = balance;
          _isLoadingLedger = false;

          // Update summary in _owners list
          final idx = _owners.indexWhere((o) => o.ownerEmail.toLowerCase() == _selectedOwnerEmail.toLowerCase());
          if (idx != -1) {
            _owners[idx] = LedgerOwnerSummary(
              ownerEmail: _owners[idx].ownerEmail,
              venueName: _owners[idx].venueName,
              ownerName: _owners[idx].ownerName,
              totalCharges: charges,
              totalPayments: payments,
              currentBalance: balance,
              transactionCount: fetched.length,
            );
          }
        });
      } else {
        setState(() {
          _errorMessage = res['message'] ?? 'Failed to fetch ledger';
          _isLoadingLedger = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoadingLedger = false;
      });
    }
  }

  // ==================== ADD TRANSACTION DIALOG ====================
  void _showAddTransactionDialog() {
    final formKey = GlobalKey<FormState>();
    String selectedType = 'charge';
    DateTime selectedDate = DateTime.now();
    final particularsCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    bool isSubmitting = false;

    // Default target owner to currently selected or first available owner
    String activeOwnerEmail = _selectedOwnerEmail;
    String activeVenueName = _selectedVenueName;
    if (activeOwnerEmail.isEmpty && _owners.isNotEmpty) {
      activeOwnerEmail = _owners.first.ownerEmail;
      activeVenueName = _owners.first.venueName;
    }

    final List<String> suggestions = [
      'Monthly Platform Fee',
      'Booking Service Fee Remittance',
      'GCash Payout',
      'Bank Transfer Remittance',
      'Court Maintenance Fee',
      'Offline Booking Settlement',
      'Account Balance Adjustment',
    ];

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primaryGreen, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'New Ledger Transaction',
                          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.richBlack),
                        ),
                        Text(
                          activeVenueName.isNotEmpty
                              ? activeVenueName
                              : (activeOwnerEmail.isNotEmpty ? activeOwnerEmail : 'Select target court owner below'),
                          style: GoogleFonts.outfit(fontSize: 12, color: AppColors.stoneGray),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 480,
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 8),

                        // Target Court Owner (if Super Admin)
                        if (widget.isSuperAdmin) ...[
                          Text(
                            'Target Court Owner',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.richBlack),
                          ),
                          const SizedBox(height: 6),
                          if (_owners.isNotEmpty)
                            DropdownButtonFormField<String>(
                              value: _owners.any((o) => o.ownerEmail.toLowerCase() == activeOwnerEmail.toLowerCase())
                                  ? _owners.firstWhere((o) => o.ownerEmail.toLowerCase() == activeOwnerEmail.toLowerCase()).ownerEmail
                                  : _owners.first.ownerEmail,
                              isExpanded: true,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                              items: _owners.map((o) {
                                return DropdownMenuItem<String>(
                                  value: o.ownerEmail,
                                  child: Text(
                                    '${o.venueName.isNotEmpty ? o.venueName : 'Venue'} — ${o.ownerName} (${o.ownerEmail})',
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() {
                                    activeOwnerEmail = val;
                                    final match = _owners.firstWhere((o) => o.ownerEmail == val);
                                    activeVenueName = match.venueName;
                                  });
                                }
                              },
                            )
                          else
                            TextFormField(
                              initialValue: activeOwnerEmail,
                              decoration: InputDecoration(
                                hintText: 'e.g. owner@example.com',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Enter court owner email';
                                if (!v.contains('@')) return 'Enter a valid email address';
                                return null;
                              },
                              onChanged: (v) => activeOwnerEmail = v.trim(),
                            ),
                          const SizedBox(height: 14),
                        ],

                        // Type Segmented Toggle
                        Text('Transaction Type', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.richBlack)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setDialogState(() => selectedType = 'charge'),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: selectedType == 'charge' ? Colors.red.shade50 : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: selectedType == 'charge' ? Colors.red.shade400 : Colors.grey.shade300,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.arrow_upward_rounded, size: 16, color: selectedType == 'charge' ? Colors.red.shade700 : Colors.grey.shade600),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Charge (Debit)',
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: selectedType == 'charge' ? Colors.red.shade700 : Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: () => setDialogState(() => selectedType = 'payment'),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: selectedType == 'payment' ? Colors.green.shade50 : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: selectedType == 'payment' ? AppColors.primaryGreen : Colors.grey.shade300,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.arrow_downward_rounded, size: 16, color: selectedType == 'payment' ? AppColors.primaryGreen : Colors.grey.shade600),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Payment (Credit)',
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: selectedType == 'payment' ? AppColors.primaryGreen : Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Date Picker Field
                        Text('Transaction Date', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.richBlack)),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) {
                              setDialogState(() => selectedDate = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primaryGreen),
                                const SizedBox(width: 10),
                                Text(_dateFormat.format(selectedDate), style: GoogleFonts.outfit(fontSize: 14, color: AppColors.richBlack)),
                                const Spacer(),
                                const Icon(Icons.arrow_drop_down, color: AppColors.stoneGray),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Amount Field
                        Text('Amount (₱)', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.richBlack)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            hintText: '0.00',
                            prefixIcon: const Icon(Icons.attach_money_rounded, color: AppColors.primaryGreen),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Enter an amount';
                            final parsed = double.tryParse(v.trim());
                            if (parsed == null || parsed <= 0) return 'Enter a valid amount greater than 0';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Particulars Field
                        Text('Particulars / Description', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.richBlack)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: particularsCtrl,
                          decoration: InputDecoration(
                            hintText: 'e.g., Monthly Platform Fee - October',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Please describe the transaction';
                            return null;
                          },
                        ),
                        const SizedBox(height: 6),
                        // Quick suggestion chips
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: suggestions.map((s) {
                            return ActionChip(
                              label: Text(s, style: GoogleFonts.outfit(fontSize: 10, color: AppColors.primaryGreen)),
                              backgroundColor: AppColors.primaryGreen.withOpacity(0.06),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              onPressed: () {
                                setDialogState(() => particularsCtrl.text = s);
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),

                        // Reference Number
                        Text('Reference # (Optional)', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.richBlack)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: refCtrl,
                          decoration: InputDecoration(
                            hintText: 'e.g., GCASH-998811 / INV-2026-01',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Notes Field
                        Text('Notes / Remarks (Optional)', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.richBlack)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: notesCtrl,
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: 'Additional details or memo...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  child: Text('Cancel', style: GoogleFonts.outfit(color: AppColors.stoneGray, fontWeight: FontWeight.w600)),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSubmitting = true);

                          final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
                          final amt = double.parse(amountCtrl.text.trim());

                          final res = await _apiService.createLedgerEntry(
                            ownerEmail: activeOwnerEmail,
                            venueName: activeVenueName,
                            transactionDate: dateStr,
                            particulars: particularsCtrl.text.trim(),
                            type: selectedType,
                            amount: amt,
                            referenceNumber: refCtrl.text.trim().isEmpty ? null : refCtrl.text.trim(),
                            notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                            createdBy: _currentUserName,
                          );

                          if (res['success'] == true) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('✅ Transaction recorded successfully.', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                                backgroundColor: AppColors.primaryGreen,
                              ),
                            );
                            setState(() {
                              _selectedOwnerEmail = activeOwnerEmail;
                              _selectedVenueName = activeVenueName;
                              _ensureOwnerInList(_selectedOwnerEmail, _selectedVenueName);
                              _selectedOwner = _owners.firstWhere(
                                (o) => o.ownerEmail.toLowerCase() == _selectedOwnerEmail.toLowerCase(),
                                orElse: () => _owners.first,
                              );
                            });
                            _fetchOwnerLedgerData();
                          } else {
                            setDialogState(() => isSubmitting = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: ${res['message'] ?? 'Failed to save transaction'}'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Record Transaction', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==================== EDIT TRANSACTION DIALOG ====================
  void _showEditTransactionDialog(LedgerEntryModel entry) {
    final formKey = GlobalKey<FormState>();
    String selectedType = entry.type.toLowerCase();
    DateTime selectedDate = DateTime.tryParse(entry.transactionDate) ?? DateTime.now();
    final particularsCtrl = TextEditingController(text: entry.particulars);
    final amountCtrl = TextEditingController(text: entry.amount.toStringAsFixed(2));
    final refCtrl = TextEditingController(text: entry.referenceNumber ?? '');
    final notesCtrl = TextEditingController(text: entry.notes ?? '');
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.edit_rounded, color: Colors.amber.shade800, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Edit Transaction', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.richBlack)),
                        Text('Entry ID #${entry.id ?? '—'}', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.stoneGray)),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 480,
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 8),
                        // Type Segmented Toggle
                        Text('Transaction Type', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.richBlack)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setDialogState(() => selectedType = 'charge'),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: selectedType == 'charge' ? Colors.red.shade50 : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: selectedType == 'charge' ? Colors.red.shade400 : Colors.grey.shade300,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.arrow_upward_rounded, size: 16, color: selectedType == 'charge' ? Colors.red.shade700 : Colors.grey.shade600),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Charge (Debit)',
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: selectedType == 'charge' ? Colors.red.shade700 : Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: () => setDialogState(() => selectedType = 'payment'),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: selectedType == 'payment' ? Colors.green.shade50 : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: selectedType == 'payment' ? AppColors.primaryGreen : Colors.grey.shade300,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.arrow_downward_rounded, size: 16, color: selectedType == 'payment' ? AppColors.primaryGreen : Colors.grey.shade600),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Payment (Credit)',
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: selectedType == 'payment' ? AppColors.primaryGreen : Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Date Picker Field
                        Text('Transaction Date', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.richBlack)),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) {
                              setDialogState(() => selectedDate = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primaryGreen),
                                const SizedBox(width: 10),
                                Text(_dateFormat.format(selectedDate), style: GoogleFonts.outfit(fontSize: 14, color: AppColors.richBlack)),
                                const Spacer(),
                                const Icon(Icons.arrow_drop_down, color: AppColors.stoneGray),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Amount Field
                        Text('Amount (₱)', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.richBlack)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            hintText: '0.00',
                            prefixIcon: const Icon(Icons.attach_money_rounded, color: AppColors.primaryGreen),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Enter an amount';
                            final parsed = double.tryParse(v.trim());
                            if (parsed == null || parsed <= 0) return 'Enter a valid amount greater than 0';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Particulars Field
                        Text('Particulars / Description', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.richBlack)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: particularsCtrl,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Please describe the transaction';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Reference Number
                        Text('Reference # (Optional)', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.richBlack)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: refCtrl,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Notes Field
                        Text('Notes / Remarks (Optional)', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.richBlack)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: notesCtrl,
                          maxLines: 2,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  child: Text('Cancel', style: GoogleFonts.outfit(color: AppColors.stoneGray, fontWeight: FontWeight.w600)),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate() || entry.id == null) return;
                          setDialogState(() => isSubmitting = true);

                          final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
                          final amt = double.parse(amountCtrl.text.trim());

                          final res = await _apiService.updateLedgerEntry(
                            entry.id!,
                            ownerEmail: _selectedOwnerEmail,
                            venueName: _selectedVenueName,
                            transactionDate: dateStr,
                            particulars: particularsCtrl.text.trim(),
                            type: selectedType,
                            amount: amt,
                            referenceNumber: refCtrl.text.trim().isEmpty ? null : refCtrl.text.trim(),
                            notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                          );

                          if (res['success'] == true) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('✅ Transaction updated successfully.', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                                backgroundColor: AppColors.primaryGreen,
                              ),
                            );
                            _fetchOwnerLedgerData();
                          } else {
                            setDialogState(() => isSubmitting = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: ${res['message'] ?? 'Failed to update transaction'}'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Save Changes', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==================== DELETE TRANSACTION CONFIRMATION ====================
  void _confirmDeleteTransaction(LedgerEntryModel entry) {
    if (entry.id == null) return;
    showDialog(
      context: context,
      builder: (ctx) {
        bool isDeleting = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
                  const SizedBox(width: 10),
                  Text('Delete Transaction?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.richBlack)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Are you sure you want to permanently remove this transaction? Running balances will be automatically recalculated.',
                    style: GoogleFonts.outfit(fontSize: 14, color: AppColors.stoneGray),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.particulars, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.richBlack)),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(entry.transactionDate, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.stoneGray)),
                            Text(
                              _currencyFormat.format(entry.amount),
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: entry.isCharge ? Colors.red.shade700 : AppColors.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.pop(ctx),
                  child: Text('Cancel', style: GoogleFonts.outfit(color: AppColors.stoneGray, fontWeight: FontWeight.w600)),
                ),
                ElevatedButton(
                  onPressed: isDeleting
                      ? null
                      : () async {
                          setDialogState(() => isDeleting = true);
                          final res = await _apiService.deleteLedgerEntry(entry.id!);
                          if (res['success'] == true) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('🗑️ Transaction deleted.', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                                backgroundColor: AppColors.richBlack,
                              ),
                            );
                            _fetchOwnerLedgerData();
                          } else {
                            setDialogState(() => isDeleting = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: ${res['message'] ?? 'Failed to delete'}'), backgroundColor: Colors.redAccent),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isDeleting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Delete', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==================== UI BUILD ====================
  @override
  Widget build(BuildContext context) {
    Widget content = _buildMainBody();

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: AppColors.deepTeal,
        elevation: 0,
        title: Text(
          widget.isSuperAdmin ? 'Court Owner Ledgers' : 'Account Ledger',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Ledger',
            onPressed: () {
              if (widget.isSuperAdmin) {
                _loadOwnersAndLedger();
              } else {
                _fetchOwnerLedgerData();
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: content,
    );
  }

  Widget _buildMainBody() {
    return RefreshIndicator(
      onRefresh: () async {
        if (widget.isSuperAdmin) {
          await _loadOwnersAndLedger();
        } else {
          await _fetchOwnerLedgerData();
        }
      },
      color: AppColors.primaryGreen,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header & Owner Selector (if Super Admin)
            _buildTopControls(),
            const SizedBox(height: 16),

            // Summary Metric Cards
            _buildSummaryCards(),
            const SizedBox(height: 20),

            // Filter Bar (Search + Date Range)
            _buildFilterBar(),
            const SizedBox(height: 16),

            // Ledger Table Container
            _buildLedgerTableContainer(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ==================== TOP CONTROLS ====================
  Widget _buildTopControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.menu_book_rounded, color: AppColors.primaryGreen, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isSuperAdmin ? 'Court Owner Financial Ledger' : 'My Court Account Ledger',
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.richBlack),
                    ),
                    Text(
                      widget.isSuperAdmin
                          ? 'Manage and track manual charges, remittances, and running balances per court owner.'
                          : 'Official transaction record and running statement of your court account.',
                      style: GoogleFonts.outfit(fontSize: 12, color: AppColors.stoneGray),
                    ),
                  ],
                ),
              ),
              if (widget.isSuperAdmin) ...[
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _showAddTransactionDialog,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text('Add Entry', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ],
          ),

          // Owner Selector for Super Admin
          if (widget.isSuperAdmin) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  'Select Court Owner:',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.richBlack),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _isLoadingOwners
                      ? const SizedBox(height: 20, width: 20, child: Align(alignment: Alignment.centerLeft, child: CircularProgressIndicator(strokeWidth: 2)))
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: _owners.any((o) => o.ownerEmail.toLowerCase() == _selectedOwnerEmail.toLowerCase())
                                  ? _owners.firstWhere((o) => o.ownerEmail.toLowerCase() == _selectedOwnerEmail.toLowerCase()).ownerEmail
                                  : (_owners.isNotEmpty ? _owners.first.ownerEmail : null),
                              hint: Text('Select an owner', style: GoogleFonts.outfit(fontSize: 13, color: AppColors.stoneGray)),
                              icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryGreen),
                              items: _owners.map((owner) {
                                return DropdownMenuItem<String>(
                                  value: owner.ownerEmail,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${owner.venueName.isNotEmpty ? owner.venueName : 'Venue'} — ${owner.ownerName} (${owner.ownerEmail})',
                                          style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.richBlack),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: owner.currentBalance > 0
                                              ? Colors.red.shade50
                                              : (owner.currentBalance < 0 ? Colors.blue.shade50 : Colors.green.shade50),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          _currencyFormat.format(owner.currentBalance),
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: owner.currentBalance > 0
                                                ? Colors.red.shade700
                                                : (owner.currentBalance < 0 ? Colors.blue.shade700 : AppColors.primaryGreen),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (newEmail) {
                                if (newEmail != null && newEmail.toLowerCase() != _selectedOwnerEmail.toLowerCase()) {
                                  final match = _owners.firstWhere((o) => o.ownerEmail.toLowerCase() == newEmail.toLowerCase(), orElse: () => _owners.first);
                                  setState(() {
                                    _selectedOwner = match;
                                    _selectedOwnerEmail = match.ownerEmail;
                                    _selectedVenueName = match.venueName;
                                  });
                                  _fetchOwnerLedgerData();
                                }
                              },
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.storefront_rounded, size: 16, color: AppColors.primaryGreen),
                  const SizedBox(width: 8),
                  Text(
                    _selectedVenueName.isNotEmpty ? _selectedVenueName : 'My Court Account',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryGreen),
                  ),
                  const Spacer(),
                  Text(
                    _selectedOwnerEmail,
                    style: GoogleFonts.outfit(fontSize: 12, color: AppColors.stoneGray),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==================== SUMMARY CARDS ====================
  Widget _buildSummaryCards() {
    final balanceColor = _currentBalance > 0
        ? Colors.red.shade700
        : (_currentBalance < 0 ? Colors.blue.shade700 : AppColors.primaryGreen);
    final balanceBg = _currentBalance > 0
        ? Colors.red.shade50
        : (_currentBalance < 0 ? Colors.blue.shade50 : Colors.green.shade50);
    final balanceStatus = _currentBalance > 0
        ? 'Outstanding Due'
        : (_currentBalance < 0 ? 'Advance Credit' : 'Account Settled');

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 640;
        final cardWidth = isNarrow ? (constraints.maxWidth - 12) / 2 : (constraints.maxWidth - 36) / 4;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            // Running Balance Card
            _buildMetricCard(
              width: isNarrow ? constraints.maxWidth : cardWidth,
              title: 'Running Balance',
              value: _currencyFormat.format(_currentBalance),
              subtitle: balanceStatus,
              icon: Icons.account_balance_rounded,
              iconColor: balanceColor,
              bgColor: balanceBg,
              isHighlighted: true,
            ),
            // Total Charges
            _buildMetricCard(
              width: cardWidth,
              title: 'Total Charges',
              value: _currencyFormat.format(_totalCharges),
              subtitle: 'Debits / Billed',
              icon: Icons.arrow_upward_rounded,
              iconColor: Colors.red.shade700,
              bgColor: Colors.white,
            ),
            // Total Payments
            _buildMetricCard(
              width: cardWidth,
              title: 'Total Payments',
              value: _currencyFormat.format(_totalPayments),
              subtitle: 'Credits / Paid',
              icon: Icons.arrow_downward_rounded,
              iconColor: AppColors.primaryGreen,
              bgColor: Colors.white,
            ),
            // Total Entries
            _buildMetricCard(
              width: cardWidth,
              title: 'Transactions',
              value: _entries.length.toString(),
              subtitle: 'Recorded Entries',
              icon: Icons.receipt_long_rounded,
              iconColor: AppColors.stoneGray,
              bgColor: Colors.white,
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required double width,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    bool isHighlighted = false,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHighlighted ? iconColor.withOpacity(0.3) : Colors.grey.shade200,
          width: isHighlighted ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.stoneGray)),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isHighlighted ? iconColor : AppColors.richBlack,
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: GoogleFonts.outfit(fontSize: 11, color: isHighlighted ? iconColor : AppColors.stoneGray)),
        ],
      ),
    );
  }

  // ==================== FILTER BAR ====================
  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          // Date Filter Pills
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFilterChip('All Time', 'ALL'),
              const SizedBox(width: 6),
              _buildFilterChip('This Month', 'THIS_MONTH'),
              const SizedBox(width: 6),
              _buildFilterChip('Last 30 Days', 'LAST_30_DAYS'),
              const SizedBox(width: 6),
              _buildCustomDateChip(),
            ],
          ),

          // Search Field
          SizedBox(
            width: 240,
            height: 38,
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() => _searchQuery = val);
                _fetchOwnerLedgerData();
              },
              style: GoogleFonts.outfit(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search particulars or ref #...',
                hintStyle: GoogleFonts.outfit(fontSize: 12, color: AppColors.stoneGray),
                prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.stoneGray),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _fetchOwnerLedgerData();
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8F9FA),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String mode) {
    final isSelected = _dateFilterMode == mode;
    return InkWell(
      onTap: () {
        setState(() {
          _dateFilterMode = mode;
        });
        _fetchOwnerLedgerData();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppColors.primaryGreen : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.stoneGray,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomDateChip() {
    final isSelected = _dateFilterMode == 'CUSTOM';
    String label = 'Custom';
    if (isSelected && _customDateRange != null) {
      label = '${DateFormat('MM/dd').format(_customDateRange!.start)} - ${DateFormat('MM/dd').format(_customDateRange!.end)}';
    }

    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDateRangePicker(
          context: context,
          initialDateRange: _customDateRange ?? DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now),
          firstDate: DateTime(2020),
          lastDate: DateTime(2035),
        );
        if (picked != null) {
          setState(() {
            _dateFilterMode = 'CUSTOM';
            _customDateRange = picked;
          });
          _fetchOwnerLedgerData();
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppColors.primaryGreen : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month_outlined, size: 13, color: isSelected ? Colors.white : AppColors.stoneGray),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.stoneGray,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== LEDGER TABLE CONTAINER ====================
  Widget _buildLedgerTableContainer() {
    if (_isLoadingLedger) {
      return Container(
        height: 280,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primaryGreen),
            const SizedBox(height: 14),
            Text('Loading ledger records...', style: GoogleFonts.outfit(color: AppColors.stoneGray, fontSize: 13)),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent),
            const SizedBox(width: 12),
            Expanded(child: Text(_errorMessage!, style: GoogleFonts.outfit(color: Colors.red.shade800))),
            TextButton(
              onPressed: _fetchOwnerLedgerData,
              child: Text('Retry', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.red.shade800)),
            ),
          ],
        ),
      );
    }

    if (_entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.receipt_long_outlined, size: 36, color: AppColors.primaryGreen),
              ),
              const SizedBox(height: 14),
              Text('No Ledger Transactions Found', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.richBlack)),
              const SizedBox(height: 6),
              Text(
                widget.isSuperAdmin
                    ? 'No transactions recorded for this owner yet. Click "+ Add Entry" above to add the first charge or payment.'
                    : 'No ledger transactions recorded for your court account during the selected period.',
                style: GoogleFonts.outfit(fontSize: 13, color: AppColors.stoneGray),
                textAlign: TextAlign.center,
              ),
              if (widget.isSuperAdmin) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _showAddTransactionDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text('Record First Entry', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Modern Responsive Data Table
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 850),
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(const Color(0xFFF4F6F5)),
              horizontalMargin: 20,
              columnSpacing: 24,
              dataRowHeight: 56,
              headingRowHeight: 46,
              columns: [
                DataColumn(
                  label: Text('DATE', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.deepTeal, letterSpacing: 0.5)),
                ),
                DataColumn(
                  label: Text('PARTICULARS', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.deepTeal, letterSpacing: 0.5)),
                ),
                DataColumn(
                  label: Text('REF #', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.deepTeal, letterSpacing: 0.5)),
                ),
                DataColumn(
                  numeric: true,
                  label: Text('CHARGES (₱)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.red.shade700, letterSpacing: 0.5)),
                ),
                DataColumn(
                  numeric: true,
                  label: Text('PAYMENT (₱)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primaryGreen, letterSpacing: 0.5)),
                ),
                DataColumn(
                  numeric: true,
                  label: Text('RUNNING BAL (₱)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.deepTeal, letterSpacing: 0.5)),
                ),
                if (widget.isSuperAdmin)
                  DataColumn(
                    label: Text('ACTIONS', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.deepTeal, letterSpacing: 0.5)),
                  ),
              ],
              rows: _entries.map((entry) {
                DateTime? dt = DateTime.tryParse(entry.transactionDate);
                String formattedDate = dt != null ? _dateFormat.format(dt) : entry.transactionDate;

                final hasNotes = entry.notes != null && entry.notes!.trim().isNotEmpty;

                return DataRow(
                  cells: [
                    // Date
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            entry.isCharge ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                            size: 14,
                            color: entry.isCharge ? Colors.red.shade600 : AppColors.primaryGreen,
                          ),
                          const SizedBox(width: 6),
                          Text(formattedDate, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.richBlack)),
                        ],
                      ),
                    ),
                    // Particulars
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            entry.particulars,
                            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.richBlack),
                          ),
                          if (hasNotes)
                            Text(
                              entry.notes!,
                              style: GoogleFonts.outfit(fontSize: 11, color: AppColors.stoneGray, fontStyle: FontStyle.italic),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    // Reference #
                    DataCell(
                      entry.referenceNumber != null && entry.referenceNumber!.isNotEmpty
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Text(
                                entry.referenceNumber!,
                                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.deepTeal),
                              ),
                            )
                          : Text('—', style: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 12)),
                    ),
                    // Charges
                    DataCell(
                      entry.charges > 0
                          ? Text(
                              _currencyFormat.format(entry.charges),
                              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red.shade700),
                            )
                          : Text('—', style: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 12)),
                    ),
                    // Payment
                    DataCell(
                      entry.payment > 0
                          ? Text(
                              _currencyFormat.format(entry.payment),
                              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                            )
                          : Text('—', style: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 12)),
                    ),
                    // Running Balance
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: entry.runningBalance > 0
                              ? Colors.red.shade50
                              : (entry.runningBalance < 0 ? Colors.blue.shade50 : Colors.green.shade50),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _currencyFormat.format(entry.runningBalance),
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: entry.runningBalance > 0
                                ? Colors.red.shade700
                                : (entry.runningBalance < 0 ? Colors.blue.shade700 : AppColors.primaryGreen),
                          ),
                        ),
                      ),
                    ),
                    // Actions (Super Admin only)
                    if (widget.isSuperAdmin)
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.stoneGray),
                              tooltip: 'Edit Transaction',
                              splashRadius: 18,
                              onPressed: () => _showEditTransactionDialog(entry),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                              tooltip: 'Delete Transaction',
                              splashRadius: 18,
                              onPressed: () => _confirmDeleteTransaction(entry),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

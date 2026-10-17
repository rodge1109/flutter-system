import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/ledger_entry_model.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class LedgerEntryFormScreen extends StatefulWidget {
  final bool isSuperAdmin;
  final String currentUserName;
  final String initialOwnerEmail;
  final String initialVenueName;
  final List<LedgerOwnerSummary> availableOwners;
  final LedgerEntryModel? existingEntry; // null for Add, populated for Edit

  const LedgerEntryFormScreen({
    Key? key,
    this.isSuperAdmin = true,
    this.currentUserName = 'Super Admin',
    this.initialOwnerEmail = '',
    this.initialVenueName = '',
    this.availableOwners = const [],
    this.existingEntry,
  }) : super(key: key);

  @override
  _LedgerEntryFormScreenState createState() => _LedgerEntryFormScreenState();
}

class _LedgerEntryFormScreenState extends State<LedgerEntryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
  final DateFormat _dateFormat = DateFormat('EEEE, MMMM dd, yyyy');

  late String _selectedOwnerEmail;
  late String _selectedVenueName;
  late String _selectedType; // 'charge' or 'payment'
  late DateTime _selectedDate;

  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _particularsCtrl = TextEditingController();
  final TextEditingController _refCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  bool _isSubmitting = false;

  final List<String> _quickSuggestions = [
    'Monthly Platform Fee',
    'Booking Service Fee Remittance',
    'GCash Payout',
    'Bank Transfer Remittance',
    'Court Maintenance Fee',
    'Offline Booking Settlement',
    'Account Balance Adjustment',
  ];

  @override
  void initState() {
    super.initState();
    final entry = widget.existingEntry;

    if (entry != null) {
      _selectedOwnerEmail = entry.ownerEmail;
      _selectedVenueName = entry.venueName ?? widget.initialVenueName;
      _selectedType = entry.type.toLowerCase();
      _selectedDate = DateTime.tryParse(entry.transactionDate) ?? DateTime.now();
      _amountCtrl.text = entry.amount.toStringAsFixed(2);
      _particularsCtrl.text = entry.particulars;
      _refCtrl.text = entry.referenceNumber ?? '';
      _notesCtrl.text = entry.notes ?? '';
    } else {
      _selectedOwnerEmail = widget.initialOwnerEmail;
      _selectedVenueName = widget.initialVenueName;
      if (_selectedOwnerEmail.isEmpty && widget.availableOwners.isNotEmpty) {
        _selectedOwnerEmail = widget.availableOwners.first.ownerEmail;
        _selectedVenueName = widget.availableOwners.first.venueName;
      }
      _selectedType = 'charge';
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _particularsCtrl.dispose();
    _refCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryGreen,
              onPrimary: Colors.white,
              onSurface: AppColors.richBlack,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedOwnerEmail.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or specify a court owner email.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final amt = double.parse(_amountCtrl.text.trim());
    final isEditing = widget.existingEntry != null;

    Map<String, dynamic> res;

    if (isEditing) {
      res = await _apiService.updateLedgerEntry(
        widget.existingEntry!.id!,
        ownerEmail: _selectedOwnerEmail.trim(),
        venueName: _selectedVenueName.trim(),
        transactionDate: dateStr,
        particulars: _particularsCtrl.text.trim(),
        type: _selectedType,
        amount: amt,
        referenceNumber: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
    } else {
      res = await _apiService.createLedgerEntry(
        ownerEmail: _selectedOwnerEmail.trim(),
        venueName: _selectedVenueName.trim(),
        transactionDate: dateStr,
        particulars: _particularsCtrl.text.trim(),
        type: _selectedType,
        amount: amt,
        referenceNumber: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        createdBy: widget.currentUserName,
      );
    }

    if (!mounted) return;

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing ? '✅ Transaction updated successfully.' : '✅ Transaction recorded successfully.',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
      Navigator.pop(context, {
        'saved': true,
        'ownerEmail': _selectedOwnerEmail.trim(),
        'venueName': _selectedVenueName.trim(),
      });
    } else {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${res['message'] ?? 'Failed to save transaction'}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingEntry != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.richBlack),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditing ? 'Edit Ledger Transaction' : 'New Ledger Transaction',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: AppColors.richBlack,
            fontSize: 18,
          ),
        ),
        actions: [
          if (isEditing)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Entry #${widget.existingEntry!.id ?? '—'}',
                    style: GoogleFonts.outfit(fontSize: 12, color: AppColors.stoneGray, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                children: [
                  // Owner Info / Selector Card
                  _buildOwnerSelectorCard(),
                  const SizedBox(height: 18),

                  // Transaction Type Selection
                  _buildTypeSelector(),
                  const SizedBox(height: 18),

                  // Transaction Details Card
                  _buildDetailsCard(),
                  const SizedBox(height: 18),

                  // Memo / References Card
                  _buildMemoCard(),
                  const SizedBox(height: 28),

                  // Submit and Cancel Buttons
                  _buildActionButtons(isEditing),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== OWNER SELECTOR CARD ====================
  Widget _buildOwnerSelectorCard() {
    final hasOwners = widget.availableOwners.isNotEmpty;
    final isMatching = widget.availableOwners.any((o) => o.ownerEmail.toLowerCase() == _selectedOwnerEmail.toLowerCase());

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
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.storefront_rounded, color: AppColors.primaryGreen, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Court Owner & Venue Account',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.richBlack),
                    ),
                    Text(
                      'The balance and ledger statement of this court owner will be updated.',
                      style: GoogleFonts.outfit(fontSize: 12, color: AppColors.stoneGray),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),

          if (widget.isSuperAdmin && hasOwners) ...[
            DropdownButtonFormField<String>(
              value: isMatching
                  ? widget.availableOwners.firstWhere((o) => o.ownerEmail.toLowerCase() == _selectedOwnerEmail.toLowerCase()).ownerEmail
                  : widget.availableOwners.first.ownerEmail,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Select Court Owner',
                labelStyle: GoogleFonts.outfit(color: AppColors.stoneGray, fontSize: 13),
                filled: true,
                fillColor: const Color(0xFFF8F9FA),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
              ),
              items: widget.availableOwners.map((owner) {
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
                      const SizedBox(width: 8),
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
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedOwnerEmail = val;
                    final match = widget.availableOwners.firstWhere((o) => o.ownerEmail == val);
                    _selectedVenueName = match.venueName;
                  });
                }
              },
            ),
          ] else ...[
            TextFormField(
              initialValue: _selectedOwnerEmail,
              enabled: widget.isSuperAdmin,
              decoration: InputDecoration(
                labelText: 'Court Owner Email',
                labelStyle: GoogleFonts.outfit(color: AppColors.stoneGray, fontSize: 13),
                prefixIcon: const Icon(Icons.email_outlined, size: 18, color: AppColors.stoneGray),
                filled: true,
                fillColor: const Color(0xFFF8F9FA),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Owner email is required';
                if (!v.contains('@')) return 'Enter a valid email address';
                return null;
              },
              onChanged: (v) => _selectedOwnerEmail = v.trim(),
            ),
          ],
        ],
      ),
    );
  }

  // ==================== TYPE SELECTOR ====================
  Widget _buildTypeSelector() {
    final isCharge = _selectedType == 'charge';
    final isPayment = _selectedType == 'payment';

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
          Text(
            'Transaction Type',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.richBlack),
          ),
          const SizedBox(height: 4),
          Text(
            'Select whether you are billing a charge to the court owner, or crediting a payment/payout.',
            style: GoogleFonts.outfit(fontSize: 12, color: AppColors.stoneGray),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              // Charge (Debit) Card
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _selectedType = 'charge'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isCharge ? Colors.red.shade50 : const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCharge ? Colors.red.shade400 : Colors.grey.shade300,
                        width: isCharge ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isCharge ? Colors.red.shade100 : Colors.grey.shade200,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.arrow_upward_rounded,
                                size: 16,
                                color: isCharge ? Colors.red.shade700 : AppColors.stoneGray,
                              ),
                            ),
                            const Spacer(),
                            if (isCharge)
                              const Icon(Icons.check_circle_rounded, color: Colors.redAccent, size: 18),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Charge (Debit)',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isCharge ? Colors.red.shade800 : AppColors.richBlack,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Increases balance owed (e.g., Platform fee, maintenance, penalties)',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: isCharge ? Colors.red.shade700 : AppColors.stoneGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Payment (Credit) Card
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _selectedType = 'payment'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isPayment ? Colors.green.shade50 : const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isPayment ? AppColors.primaryGreen : Colors.grey.shade300,
                        width: isPayment ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isPayment ? AppColors.primaryGreen.withOpacity(0.18) : Colors.grey.shade200,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.arrow_downward_rounded,
                                size: 16,
                                color: isPayment ? AppColors.primaryGreen : AppColors.stoneGray,
                              ),
                            ),
                            const Spacer(),
                            if (isPayment)
                              const Icon(Icons.check_circle_rounded, color: AppColors.primaryGreen, size: 18),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Payment (Credit)',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isPayment ? AppColors.primaryGreen : AppColors.richBlack,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Decreases balance owed (e.g., GCash payout, remittance, settlement)',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: isPayment ? AppColors.primaryGreen : AppColors.stoneGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== DETAILS CARD ====================
  Widget _buildDetailsCard() {
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
          Text(
            'Transaction Details',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.richBlack),
          ),
          const SizedBox(height: 14),

          // Date Picker Tile
          Text('Date of Transaction', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.richBlack)),
          const SizedBox(height: 6),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primaryGreen),
                  const SizedBox(width: 10),
                  Text(_dateFormat.format(_selectedDate), style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.richBlack)),
                  const Spacer(),
                  Text('Change', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Amount Field
          Text('Amount (₱)', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.richBlack)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.richBlack),
            decoration: InputDecoration(
              hintText: '0.00',
              prefixIcon: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Text(
                  '₱',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _selectedType == 'charge' ? Colors.red.shade700 : AppColors.primaryGreen,
                  ),
                ),
              ),
              filled: true,
              fillColor: const Color(0xFFF8F9FA),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2)),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Please enter an amount';
              final parsed = double.tryParse(v.trim());
              if (parsed == null || parsed <= 0) return 'Enter a valid amount greater than ₱0.00';
              return null;
            },
          ),
          const SizedBox(height: 18),

          // Particulars Field
          Text('Particulars / Description', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.richBlack)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _particularsCtrl,
            style: GoogleFonts.outfit(fontSize: 14, color: AppColors.richBlack),
            decoration: InputDecoration(
              hintText: 'e.g., Monthly Platform Fee - October 2026',
              filled: true,
              fillColor: const Color(0xFFF8F9FA),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2)),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Please describe the transaction';
              return null;
            },
          ),
          const SizedBox(height: 8),

          // Quick Suggestion Chips
          Text('Quick Suggestions:', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.stoneGray)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _quickSuggestions.map((s) {
              final isChosen = _particularsCtrl.text.trim() == s;
              return ActionChip(
                label: Text(
                  s,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: isChosen ? FontWeight.bold : FontWeight.w500,
                    color: isChosen ? Colors.white : AppColors.deepTeal,
                  ),
                ),
                backgroundColor: isChosen ? AppColors.deepTeal : AppColors.primaryGreen.withOpacity(0.08),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.transparent)),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                onPressed: () {
                  setState(() => _particularsCtrl.text = s);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ==================== MEMO & REFERENCES CARD ====================
  Widget _buildMemoCard() {
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
          Text(
            'Reference & Remarks (Optional)',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.richBlack),
          ),
          const SizedBox(height: 14),

          // Reference Number Field
          Text('Reference Number', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.richBlack)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _refCtrl,
            style: GoogleFonts.outfit(fontSize: 14, color: AppColors.richBlack),
            decoration: InputDecoration(
              hintText: 'e.g., GCASH-998811 / INV-2026-01 / BDO-TRX-44',
              prefixIcon: const Icon(Icons.tag_rounded, size: 18, color: AppColors.stoneGray),
              filled: true,
              fillColor: const Color(0xFFF8F9FA),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
            ),
          ),
          const SizedBox(height: 16),

          // Notes Field
          Text('Notes / Memo', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.richBlack)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _notesCtrl,
            maxLines: 3,
            style: GoogleFonts.outfit(fontSize: 14, color: AppColors.richBlack),
            decoration: InputDecoration(
              hintText: 'Add breakdown, payment terms, or memo for this transaction...',
              filled: true,
              fillColor: const Color(0xFFF8F9FA),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== ACTION BUTTONS ====================
  Widget _buildActionButtons(bool isEditing) {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: OutlinedButton(
            onPressed: _isSubmitting ? null : () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.stoneGray,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _handleSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedType == 'charge' ? Colors.red.shade700 : AppColors.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isEditing ? Icons.check_circle_outline : Icons.add_circle_outline_rounded,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isEditing ? 'Save Changes' : 'Record Transaction',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

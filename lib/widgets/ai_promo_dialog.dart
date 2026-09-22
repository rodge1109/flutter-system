import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';
import '../services/ai_promo_service.dart';

class AiPromoDialog extends StatefulWidget {
  final String venueName;
  final List<dynamic> courts;
  final List<dynamic> todayBookings;
  final String ownerEmail;

  const AiPromoDialog({
    super.key,
    required this.venueName,
    required this.courts,
    required this.todayBookings,
    required this.ownerEmail,
  });

  @override
  State<AiPromoDialog> createState() => _AiPromoDialogState();
}

class _AiPromoDialogState extends State<AiPromoDialog> {
  final AiPromoService _aiPromoService = AiPromoService();
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();

  bool _isGenerating = true;
  List<String> _openSlots = [];
  String _basePrice = '200';
  String _bookingUrl = 'https://pickleball.app';
  bool _copied = false;
  bool _showApiKeyInput = false;

  @override
  void initState() {
    super.initState();
    _initDataAndGenerate();
  }

  Future<void> _initDataAndGenerate() async {
    setState(() => _isGenerating = true);

    // Calculate base court price if available
    if (widget.courts.isNotEmpty) {
      final c = widget.courts.first;
      _basePrice = (c['base_price'] ?? c['hourly_price'] ?? '200').toString();
      final slug = (c['slug'] ?? widget.venueName.toLowerCase().replaceAll(' ', '')).toString();
      _bookingUrl = 'https://pickleball.app/$slug';
    }

    _openSlots = _aiPromoService.getTodayOpenSlots(
      courts: widget.courts,
      todayBookings: widget.todayBookings,
    );

    await _generateCaption();
  }

  Future<void> _generateCaption() async {
    setState(() => _isGenerating = true);

    final caption = await _aiPromoService.generateFacebookPromoCaption(
      venueName: widget.venueName.isNotEmpty ? widget.venueName : 'Our Court Venue',
      openSlots: _openSlots,
      basePrice: _basePrice,
      bookingUrl: _bookingUrl,
      apiKey: _apiKeyController.text.trim().isNotEmpty ? _apiKeyController.text.trim() : null,
    );

    if (mounted) {
      setState(() {
        _captionController.text = caption;
        _isGenerating = false;
      });
    }
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _captionController.text));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 Caption copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _shareToFacebook() async {
    _copyToClipboard();
    final encodedUrl = Uri.encodeComponent(_bookingUrl);
    final fbShareUrl = 'https://www.facebook.com/sharer/sharer.php?u=$encodedUrl';
    
    final Uri uri = Uri.parse(fbShareUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open browser for Facebook sharing.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final nowStr = '${DateTime.now().month}/${DateTime.now().day}/${DateTime.now().year}';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 540),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome, color: AppColors.primaryGreen, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '⚡ 1-Click AI FB Promo Generator',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.richBlack,
                          ),
                        ),
                        Text(
                          'Gemini AI Open Slots Social Marketing',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Open Slots Summary Pill
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.accentLime.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primaryGreen.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.event_available_rounded, size: 18, color: AppColors.primaryGreen),
                        const SizedBox(width: 8),
                        Text(
                          'Detected Open Slots Today ($nowStr):',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _openSlots.isEmpty
                        ? Text(
                            'All prime slots booked! Standard promo template generated.',
                            style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade800),
                          )
                        : Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _openSlots.take(6).map((slot) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.primaryGreen.withOpacity(0.4)),
                                ),
                                child: Text(
                                  slot,
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Visual Poster Graphic Card Preview
              Text(
                '🖼️ Generated Poster Graphic Preview:',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.richBlack),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryGreen, Color(0xFF0F382C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGreen.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accentLime,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '⚡ OPEN SLOTS TODAY',
                            style: GoogleFonts.outfit(
                              color: AppColors.richBlack,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        Text(
                          nowStr,
                          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      widget.venueName.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Book starting at ₱$_basePrice/hr',
                      style: GoogleFonts.outfit(color: AppColors.accentLime, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: _openSlots.take(4).map((s) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white30),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.access_time_rounded, size: 12, color: AppColors.accentLime),
                              const SizedBox(width: 4),
                              Text(
                                s,
                                style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // AI Generated Caption Text Area
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '✍️ AI Generated Caption Copy:',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.richBlack),
                  ),
                  TextButton.icon(
                    onPressed: _isGenerating ? null : _generateCaption,
                    icon: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.primaryGreen),
                    label: Text(
                      'Re-generate AI',
                      style: GoogleFonts.outfit(fontSize: 12, color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _isGenerating
                  ? Container(
                      height: 140,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: AppColors.primaryGreen),
                            SizedBox(height: 12),
                            Text('Gemini AI is crafting your Facebook post...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    )
                  : TextField(
                      controller: _captionController,
                      maxLines: 6,
                      style: GoogleFonts.outfit(fontSize: 13, color: AppColors.richBlack),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
                        ),
                      ),
                    ),
              const SizedBox(height: 12),

              // Optional Gemini API Key expansion
              GestureDetector(
                onTap: () => setState(() => _showApiKeyInput = !_showApiKeyInput),
                child: Row(
                  children: [
                    Icon(_showApiKeyInput ? Icons.arrow_drop_down : Icons.arrow_right, color: Colors.grey.shade700),
                    Text(
                      'Custom Gemini API Key Settings (Optional)',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              if (_showApiKeyInput) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _apiKeyController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'Paste Google Gemini API Key here (AI Studio)',
                    labelText: 'Gemini API Key',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _copyToClipboard,
                      icon: Icon(_copied ? Icons.check : Icons.copy, size: 18),
                      label: Text(_copied ? 'Copied!' : 'Copy Caption'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        side: const BorderSide(color: AppColors.primaryGreen),
                        foregroundColor: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _shareToFacebook,
                      icon: const Icon(Icons.facebook, size: 20, color: Colors.white),
                      label: Text(
                        'Share to Facebook',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color(0xFF1877F2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

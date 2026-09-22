import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';
import '../services/ai_promo_service.dart';

class AiPromoScreen extends StatefulWidget {
  final String venueName;
  final List<dynamic> courts;
  final List<dynamic> todayBookings;
  final String ownerEmail;

  const AiPromoScreen({
    super.key,
    required this.venueName,
    required this.courts,
    required this.todayBookings,
    required this.ownerEmail,
  });

  @override
  State<AiPromoScreen> createState() => _AiPromoScreenState();
}

class _AiPromoScreenState extends State<AiPromoScreen> {
  final AiPromoService _aiPromoService = AiPromoService();
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final GlobalKey _posterKey = GlobalKey();

  bool _isGenerating = true;
  bool _isExporting = false;
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

  @override
  void dispose() {
    _captionController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _initDataAndGenerate() async {
    setState(() => _isGenerating = true);

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

  Future<Uint8List?> _capturePosterBytes() async {
    try {
      final boundary = _posterKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      print('Error capturing poster graphic: $e');
      return null;
    }
  }

  Future<void> _downloadPosterGraphic() async {
    setState(() => _isExporting = true);
    final bytes = await _capturePosterBytes();
    setState(() => _isExporting = false);

    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not generate poster graphic image.')),
        );
      }
      return;
    }

    try {
      if (kIsWeb) {
        final base64String = base64Encode(bytes);
        final dataUri = Uri.parse('data:image/png;base64,$base64String');
        await launchUrl(dataUri);
      } else {
        final xFile = XFile.fromData(
          bytes,
          name: '${widget.venueName.replaceAll(' ', '_')}_promo.png',
          mimeType: 'image/png',
        );
        await Share.shareXFiles([xFile], text: '🏓 Court Promo Poster Graphic for ${widget.venueName}');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🖼️ Poster graphic downloaded / saved successfully!'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Download poster error: $e');
    }
  }

  Future<void> _shareToFacebook() async {
    _copyToClipboard();

    setState(() => _isExporting = true);
    final bytes = await _capturePosterBytes();
    setState(() => _isExporting = false);

    if (bytes != null) {
      try {
        final xFile = XFile.fromData(
          bytes,
          name: 'court_promo_poster.png',
          mimeType: 'image/png',
        );
        await Share.shareXFiles(
          [xFile],
          text: _captionController.text,
          subject: '🏓 Court Promo - ${widget.venueName}',
        );
        return;
      } catch (e) {
        print('Share XFile failed, falling back to Facebook sharer: $e');
      }
    }

    // Direct Web Sharer fallback
    final encodedUrl = Uri.encodeComponent(_bookingUrl);
    final fbShareUrl = 'https://www.facebook.com/sharer/sharer.php?u=$encodedUrl';

    final Uri uri = Uri.parse(fbShareUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open browser for Facebook sharing.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final nowStr = '${DateTime.now().month}/${DateTime.now().day}/${DateTime.now().year}';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.richBlack, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: AppColors.primaryGreen, size: 20),
                const SizedBox(width: 8),
                Text(
                  '1-Click AI FB Promo Generator',
                  style: GoogleFonts.outfit(
                    color: AppColors.richBlack,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Text(
              'Gemini AI Open Slots Marketing',
              style: GoogleFonts.outfit(
                color: Colors.grey.shade600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Open Slots Summary Pill Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primaryGreen.withOpacity(0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryGreen.withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.event_available_rounded, size: 18, color: AppColors.primaryGreen),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Detected Open Slots Today ($nowStr):',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.richBlack,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.accentLime.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_openSlots.length} Slots Available',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _openSlots.isEmpty
                            ? Text(
                                'All prime slots booked! Standard promo template generated.',
                                style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade700),
                              )
                            : Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _openSlots.map((slot) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryGreen.withOpacity(0.06),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: AppColors.primaryGreen.withOpacity(0.25)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.access_time_rounded, size: 13, color: AppColors.primaryGreen),
                                        const SizedBox(width: 5),
                                        Text(
                                          slot,
                                          style: GoogleFonts.outfit(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primaryGreen,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Poster Graphic Card Preview Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '🖼️ Generated Poster Graphic Preview',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.richBlack),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isExporting ? null : _downloadPosterGraphic,
                        icon: _isExporting
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen))
                            : const Icon(Icons.download_rounded, size: 16, color: AppColors.primaryGreen),
                        label: Text(
                          'Download Graphic',
                          style: GoogleFonts.outfit(fontSize: 12, color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen.withOpacity(0.12),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Capturable RepaintBoundary Poster Card
                  RepaintBoundary(
                    key: _posterKey,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primaryGreen, Color(0xFF0F382C)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryGreen.withOpacity(0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.accentLime,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '⚡ OPEN SLOTS TODAY',
                                  style: GoogleFonts.outfit(
                                    color: AppColors.richBlack,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              Text(
                                nowStr,
                                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            widget.venueName.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Book court slots starting at ₱$_basePrice/hr',
                            style: GoogleFonts.outfit(color: AppColors.accentLime, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            alignment: WrapAlignment.center,
                            children: _openSlots.take(6).map((s) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white30),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.access_time_rounded, size: 14, color: AppColors.accentLime),
                                    const SizedBox(width: 6),
                                    Text(
                                      s,
                                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // AI Generated Caption Copy Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '✍️ AI Generated Facebook Caption',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.richBlack),
                      ),
                      TextButton.icon(
                        onPressed: _isGenerating ? null : _generateCaption,
                        icon: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.primaryGreen),
                        label: Text(
                          'Re-generate AI',
                          style: GoogleFonts.outfit(fontSize: 13, color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _isGenerating
                      ? Container(
                          height: 180,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(color: AppColors.primaryGreen),
                                SizedBox(height: 14),
                                Text(
                                  'Gemini AI is crafting your Facebook promo post...',
                                  style: TextStyle(fontSize: 13, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _captionController,
                            maxLines: 9,
                            style: GoogleFonts.outfit(fontSize: 14, color: AppColors.richBlack, height: 1.4),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              hintText: 'Your AI generated Facebook post will appear here...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide(color: Colors.grey.shade200),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
                              ),
                              contentPadding: const EdgeInsets.all(18),
                            ),
                          ),
                        ),
                  const SizedBox(height: 16),

                  // Optional Gemini API Key Settings
                  GestureDetector(
                    onTap: () => setState(() => _showApiKeyInput = !_showApiKeyInput),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(_showApiKeyInput ? Icons.arrow_drop_down : Icons.arrow_right, color: Colors.grey.shade700),
                          const SizedBox(width: 4),
                          Text(
                            'Custom Gemini API Key Settings (Optional)',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showApiKeyInput) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _apiKeyController,
                      obscureText: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hintText: 'Paste Google Gemini API Key here (AI Studio)',
                        labelText: 'Gemini API Key',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),

                  // Bottom Action Buttons Row
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      SizedBox(
                        width: 180,
                        child: OutlinedButton.icon(
                          onPressed: _copyToClipboard,
                          icon: Icon(_copied ? Icons.check : Icons.copy, size: 18),
                          label: Text(
                            _copied ? 'Copied!' : 'Copy Caption',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            side: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
                            foregroundColor: AppColors.primaryGreen,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 190,
                        child: OutlinedButton.icon(
                          onPressed: _isExporting ? null : _downloadPosterGraphic,
                          icon: const Icon(Icons.file_download_outlined, size: 18),
                          label: Text(
                            'Download Graphic',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            side: BorderSide(color: Colors.grey.shade400, width: 1.5),
                            foregroundColor: AppColors.richBlack,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: ElevatedButton.icon(
                          onPressed: _shareToFacebook,
                          icon: const Icon(Icons.facebook, size: 20, color: Colors.white),
                          label: Text(
                            'Share Poster & Caption',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: const Color(0xFF1877F2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

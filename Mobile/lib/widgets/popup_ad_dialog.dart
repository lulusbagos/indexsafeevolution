import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/popup_ad_model.dart';

class PopupAdDialog extends StatefulWidget {
  final PopupAdData adData;
  final String fullImageUrl;

  const PopupAdDialog({
    super.key,
    required this.adData,
    required this.fullImageUrl,
  });

  static Future<void> show(
    BuildContext context, {
    required PopupAdData adData,
    required String fullImageUrl,
  }) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Tutup Iklan',
      barrierColor: Colors.black.withValues(alpha: 0.72),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (ctx, anim1, anim2) {
        return PopupAdDialog(
          adData: adData,
          fullImageUrl: fullImageUrl,
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved = CurvedAnimation(
          parent: anim1,
          curve: Curves.easeOutBack,
        );
        return ScaleTransition(
          scale: curved,
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<PopupAdDialog> createState() => _PopupAdDialogState();
}

class _PopupAdDialogState extends State<PopupAdDialog> {
  bool _isLoading = true;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * 0.76;
    final maxWidth = (media.size.width * 0.90).clamp(280.0, 440.0);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: maxWidth,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dialog Card Box
              Container(
                constraints: BoxConstraints(maxHeight: maxHeight),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 30,
                      spreadRadius: 4,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: const Color(0xFF0F766E).withValues(alpha: 0.18),
                      blurRadius: 20,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Scrollable Image Container
                      SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: maxHeight - 10,
                          ),
                          child: InteractiveViewer(
                            minScale: 1.0,
                            maxScale: 3.0,
                            child: Image.network(
                              widget.fullImageUrl,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) {
                                  if (_isLoading) {
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      if (mounted) setState(() => _isLoading = false);
                                    });
                                  }
                                  return child;
                                }
                                final expected = loadingProgress.expectedTotalBytes;
                                final cumulative = loadingProgress.cumulativeBytesLoaded;
                                final value = (expected != null && expected > 0)
                                    ? cumulative / expected
                                    : null;

                                return Container(
                                  height: 280,
                                  width: double.infinity,
                                  color: const Color(0xFFF8FAFC),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 36,
                                          height: 36,
                                          child: CircularProgressIndicator(
                                            value: value,
                                            strokeWidth: 3,
                                            color: const Color(0xFF0D9488),
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        const Text(
                                          'Memuat info...',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 220,
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(20),
                                  color: const Color(0xFFF8FAFC),
                                  child: const Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.broken_image_rounded,
                                          size: 48,
                                          color: Color(0xFF94A3B8),
                                        ),
                                        SizedBox(height: 10),
                                        Text(
                                          'Gagal memuat gambar informasi',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),

                      // Top Floating Close Button
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Semantics(
                          button: true,
                          label: 'Tutup Pengumuman',
                          child: Material(
                            color: Colors.black.withValues(alpha: 0.55),
                            shape: const CircleBorder(),
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.of(context, rootNavigator: true).pop();
                              },
                              customBorder: const CircleBorder(),
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    width: 1.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                  size: 19,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Bottom Dismiss Pill Button
              Semantics(
                button: true,
                label: 'Tutup Iklan',
                child: TextButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context, rootNavigator: true).pop();
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Tutup',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.22),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../pages/reinduction_form_page.dart';
import '../services/api.dart';
import '../services/preference.dart';

class ReinductionPromptDialog extends StatelessWidget {
  const ReinductionPromptDialog({super.key});

  static bool _isChecking = false;
  static bool _isShowing = false;

  static String _getMonthName(int month) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    if (month >= 1 && month <= 12) return months[month - 1];
    return '';
  }

  /// Memeriksa status re-induksi bulanan karyawan saat aplikasi dibuka di awal bulan.
  /// Jika sudah mengisi di bulan berjalan, pop up tidak akan muncul lagi di bulan tersebut.
  /// Jika belum mengisi, pop up akan muncul mengingatkan pengisian.
  static Future<void> checkAndPrompt(BuildContext context) async {
    if (_isChecking || _isShowing) return;
    _isChecking = true;

    try {
      final now = DateTime.now();
      final monthKey = 'reinduksi_filled_${now.year}_${now.month}';
      final prefs = await SharedPreferences.getInstance();

      // 1. Cek cache lokal: jika sudah tercatat selesai bulan ini, lewati
      if (prefs.getBool(monthKey) == true) {
        _isChecking = false;
        return;
      }

      // 2. Cek status ke server
      final api = ApiService();
      final res = await api.getRosterStatus();

      if (!context.mounted) {
        _isChecking = false;
        return;
      }

      await res.fold(
        (err) async {
          debugPrint('[ReinductionPromptDialog] Gagal memeriksa status: ${err['message']}');
        },
        (data) async {
          final bool hasFilledThisMonth = data['hasFilledReinduksiThisMonth'] == true;
          debugPrint('[ReinductionPromptDialog] hasFilledReinduksiThisMonth: $hasFilledThisMonth');

          if (hasFilledThisMonth) {
            // Sudah mengisi di server, update cache lokal agar tidak dicek berulang
            await prefs.setBool(monthKey, true);
            return;
          }

          // Belum mengisi di bulan ini -> Munculkan pop up Re-Induksi
          if (context.mounted) {
            _isShowing = true;
            await showGeneralDialog(
              context: context,
              barrierDismissible: true,
              barrierLabel: 'Tutup',
              barrierColor: Colors.black.withValues(alpha: 0.72),
              transitionDuration: const Duration(milliseconds: 320),
              pageBuilder: (ctx, anim1, anim2) => const ReinductionPromptDialog(),
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
            _isShowing = false;
          }
        },
      );
    } catch (e) {
      debugPrint('[ReinductionPromptDialog] Exception: $e');
    } finally {
      _isChecking = false;
    }
  }

  /// Backward-compatible alias
  static Future<void> checkAndPromptRoster(BuildContext context) => checkAndPrompt(context);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final periodeStr = '${_getMonthName(now.month)} ${now.year}';

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: (MediaQuery.of(context).size.width * 0.88).clamp(280.0, 400.0),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: const Color(0xFF0F766E).withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Header Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF0F766E),
                        Color(0xFF14B8A6),
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          size: 42,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'RE-INDUKSI K3LH',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Wajib Awal Bulan',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content Body
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        'Komitmen Keselamatan Periode $periodeStr',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Untuk menjaga kepatuhan keselamatan tambang dan kesiapan operasional di area kerja PT Indexim Coalindo & Mitra Kerja, setiap karyawan wajib mengisi Form Re-Induksi K3LH di setiap awal bulan.\n\nFormulir ini hanya perlu diisi 1 kali dalam sebulan.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          height: 1.45,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      // Button Isi Re-Induksi Sekarang
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            HapticFeedback.mediumImpact();
                            Navigator.of(context).pop();
                            final profile = PreferenceService.getProfile();
                            final filled = await Navigator.of(context).push<bool>(
                              MaterialPageRoute(
                                builder: (_) => ReinductionFormPage(profile: profile),
                              ),
                            );
                            if (filled == true) {
                              final prefs = await SharedPreferences.getInstance();
                              final now = DateTime.now();
                              await prefs.setBool('reinduksi_filled_${now.year}_${now.month}', true);
                            }
                          },
                          icon: const Icon(Icons.assignment_turned_in_rounded, color: Colors.white, size: 20),
                          label: const Text(
                            'Isi Re-Induksi Sekarang',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F766E),
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Button Nanti Saja
                      SizedBox(
                        width: double.infinity,
                        height: 38,
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            'Nanti Saja',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Backward compatibility alias
typedef RosterPromptDialog = ReinductionPromptDialog;

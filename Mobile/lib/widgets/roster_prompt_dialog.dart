import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../pages/roster_settings_page.dart';
import '../services/api.dart';

class RosterPromptDialog extends StatelessWidget {
  const RosterPromptDialog({super.key});

  static bool _isChecking = false;
  static bool _isShowing = false;

  /// Memeriksa status roster karyawan setelah iklan muncul.
  /// Jika belum ada roster aktif / belum disetting, pop up akan muncul.
  /// Jika sudah disetting, pop up tidak akan muncul.
  static Future<void> checkAndPromptRoster(BuildContext context) async {
    if (_isChecking || _isShowing) return;
    _isChecking = true;

    try {
      final api = ApiService();
      final res = await api.getRosterStatus();

      if (!context.mounted) {
        _isChecking = false;
        return;
      }

      res.fold(
        (err) {
          debugPrint('[RosterPromptDialog] Gagal memeriksa status roster: ${err['message']}');
        },
        (data) async {
          final bool hasConfigured = data['hasConfiguredRoster'] == true;
          debugPrint('[RosterPromptDialog] hasConfiguredRoster: $hasConfigured');

          if (!hasConfigured && context.mounted) {
            _isShowing = true;
            await showGeneralDialog(
              context: context,
              barrierDismissible: true,
              barrierLabel: 'Tutup',
              barrierColor: Colors.black.withValues(alpha: 0.72),
              transitionDuration: const Duration(milliseconds: 320),
              pageBuilder: (ctx, anim1, anim2) => const RosterPromptDialog(),
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
      debugPrint('[RosterPromptDialog] Exception: $e');
    } finally {
      _isChecking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
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
                          Icons.calendar_month_rounded,
                          size: 44,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'PENGATURAN ROSTER',
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
                          'Wajib Diisi Karyawan',
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

                // Content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text(
                        'Jadwal Roster Belum Diatur!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Anda belum mengatur jadwal Roster Kerja Anda atau periode dinas sebelumnya telah berakhir.\n\nHarap lakukan pengaturan jadwal dinas & cuti Anda serta melengkapi Form Re-Induksi untuk mengaktifkan target kepatuhan K3LH.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          height: 1.45,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      // Button Atur Sekarang
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const RosterSettingsPage(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.edit_calendar_rounded, color: Colors.white, size: 20),
                          label: const Text(
                            'Atur Roster Sekarang',
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

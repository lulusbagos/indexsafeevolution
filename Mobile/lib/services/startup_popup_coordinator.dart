import 'package:flutter/material.dart';
import '../services/popup_ad_service.dart';
import '../services/preference.dart';
import '../widgets/roster_prompt_dialog.dart';
import '../widgets/web_campaign_dialog.dart';

/// Coordinator terpusat untuk mengatur alur pop-up dialog pada saat aplikasi dimulai (Startup).
///
/// Memastikan bahwa pop-up tidak pernah bertumpuk (stacked / overlapping) di layar.
/// Jika ada beberapa pop-up yang perlu tampil (misal: Iklan/Banner Info Harian,
/// Re-Induksi K3LH Bulanan, dan Web Campaign), mereka akan muncul secara BERGANTIAN:
/// Pop-up pertama ditutup terlebih dahulu -> jeda transisi halus -> pop-up berikutnya muncul.
class StartupPopupCoordinator {
  static bool _isRunning = false;

  /// Mengecek apakah proses antrean startup popup sedang berlangsung
  /// atau salah satu dialog startup sedang aktif di layar.
  static bool get isAnyPopupActive =>
      _isRunning ||
      PopupAdService.isShowing ||
      ReinductionPromptDialog.isShowing ||
      WebCampaignDialog.isShowing;

  /// Menjalankan pop-up startup secara berurutan dan anti-tumpuk.
  ///
  /// Urutan Prioritas Tampilan:
  /// 1. Iklan / Banner Informasi Harian (PopupAdService)
  ///    - Ditutup user -> jeda 500ms -> lanjut ke Re-Induksi
  /// 2. Re-Induksi K3LH Bulanan (ReinductionPromptDialog)
  ///    - Jika user pilih "Isi Re-Induksi Sekarang", alur berhenti agar tidak mengganggu pengisian form
  ///    - Jika user pilih "Nanti Saja" / tutup barrier -> jeda 500ms -> lanjut ke Web Campaign
  /// 3. Web Campaign / Kuis K3 Interaktif (WebCampaignDialog)
  static Future<void> runSequentialPopups(BuildContext context) async {
    if (_isRunning) {
      debugPrint('[StartupPopupCoordinator] Already running, skipping duplicate invocation.');
      return;
    }
    _isRunning = true;

    try {
      // Berikan jeda inisial agar frame render halaman Beranda stabil
      await Future.delayed(const Duration(milliseconds: 750));
      if (!context.mounted) return;

      // ==========================================
      // 1. TAHAP 1: Iklan / Banner Info Harian (Gambar)
      // ==========================================
      debugPrint('[StartupPopupCoordinator] Step 1: Checking PopupAd...');
      final adShown = await PopupAdService.checkAndShowPopupAd(context, force: true);
      if (adShown) {
        debugPrint('[StartupPopupCoordinator] Step 1: PopupAd closed. Waiting exit animation...');
        // Jeda halus agar dialog pertama selesai exit transition (320ms + jeda 180ms)
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (!context.mounted) return;

      // ==========================================
      // 2. TAHAP 2: Re-Induksi K3LH Bulanan
      // ==========================================
      debugPrint('[StartupPopupCoordinator] Step 2: Checking Re-Induksi...');
      final reinductionResult = await ReinductionPromptDialog.checkAndPrompt(context);
      if (reinductionResult == ReinductionPromptResult.formOpened) {
        debugPrint('[StartupPopupCoordinator] Step 2: User opened Re-Induksi form. Pausing next popups.');
        return;
      } else if (reinductionResult == ReinductionPromptResult.dismissed) {
        debugPrint('[StartupPopupCoordinator] Step 2: Re-Induksi closed. Waiting exit animation...');
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (!context.mounted) return;

      // ==========================================
      // 3. TAHAP 3: Web Campaign / Kuis K3
      // ==========================================
      final profile = PreferenceService.getProfile();
      String userNik = profile?.noNik?.trim() ?? '';
      if (userNik.isEmpty) {
        userNik = PreferenceService.getOfflineNik() ?? '';
      }
      if (userNik.isNotEmpty) {
        debugPrint('[StartupPopupCoordinator] Step 3: Checking WebCampaign for NIK: $userNik');
        await WebCampaignDialog.checkAndShow(
          context,
          nik: userNik,
          nama: profile?.namaLengkap ?? '',
          depart: profile?.depart ?? '',
        );
      }
    } catch (e) {
      debugPrint('[StartupPopupCoordinator] Error in sequential flow: $e');
    } finally {
      _isRunning = false;
    }
  }
}

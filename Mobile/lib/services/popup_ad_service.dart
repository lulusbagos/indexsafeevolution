import 'package:flutter/material.dart';

import '../widgets/popup_ad_dialog.dart';
import 'api.dart';
import 'preference.dart';

class PopupAdService {
  static bool _isShowing = false;

  static bool get isShowing => _isShowing;

  /// Memeriksa dan menampilkan iklan popup jika tersedia dari backend.
  /// Otomatis muncul 1 hari sekali setiap aplikasi dibuka.
  /// Jika ada gambar baru (fileName berubah), akan langsung muncul hari itu juga.
  /// Mengembalikan true jika dialog iklan berhasil ditampilkan dan ditutup user.
  static Future<bool> checkAndShowPopupAd(
    BuildContext context, {
    bool force = false,
  }) async {
    if (_isShowing) return false;

    try {
      final api = ApiService();

      // Ambil informasi iklan aktif dari backend (mendukung Wi-Fi, Cellular, maupun USB ADB Reverse)
      final adRes = await api.getActivePopupAd();
      debugPrint('[PopupAdService] Fetch result: hasAd=${adRes?.hasAd}, data=${adRes?.data?.fileName}');
      if (adRes == null || !adRes.hasAd || adRes.data == null) {
        return false;
      }

      final adData = adRes.data!;
      if (adData.fileName.isEmpty || adData.imageUrl.isEmpty) {
        return false;
      }

      // 3. Tampilkan iklan aktif dari backend pada saat startup
      final now = DateTime.now();
      final todayStr =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      final lastShownDate = PreferenceService.getLastAdShownDate();
      final lastShownFile = PreferenceService.getLastAdShownFile();

      // Selalu tampilkan jika force == true atau ada iklan aktif dari backend
      final shouldShow = force || adData.fileName.isNotEmpty;

      debugPrint('[PopupAdService] today=$todayStr, lastDate=$lastShownDate, lastFile=$lastShownFile, shouldShow=$shouldShow');

      if (!shouldShow) {
        debugPrint('[PopupAdService] No ad to display. Skipping.');
        return false;
      }

      if (!context.mounted) {
        debugPrint('[PopupAdService] Context not mounted. Skipping.');
        return false;
      }

      _isShowing = true;

      final fullUrl = api.resolveImageUrl(adData.imageUrl);
      debugPrint('[PopupAdService] Showing PopupAdDialog with fullUrl: $fullUrl');

      // 4. Tampilkan dialog popup iklan
      await PopupAdDialog.show(
        context,
        adData: adData,
        fullImageUrl: fullUrl,
      );
      debugPrint('[PopupAdService] PopupAdDialog was closed.');

      // 5. Catat waktu tampil hari ini & file iklannya setelah dialog berhasil ditampilkan
      await PreferenceService.setLastAdShown(
        dateStr: todayStr,
        fileName: adData.fileName,
      );
      return true;
    } catch (e) {
      debugPrint('[PopupAdService] Error in checkAndShowPopupAd: $e');
      return false;
    } finally {
      _isShowing = false;
    }
  }
}

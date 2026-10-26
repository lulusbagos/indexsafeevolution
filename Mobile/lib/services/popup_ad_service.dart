import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../widgets/popup_ad_dialog.dart';
import 'api.dart';
import 'preference.dart';

class PopupAdService {
  static bool _isShowing = false;

  /// Memeriksa dan menampilkan iklan popup jika tersedia dari backend.
  /// Otomatis muncul 1 hari sekali setiap aplikasi dibuka.
  /// Jika ada gambar baru (fileName berubah), akan langsung muncul hari itu juga.
  static Future<void> checkAndShowPopupAd(
    BuildContext context, {
    bool force = false,
  }) async {
    if (_isShowing) return;

    try {
      final api = ApiService();

      // Ambil informasi iklan aktif dari backend (mendukung Wi-Fi, Cellular, maupun USB ADB Reverse)
      final adRes = await api.getActivePopupAd();
      debugPrint('[PopupAdService] Fetch result: hasAd=${adRes?.hasAd}, data=${adRes?.data?.fileName}');
      if (adRes == null || !adRes.hasAd || adRes.data == null) {
        return;
      }

      final adData = adRes.data!;
      if (adData.fileName.isEmpty || adData.imageUrl.isEmpty) {
        return;
      }

      // 3. Cek pembatasan 1 hari sekali
      final now = DateTime.now();
      final todayStr =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      final lastShownDate = PreferenceService.getLastAdShownDate();
      final lastShownFile = PreferenceService.getLastAdShownFile();

      // Jika belum pernah ditampilkan hari ini, atau jika file gambar iklannya baru
      final shouldShow = force ||
          lastShownDate != todayStr ||
          lastShownFile != adData.fileName;

      debugPrint('[PopupAdService] today=$todayStr, lastDate=$lastShownDate, lastFile=$lastShownFile, shouldShow=$shouldShow');

      if (!shouldShow) {
        debugPrint('[PopupAdService] Ad already displayed today. Skipping.');
        return;
      }

      if (!context.mounted) {
        debugPrint('[PopupAdService] Context not mounted. Skipping.');
        return;
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
    } catch (e) {
      debugPrint('[PopupAdService] Error in checkAndShowPopupAd: $e');
    } finally {
      _isShowing = false;
    }
  }
}

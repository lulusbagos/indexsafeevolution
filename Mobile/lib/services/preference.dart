import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/foundation.dart';

import '../models/auth_model.dart';
import '../models/profile_model.dart';
import '../utils/crypto_util.dart';

class PreferenceService {
  static Future<SharedPreferences> get _instance async =>
      prefs ??= await SharedPreferences.getInstance();
  static SharedPreferences? prefs;

  /// Reactive notifier to instantly sync profile picture changes between Home & Profile
  static final ValueNotifier<String?> profilePhotoNotifier =
      ValueNotifier<String?>(null);

  static Future<SharedPreferences> init() async {
    prefs = await _instance;
    // Pre-populate notifier with stored profile photo
    final p = getProfile();
    if (p?.foto != null) {
      profilePhotoNotifier.value = p!.foto;
    }
    return prefs ?? await SharedPreferences.getInstance();
  }

  static Future<void> setAuth(AuthModel auth) async {
    final raw = jsonEncode(auth.toJson());
    await prefs?.setString('authJson', CryptoUtil.encrypt(raw));
  }

  static Future<void> setObservationOptionsCache(
      Map<String, dynamic> value) async {
    await prefs?.setString(
        'observationOptionsCache', CryptoUtil.encrypt(jsonEncode(value)));
  }

  static Map<String, dynamic>? getObservationOptionsCache() {
    final raw = prefs?.getString('observationOptionsCache');
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(CryptoUtil.decrypt(raw));
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  /// Cookie sesi MBS SAP untuk request native yang memakai endpoint web resmi.
  /// Disimpan terenkripsi seperti data autentikasi lain dan tidak pernah dicetak
  /// ke log aplikasi.
  static Future<void> setMbsSessionCookie(String value) async {
    await prefs?.setString('mbsSessionCookie', CryptoUtil.encrypt(value));
  }

  static String? getMbsSessionCookie() {
    final raw = prefs?.getString('mbsSessionCookie');
    if (raw == null || raw.isEmpty) return null;
    final decrypted = CryptoUtil.decrypt(raw);
    return decrypted.isEmpty ? null : decrypted;
  }

  static Future<void> setProfile(ProfileModel profile) async {
    final raw = jsonEncode(profile.toJson());
    await prefs?.setString('profileJson', CryptoUtil.encrypt(raw));
    profilePhotoNotifier.value = profile.foto;
  }

  static Future<void> setProfilePict(String pict) async {
    ProfileModel? profile = getProfile();
    if (profile != null) {
      profile.foto = pict;
      await setProfile(profile);
    } else {
      profilePhotoNotifier.value = pict;
    }
  }

  static void notifyProfilePhotoChanged(String? foto) {
    profilePhotoNotifier.value = foto;
  }

  static Future<void> setUserPassword(String user, String pswd) async {
    await prefs?.setString('userLogin', CryptoUtil.encrypt(user));
    await prefs?.setString('pswdLogin', CryptoUtil.encrypt(pswd));
  }

  /// Simpan kredensial terenkripsi khusus untuk mode offline tambang
  static Future<void> setOfflineCredentials({
    required String nik,
    required String password,
    String? fullName,
  }) async {
    await prefs?.setString('offline_nik', CryptoUtil.encrypt(nik.trim()));
    await prefs?.setString('offline_pswd', CryptoUtil.encrypt(password));
    if (fullName != null && fullName.isNotEmpty) {
      await prefs?.setString('offline_name', CryptoUtil.encrypt(fullName));
    }
  }

  static String? getOfflineNik() {
    final val = prefs?.getString('offline_nik');
    if (val == null || val.isEmpty) return null;
    final decrypted = CryptoUtil.decrypt(val);
    return decrypted.isNotEmpty ? decrypted : null;
  }

  static String? getOfflinePassword() {
    final val = prefs?.getString('offline_pswd');
    if (val == null || val.isEmpty) return null;
    final decrypted = CryptoUtil.decrypt(val);
    return decrypted.isNotEmpty ? decrypted : null;
  }

  static String? getOfflineName() {
    final val = prefs?.getString('offline_name');
    if (val == null || val.isEmpty) return null;
    final decrypted = CryptoUtil.decrypt(val);
    return decrypted.isNotEmpty ? decrypted : null;
  }

  /// Apakah seluruh data master sudah tersinkronisasi dan siap untuk offline mode
  static bool isMasterDataSynced() {
    final sync = getDataSync();
    return sync != null && sync.length >= 10;
  }

  static Future<void> setDataSync(Map<String, dynamic> master) async {
    await prefs?.setString('dataSync', jsonEncode(master));
  }

  static Future<void> clearDataSync() async {
    await prefs?.remove('dataSync');
  }

  static Future<void> setNotif(int total) async {
    await prefs?.setInt('notif', total);
  }

  static Future<void> setNotifCounts(
      {required int unread, required int unactioned}) async {
    await prefs?.setInt('notif_unread', unread);
    await prefs?.setInt('notif_unactioned', unactioned);
    await prefs?.setInt('notif', unread + unactioned);
  }

  static int getNotifUnread() =>
      prefs?.getInt('notif_unread') ?? prefs?.getInt('notif') ?? 0;
  static int getNotifUnactioned() => prefs?.getInt('notif_unactioned') ?? 0;
  static int getTotalPendingNotif() => prefs?.getInt('notif') ?? 0;

  static Future<void> setLastSeenIncidentId(int id) async {
    await prefs?.setInt('last_seen_incident_id', id);
  }

  static int getLastSeenIncidentId() =>
      prefs?.getInt('last_seen_incident_id') ?? 0;

  static String? getUser() {
    final val = prefs?.getString('userLogin');
    if (val == null || val.isEmpty) return null;
    final decrypted = CryptoUtil.decrypt(val);
    return decrypted.isNotEmpty ? decrypted : null;
  }

  static String? getPassword() {
    final val = prefs?.getString('pswdLogin');
    if (val == null || val.isEmpty) return null;
    final decrypted = CryptoUtil.decrypt(val);
    return decrypted.isNotEmpty ? decrypted : null;
  }

  static String? getBgToken() => prefs?.getString('bgToken');

  static Future<void> removeAuth() async {
    await prefs?.remove('authJson');
    await prefs?.remove('mbsSessionCookie');
  }

  static Future<void> removeProfile() async {
    await prefs?.remove('profileJson');
    profilePhotoNotifier.value = null;
  }

  static AuthModel? getAuth() {
    String? auth = prefs?.getString('authJson');
    if (auth != null && auth.isNotEmpty) {
      final decrypted = CryptoUtil.decrypt(auth);
      if (decrypted.isNotEmpty) {
        try {
          return AuthModel.fromJson(jsonDecode(decrypted));
        } catch (_) {}
      }
    }
    return null;
  }

  static ProfileModel? getProfile() {
    String? profile = prefs?.getString('profileJson');
    if (profile != null && profile.isNotEmpty) {
      final decrypted = CryptoUtil.decrypt(profile);
      if (decrypted.isNotEmpty) {
        try {
          return ProfileModel.fromJson(jsonDecode(decrypted));
        } catch (_) {}
      }
    }
    return null;
  }

  static Map<String, dynamic>? getDataSync() {
    String? master = prefs?.getString('dataSync');
    if (master != null) {
      return jsonDecode(master) as Map<String, dynamic>;
    }
    return null;
  }

  static int getNotif() {
    return prefs?.getInt('notif') ?? 0;
  }

  /// Kontrol efisiensi baterai & Background Service
  static Future<void> setBackgroundSyncEnabled(bool enabled) async {
    await prefs?.setBool('bg_sync_enabled', enabled);
  }

  static bool isBackgroundSyncEnabled() {
    return prefs?.getBool('bg_sync_enabled') ??
        false; // Default: false (Hemat baterai aktif)
  }

  /// Pengaturan Hemat Baterai & Mencegah HP Panas (Default: TRUE / Hemat Baterai Aktif)
  static Future<void> setPowerSaverEnabled(bool enabled) async {
    await prefs?.setBool('power_saver_enabled', enabled);
  }

  static bool isPowerSaverEnabled() {
    return prefs?.getBool('power_saver_enabled') ??
        true; // Default: ON (Dingin & Hemat Baterai)
  }

  /// Pengaturan Notifikasi & Getar Otomatis Background (Default: FALSE / Mati)
  static Future<void> setAutoNotifEnabled(bool enabled) async {
    await prefs?.setBool('auto_notif_enabled', enabled);
  }

  static bool isAutoNotifEnabled() {
    return prefs?.getBool('auto_notif_enabled') ??
        false; // Default: OFF (Mencegah panas)
  }

  /// Pengaturan Mode Peta Hazard ('heatmap', 'points', 'off')
  static Future<void> setHazardMapMode(String mode) async {
    await prefs?.setString('hazard_map_mode', mode);
  }

  static String getHazardMapMode() {
    return prefs?.getString('hazard_map_mode') ?? 'heatmap';
  }

  /// Catatan tanggal terakhir kali iklan/banner popup dimunculkan (Format: yyyy-MM-dd)
  static String? getLastAdShownDate() {
    return prefs?.getString('last_popup_ad_shown_date');
  }

  static String? getLastAdShownFile() {
    return prefs?.getString('last_popup_ad_shown_file');
  }

  static Future<void> setLastAdShown({
    required String dateStr,
    required String fileName,
  }) async {
    await prefs?.setString('last_popup_ad_shown_date', dateStr);
    await prefs?.setString('last_popup_ad_shown_file', fileName);
  }

  static Future<void> clearLastAdShown() async {
    await prefs?.remove('last_popup_ad_shown_date');
    await prefs?.remove('last_popup_ad_shown_file');
  }

  /// Cache data titik Safe Map untuk Dashboard (1 hari sekali)
  static String? getHazardMapLastFetchDate() {
    return prefs?.getString('safemap_last_fetch_date');
  }

  static String? getCachedHazardMapJson() {
    return prefs?.getString('safemap_cached_points_json');
  }

  static Future<void> setCachedHazardMapPoints({
    required String jsonString,
    required String dateStr,
  }) async {
    await prefs?.setString('safemap_cached_points_json', jsonString);
    await prefs?.setString('safemap_last_fetch_date', dateStr);
  }

  static Future<void> setFcmToken(String token) async {
    await prefs?.setString('fcm_token', token);
  }

  static String? getFcmToken() {
    return prefs?.getString('fcm_token');
  }
}

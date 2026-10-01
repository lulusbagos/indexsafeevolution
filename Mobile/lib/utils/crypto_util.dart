import 'dart:convert';

/// Utility untuk enkripsi dan dekripsi data sensitif (kredensial, password, token)
/// sebelum disimpan ke penyimpanan lokal (SharedPreferences / Storage).
class CryptoUtil {
  // Kunci enkripsi internal aplikasi
  static const String _vaultKey =
      'INDEXSAFE_EVOLUTION_K3_MINING_OFFLINE_SECURE_ENCRYPTION_KEY_2026!#@*';
  static const String _prefix = 'enc:v1:';

  /// Enkripsi teks menjadi string aman terproteksi Base64 + Stream Cipher
  static String encrypt(String plainText) {
    if (plainText.isEmpty) return '';
    try {
      final textBytes = utf8.encode(plainText);
      final keyBytes = utf8.encode(_vaultKey);
      final encryptedBytes = <int>[];

      for (int i = 0; i < textBytes.length; i++) {
        final keyByte = keyBytes[i % keyBytes.length];
        // Stream obfuscation dengan salt rotasi index
        final encryptedByte = (textBytes[i] ^ keyByte ^ ((i * 7 + 13) & 0xFF)) & 0xFF;
        encryptedBytes.add(encryptedByte);
      }

      return '$_prefix${base64Encode(encryptedBytes)}';
    } catch (_) {
      // Fallback aman
      return '$_prefix${base64Encode(utf8.encode(plainText))}';
    }
  }

  /// Dekripsi string terenkripsi kembali ke teks asli
  static String decrypt(String? cipherText) {
    if (cipherText == null || cipherText.isEmpty) return '';
    if (!cipherText.startsWith(_prefix)) {
      // Data lama yang belum terenkripsi (backward compatible)
      return cipherText;
    }

    try {
      final rawBase64 = cipherText.substring(_prefix.length);
      final encryptedBytes = base64Decode(rawBase64);
      final keyBytes = utf8.encode(_vaultKey);
      final decryptedBytes = <int>[];

      for (int i = 0; i < encryptedBytes.length; i++) {
        final keyByte = keyBytes[i % keyBytes.length];
        final decryptedByte = (encryptedBytes[i] ^ keyByte ^ ((i * 7 + 13) & 0xFF)) & 0xFF;
        decryptedBytes.add(decryptedByte);
      }

      return utf8.decode(decryptedBytes);
    } catch (_) {
      // Jika format fallback standar base64
      try {
        final rawBase64 = cipherText.substring(_prefix.length);
        return utf8.decode(base64Decode(rawBase64));
      } catch (_) {
        return cipherText;
      }
    }
  }
}

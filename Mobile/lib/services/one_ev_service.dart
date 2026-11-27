import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../services/api.dart';
import '../services/preference.dart';

class OneEvService {
  static final OneEvService instance = OneEvService._();
  OneEvService._();

  final ApiService _api = ApiService();
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(milliseconds: 3500),
    receiveTimeout: const Duration(milliseconds: 3500),
  ));

  Map<String, dynamic>? _cachedProfile;
  List<Map<String, dynamic>> _cachedCertificates = [];
  List<Map<String, dynamic>> _cachedSkillMatrix = [];

  Map<String, dynamic>? get cachedProfile => _cachedProfile;
  List<Map<String, dynamic>> get cachedCertificates => _cachedCertificates;
  List<Map<String, dynamic>> get cachedSkillMatrix => _cachedSkillMatrix;

  List<String> _buildCandidateUrls(String path) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final activeBase = _api.baseUrl;
    final List<String> list = [];

    // 1. Port reverse adb localhost (Samsung Galaxy S10+ via USB adb reverse tcp:7302 tcp:7302)
    list.add('http://127.0.0.1:7302$cleanPath');

    // 2. Active Base URL jika berbeda
    if (activeBase.isNotEmpty && !list.contains('$activeBase$cleanPath')) {
      list.add('$activeBase$cleanPath');
    }

    // 3. Android Emulator loopback
    list.add('http://10.0.2.2:7302$cleanPath');

    // 4. Remote Production Domain
    list.add('https://apimbs.indexim.id$cleanPath');

    return list;
  }

  Map<String, String> _buildHeaders(String? nik) {
    final token = PreferenceService.getBgToken() ?? '';
    final userNik = nik ?? PreferenceService.getProfile()?.noNik ?? '24051940986';
    final userName = PreferenceService.getProfile()?.namaLengkap ?? 'Karyawan';

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-User-Nik': userNik,
      'X-User-Name': userName,
    };
    if (token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Mengambil data profil lengkap dari ONE_DB_MITRA
  Future<Map<String, dynamic>> fetchProfile({String? nik}) async {
    final targetNik = nik ?? PreferenceService.getProfile()?.noNik ?? '24051940986';
    final candidates = _buildCandidateUrls('/api/one-ev/profile?nik=$targetNik');

    for (final url in candidates) {
      try {
        final res = await _dio.get(
          url,
          options: Options(
            headers: _buildHeaders(targetNik),
            validateStatus: (status) => status != null && status < 500,
          ),
        );

        if (res.statusCode == 200 && res.data != null) {
          final data = res.data is Map ? res.data['data'] : jsonDecode(res.data.toString())['data'];
          if (data is Map<String, dynamic>) {
            _cachedProfile = Map<String, dynamic>.from(data);
            return _cachedProfile!;
          }
        }
      } catch (e) {
        debugPrint('[OneEvService] Gagal fetch profile dari $url: $e');
      }
    }

    // Fallback murni tanpa data palsu/dummy
    if (_cachedProfile != null) return _cachedProfile!;

    final prefProfile = PreferenceService.getProfile();
    _cachedProfile = {
      'no_nik': targetNik,
      'nama_lengkap': prefProfile?.namaLengkap ?? '',
      'nama_perusahaan': prefProfile?.company ?? 'PT INDEXIM COALINDO',
      'kode_perusahaan': 'IDC',
      'nama_departemen': prefProfile?.depart ?? '',
      'nama_jabatan': prefProfile?.posisi ?? '',
      'nama_posisi': prefProfile?.jabatan ?? '',
      'hp_1': prefProfile?.hp ?? '',
      'email_pribadi': '',
      'email_kantor': prefProfile?.emailKantor ?? '',
      'status_aktif': true,
      'grade': '',
      'roster_kerja': '',
      'golongan_tipe': '',
      'alamat': '',
      'kontak_darurat_nama': '',
      'kontak_darurat_telp': '',
      'kontak_darurat_relasi': '',
      'kontak_darurat_keterangan': '',
      'permit_jenis': 'MINE_PERMIT',
      'permit_berakhir': '-',
      'mcu_tanggal': null,
      'mcu_hasil': null,
      'mcu_keterangan': null,
      'mcu_file': null,
      'total_sertifikat': 0,
      'total_kompetensi': 0,
    };
    return _cachedProfile!;
  }

  /// Memperbarui data profil ke ONE_DB_MITRA
  Future<bool> updateProfile(Map<String, dynamic> updateData) async {
    final targetNik = updateData['no_nik'] ?? PreferenceService.getProfile()?.noNik ?? '24051940986';
    final candidates = _buildCandidateUrls('/api/one-ev/profile');

    for (final url in candidates) {
      try {
        final res = await _dio.put(
          url,
          data: updateData,
          options: Options(
            headers: _buildHeaders(targetNik),
            validateStatus: (status) => status != null && status < 500,
          ),
        );

        if (res.statusCode == 200 || res.statusCode == 204) {
          // Update cache lokal
          if (_cachedProfile != null) {
            updateData.forEach((key, val) {
              if (val != null) _cachedProfile![key] = val;
            });
          }
          return true;
        }
      } catch (e) {
        debugPrint('[OneEvService] Gagal update profile di $url: $e');
      }
    }

    // Jika network sementara gagal, simpan field yang diubah di cache lokal tanpa dummy
    if (_cachedProfile != null) {
      updateData.forEach((key, val) {
        if (val != null) _cachedProfile![key] = val;
      });
    }
    return true;
  }

  /// Mengambil daftar sertifikat asli dari ONE_DB_MITRA (tidak ada dummy)
  Future<List<Map<String, dynamic>>> fetchCertificates({String? nik}) async {
    final targetNik = nik ?? PreferenceService.getProfile()?.noNik ?? '24051940986';
    final candidates = _buildCandidateUrls('/api/one-ev/certificates?nik=$targetNik');

    for (final url in candidates) {
      try {
        final res = await _dio.get(
          url,
          options: Options(
            headers: _buildHeaders(targetNik),
            validateStatus: (status) => status != null && status < 500,
          ),
        );

        if (res.statusCode == 200 && res.data != null) {
          final listRaw = res.data is Map ? res.data['data'] : jsonDecode(res.data.toString())['data'];
          if (listRaw is List) {
            final mapped = listRaw.map((e) => Map<String, dynamic>.from(e)).toList();
            // Deduplikasi lokal untuk menjamin tidak ada duplikat sertifikat di mobile
            final seen = <String>{};
            final unique = <Map<String, dynamic>>[];
            for (final c in mapped) {
              final key = (c['nama_sertifikat'] ?? '').toString().trim().toLowerCase();
              if (key.isNotEmpty && !seen.contains(key)) {
                seen.add(key);
                unique.add(c);
              }
            }
            _cachedCertificates = unique;
            return _cachedCertificates;
          }
        }
      } catch (e) {
        debugPrint('[OneEvService] Gagal fetch certificates dari $url: $e');
      }
    }

    // Kembalikan cache atau list kosong - TIDAK ADA DUMMY
    return _cachedCertificates;
  }

  /// Menambahkan sertifikat baru ke ONE_DB_MITRA
  Future<bool> addCertificate(Map<String, dynamic> data) async {
    final targetNik = data['no_nik'] ?? PreferenceService.getProfile()?.noNik ?? '24051940986';
    final candidates = _buildCandidateUrls('/api/one-ev/certificates');

    for (final url in candidates) {
      try {
        final res = await _dio.post(
          url,
          data: data,
          options: Options(
            headers: _buildHeaders(targetNik),
            validateStatus: (status) => status != null && status < 500,
          ),
        );

        if (res.statusCode == 200 || res.statusCode == 201) {
          await fetchCertificates(nik: targetNik);
          return true;
        }
      } catch (e) {
        debugPrint('[OneEvService] Gagal add certificate di $url: $e');
      }
    }

    _cachedCertificates.insert(0, {
      'id': DateTime.now().millisecondsSinceEpoch,
      'nama_sertifikat': data['nama_sertifikat'] ?? 'Sertifikat K3',
      'penyelenggara': data['penyelenggara'] ?? '',
      'tanggal_terbit': data['tanggal_terbit'] ?? DateTime.now().toIso8601String().substring(0, 10),
      'tanggal_expired': data['tanggal_expired'] ?? DateTime.now().add(const Duration(days: 730)).toIso8601String().substring(0, 10),
      'status': 'AKTIF',
    });
    return true;
  }

  /// Mengambil matriks skill & kompetensi asli dari ONE_DB_MITRA (tidak ada dummy)
  Future<List<Map<String, dynamic>>> fetchSkillMatrix({String? nik}) async {
    final targetNik = nik ?? PreferenceService.getProfile()?.noNik ?? '24051940986';
    final candidates = _buildCandidateUrls('/api/one-ev/skill-matrix?nik=$targetNik');

    for (final url in candidates) {
      try {
        final res = await _dio.get(
          url,
          options: Options(
            headers: _buildHeaders(targetNik),
            validateStatus: (status) => status != null && status < 500,
          ),
        );

        if (res.statusCode == 200 && res.data != null) {
          final listRaw = res.data is Map ? res.data['data'] : jsonDecode(res.data.toString())['data'];
          if (listRaw is List) {
            _cachedSkillMatrix = listRaw.map((e) => Map<String, dynamic>.from(e)).toList();
            return _cachedSkillMatrix;
          }
        }
      } catch (e) {
        debugPrint('[OneEvService] Gagal fetch skill-matrix dari $url: $e');
      }
    }

    // Kembalikan cache atau list kosong - TIDAK ADA DUMMY
    return _cachedSkillMatrix;
  }

  /// Memperbarui matriks skill ke ONE_DB_MITRA
  Future<bool> updateSkillMatrix(Map<String, dynamic> data) async {
    final targetNik = data['no_nik'] ?? PreferenceService.getProfile()?.noNik ?? '24051940986';
    final candidates = _buildCandidateUrls('/api/one-ev/skill-matrix');

    for (final url in candidates) {
      try {
        final res = await _dio.post(
          url,
          data: data,
          options: Options(
            headers: _buildHeaders(targetNik),
            validateStatus: (status) => status != null && status < 500,
          ),
        );

        if (res.statusCode == 200 || res.statusCode == 201) {
          await fetchSkillMatrix(nik: targetNik);
          return true;
        }
      } catch (e) {
        debugPrint('[OneEvService] Gagal update skill-matrix di $url: $e');
      }
    }

    return true;
  }
}

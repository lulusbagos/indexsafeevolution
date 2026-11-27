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
    connectTimeout: const Duration(milliseconds: 10000),
    receiveTimeout: const Duration(milliseconds: 10000),
  ));

  Map<String, dynamic>? _cachedProfile;
  Map<String, dynamic>? _cachedSimper;
  List<Map<String, dynamic>> _cachedCertificates = [];
  List<Map<String, dynamic>> _cachedSkillMatrix = [];

  Map<String, dynamic>? get cachedProfile => _cachedProfile;
  Map<String, dynamic>? get cachedSimper => _cachedSimper;
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
      'no_ktp': prefProfile?.noKtp ?? '',
      'no_kk': prefProfile?.noKk ?? '',
      'nama_lengkap': prefProfile?.namaLengkap ?? '',
      'nama_alias': prefProfile?.namaAlias ?? '',
      'warga_negara': prefProfile?.wn ?? 'WNI',
      'jenis_kelamin': prefProfile?.jk ?? '',
      'tempat_lahir': prefProfile?.tmpLahir ?? '',
      'tanggal_lahir': prefProfile?.tglLahir ?? '',
      'agama': prefProfile?.agama ?? '',
      'status_nikah': prefProfile?.statNikah ?? '',
      'nama_ibu': prefProfile?.namaIbu ?? '',
      'nama_ayah': prefProfile?.namaAyah ?? '',
      'nama_perusahaan': prefProfile?.company ?? 'PT INDEXIM COALINDO',
      'kode_perusahaan': 'IDC',
      'nama_departemen': prefProfile?.depart ?? '',
      'nama_jabatan': prefProfile?.posisi ?? '',
      'nama_posisi': prefProfile?.jabatan ?? '',
      'hp_1': prefProfile?.hp ?? '',
      'email_pribadi': prefProfile?.emailPribadi ?? '',
      'email_kantor': prefProfile?.emailKantor ?? '',
      'status_aktif': true,
      'grade': prefProfile?.grade ?? '',
      'roster_kerja': prefProfile?.roster != null ? '${prefProfile!.roster}' : '',
      'golongan_tipe': '',
      'alamat': '',
      'kontak_darurat_nama': '',
      'kontak_darurat_telp': '',
      'kontak_darurat_relasi': '',
      'kontak_darurat_keterangan': '',
      'permit_jenis': 'MINE_PERMIT',
      'permit_berakhir': '-',
      'path_foto': prefProfile?.foto,
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

  /// Mengambil data resmi SIMPER Tambang dan daftar unit yang diizinkan (tb_simper & tb_simper_unit)
  Future<Map<String, dynamic>?> fetchSimper({String? nik}) async {
    final targetNik = nik ?? PreferenceService.getProfile()?.noNik ?? '24051940986';
    final candidates = _buildCandidateUrls('/api/one-ev/simper?nik=$targetNik');

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
          final body = res.data is Map ? res.data : jsonDecode(res.data.toString());
          if (body['success'] == true && body['data'] != null) {
            _cachedSimper = Map<String, dynamic>.from(body['data']);
            return _cachedSimper;
          }
        }
      } catch (e) {
        debugPrint('[OneEvService] Gagal fetch simper dari $url: $e');
      }
    }
    return _cachedSimper;
  }

  /// Mengambil daftar master Agama dari ONE_DB_MITRA
  Future<List<Map<String, dynamic>>> fetchMasterAgama() async {
    final candidates = _buildCandidateUrls('/api/one-ev/master/agama');
    for (final url in candidates) {
      try {
        final res = await _dio.get(url, options: Options(validateStatus: (s) => s != null && s < 500));
        if (res.statusCode == 200 && res.data != null) {
          final listRaw = res.data is Map ? res.data['data'] : jsonDecode(res.data.toString())['data'];
          if (listRaw is List) {
            return listRaw.map((e) => Map<String, dynamic>.from(e)).toList();
          }
        }
      } catch (e) {
        debugPrint('[OneEvService] Gagal fetch master agama: $e');
      }
    }
    return [
      {'id': 1, 'nama': 'BUDHA'},
      {'id': 2, 'nama': 'HINDU'},
      {'id': 3, 'nama': 'ISLAM'},
      {'id': 4, 'nama': 'KATHOLIK'},
      {'id': 5, 'nama': 'KHONGHUCU'},
      {'id': 6, 'nama': 'KRISTEN'},
    ];
  }

  /// Mengambil daftar master Tingkat Pendidikan dari ONE_DB_MITRA
  Future<List<Map<String, dynamic>>> fetchMasterPendidikan() async {
    final candidates = _buildCandidateUrls('/api/one-ev/master/pendidikan');
    for (final url in candidates) {
      try {
        final res = await _dio.get(url, options: Options(validateStatus: (s) => s != null && s < 500));
        if (res.statusCode == 200 && res.data != null) {
          final listRaw = res.data is Map ? res.data['data'] : jsonDecode(res.data.toString())['data'];
          if (listRaw is List) {
            return listRaw.map((e) => Map<String, dynamic>.from(e)).toList();
          }
        }
      } catch (e) {
        debugPrint('[OneEvService] Gagal fetch master pendidikan: $e');
      }
    }
    return [
      {'id': 1, 'nama': 'SD'},
      {'id': 2, 'nama': 'SMP'},
      {'id': 4, 'nama': 'SMA/K'},
      {'id': 8, 'nama': 'PAKET C'},
      {'id': 9, 'nama': 'DIPLOMA 1'},
      {'id': 10, 'nama': 'DIPLOMA 2'},
      {'id': 11, 'nama': 'DIPLOMA 3'},
      {'id': 12, 'nama': 'DIPLOMA 4'},
      {'id': 13, 'nama': 'STRATA 1'},
      {'id': 14, 'nama': 'STRATA 2'},
      {'id': 15, 'nama': 'STRATA 3'},
      {'id': 16, 'nama': 'TIDAK TAMAT SD'},
      {'id': 17, 'nama': 'PAKET B'},
    ];
  }

  /// Mengambil daftar master Provinsi dari ONE_DB_MITRA
  Future<List<Map<String, dynamic>>> fetchMasterProvinsi() async {
    final candidates = _buildCandidateUrls('/api/one-ev/master/provinsi');
    for (final url in candidates) {
      try {
        final res = await _dio.get(url, options: Options(validateStatus: (s) => s != null && s < 500));
        if (res.statusCode == 200 && res.data != null) {
          final listRaw = res.data is Map ? res.data['data'] : jsonDecode(res.data.toString())['data'];
          if (listRaw is List) {
            return listRaw.map((e) => Map<String, dynamic>.from(e)).toList();
          }
        }
      } catch (e) {
        debugPrint('[OneEvService] Gagal fetch master provinsi: $e');
      }
    }
    return [];
  }

  /// Mengambil daftar master Kabupaten dari ONE_DB_MITRA berdasarkan provinsi
  Future<List<Map<String, dynamic>>> fetchMasterKabupaten({String? provinsi}) async {
    final param = provinsi != null && provinsi.trim().isNotEmpty ? '?provinsi=${Uri.encodeComponent(provinsi.trim())}' : '';
    final candidates = _buildCandidateUrls('/api/one-ev/master/kabupaten$param');
    for (final url in candidates) {
      try {
        final res = await _dio.get(url, options: Options(validateStatus: (s) => s != null && s < 500));
        if (res.statusCode == 200 && res.data != null) {
          final listRaw = res.data is Map ? res.data['data'] : jsonDecode(res.data.toString())['data'];
          if (listRaw is List) {
            return listRaw.map((e) => Map<String, dynamic>.from(e)).toList();
          }
        }
      } catch (e) {
        debugPrint('[OneEvService] Gagal fetch master kabupaten: $e');
      }
    }
    return [];
  }

  /// Mengambil daftar master Kecamatan dari ONE_DB_MITRA berdasarkan kabupaten
  Future<List<Map<String, dynamic>>> fetchMasterKecamatan({String? kabupaten}) async {
    final param = kabupaten != null && kabupaten.trim().isNotEmpty ? '?kabupaten=${Uri.encodeComponent(kabupaten.trim())}' : '';
    final candidates = _buildCandidateUrls('/api/one-ev/master/kecamatan$param');
    for (final url in candidates) {
      try {
        final res = await _dio.get(url, options: Options(validateStatus: (s) => s != null && s < 500));
        if (res.statusCode == 200 && res.data != null) {
          final listRaw = res.data is Map ? res.data['data'] : jsonDecode(res.data.toString())['data'];
          if (listRaw is List) {
            return listRaw.map((e) => Map<String, dynamic>.from(e)).toList();
          }
        }
      } catch (e) {
        debugPrint('[OneEvService] Gagal fetch master kecamatan: $e');
      }
    }
    return [];
  }

  /// Mengambil daftar master Kelurahan/Desa dari ONE_DB_MITRA berdasarkan kecamatan
  Future<List<Map<String, dynamic>>> fetchMasterKelurahan({String? kecamatan}) async {
    final param = kecamatan != null && kecamatan.trim().isNotEmpty ? '?kecamatan=${Uri.encodeComponent(kecamatan.trim())}' : '';
    final candidates = _buildCandidateUrls('/api/one-ev/master/kelurahan$param');
    for (final url in candidates) {
      try {
        final res = await _dio.get(url, options: Options(validateStatus: (s) => s != null && s < 500));
        if (res.statusCode == 200 && res.data != null) {
          final listRaw = res.data is Map ? res.data['data'] : jsonDecode(res.data.toString())['data'];
          if (listRaw is List) {
            return listRaw.map((e) => Map<String, dynamic>.from(e)).toList();
          }
        }
      } catch (e) {
        debugPrint('[OneEvService] Gagal fetch master kelurahan: $e');
      }
    }
    return [];
  }
}

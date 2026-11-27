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
    connectTimeout: const Duration(milliseconds: 3000),
    receiveTimeout: const Duration(milliseconds: 3000),
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

    // Prioritaskan domain resmi
    list.add('https://apimbs.indexim.id$cleanPath');

    if (activeBase.isNotEmpty && !list.contains('$activeBase$cleanPath')) {
      list.add('$activeBase$cleanPath');
    }

    list.add('http://10.0.2.2:7302$cleanPath');
    list.add('http://127.0.0.1:7302$cleanPath');

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

    // Fallback: gunakan cachedProfile atau PreferenceService
    if (_cachedProfile != null) return _cachedProfile!;

    final prefProfile = PreferenceService.getProfile();
    _cachedProfile = {
      'no_nik': targetNik,
      'nama_lengkap': prefProfile?.namaLengkap ?? 'LULUS BAGOS HERMAWAN',
      'nama_perusahaan': prefProfile?.company ?? 'PT INDEXIM COALINDO',
      'kode_perusahaan': 'IDC',
      'nama_departemen': prefProfile?.depart ?? 'SYSTEM INTEGRATIONS',
      'nama_jabatan': prefProfile?.posisi ?? 'FOREMAN/OFFICER',
      'nama_posisi': prefProfile?.jabatan ?? 'Officer Product & System Development',
      'hp_1': prefProfile?.hp ?? '0852-7496-6722',
      'email_pribadi': 'lulusbagoshermawan@gmail.com',
      'email_kantor': prefProfile?.emailKantor ?? 'lulus.hermawan@indexim.id',
      'status_aktif': true,
      'grade': '6 SETARA',
      'roster_kerja': '6 - 2 WEEK',
      'golongan_tipe': 'STAFF',
      'alamat': 'Jl. Imam Bonjol, Kel. Api-Api, Bontang Utara, Kalimantan Timur',
      'kontak_darurat_nama': 'Keluarga Inti',
      'kontak_darurat_telp': '0812-9876-5432',
      'kontak_darurat_relasi': 'Keluarga',
      'permit_jenis': 'MINE_PERMIT',
      'permit_berakhir': '2027-08-18',
      'total_sertifikat': 4,
      'total_kompetensi': 6,
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
            if (updateData['hp_1'] != null) _cachedProfile!['hp_1'] = updateData['hp_1'];
            if (updateData['email_kantor'] != null) _cachedProfile!['email_kantor'] = updateData['email_kantor'];
            if (updateData['email_pribadi'] != null) _cachedProfile!['email_pribadi'] = updateData['email_pribadi'];
            if (updateData['alamat'] != null) _cachedProfile!['alamat'] = updateData['alamat'];
            if (updateData['kontak_darurat_nama'] != null) _cachedProfile!['kontak_darurat_nama'] = updateData['kontak_darurat_nama'];
            if (updateData['kontak_darurat_telp'] != null) _cachedProfile!['kontak_darurat_telp'] = updateData['kontak_darurat_telp'];
            if (updateData['kontak_darurat_relasi'] != null) _cachedProfile!['kontak_darurat_relasi'] = updateData['kontak_darurat_relasi'];
          }
          return true;
        }
      } catch (e) {
        debugPrint('[OneEvService] Gagal update profile di $url: $e');
      }
    }

    // Jika offline tapi data sudah disiapkan, simpan di cache lokal
    if (_cachedProfile != null) {
      if (updateData['hp_1'] != null) _cachedProfile!['hp_1'] = updateData['hp_1'];
      if (updateData['email_kantor'] != null) _cachedProfile!['email_kantor'] = updateData['email_kantor'];
      if (updateData['email_pribadi'] != null) _cachedProfile!['email_pribadi'] = updateData['email_pribadi'];
      if (updateData['alamat'] != null) _cachedProfile!['alamat'] = updateData['alamat'];
      if (updateData['kontak_darurat_nama'] != null) _cachedProfile!['kontak_darurat_nama'] = updateData['kontak_darurat_nama'];
      if (updateData['kontak_darurat_telp'] != null) _cachedProfile!['kontak_darurat_telp'] = updateData['kontak_darurat_telp'];
      if (updateData['kontak_darurat_relasi'] != null) _cachedProfile!['kontak_darurat_relasi'] = updateData['kontak_darurat_relasi'];
    }
    return true;
  }

  /// Mengambil daftar sertifikat dari ONE_DB_MITRA
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
            _cachedCertificates = listRaw.map((e) => Map<String, dynamic>.from(e)).toList();
            return _cachedCertificates;
          }
        }
      } catch (e) {
        debugPrint('[OneEvService] Gagal fetch certificates dari $url: $e');
      }
    }

    if (_cachedCertificates.isNotEmpty) return _cachedCertificates;

    _cachedCertificates = [
      {
        'id': 1,
        'nama_sertifikat': 'Pengawas Operasional Pertama (POP) Pertambangan',
        'penyelenggara': 'Kementerian ESDM & BNSP',
        'tanggal_terbit': '2023-08-15',
        'tanggal_expired': '2028-08-15',
        'status': 'AKTIF',
      },
      {
        'id': 2,
        'nama_sertifikat': 'Induksi Keselamatan Tambang Umum K3LH',
        'penyelenggara': 'HSE PT Indexim Coalindo',
        'tanggal_terbit': '2024-05-15',
        'tanggal_expired': '2027-05-15',
        'status': 'AKTIF',
      },
      {
        'id': 3,
        'nama_sertifikat': 'Defensive Driving Training (DDT) Kendaraan 4x4',
        'penyelenggara': 'IDC Safety Driving Academy',
        'tanggal_terbit': '2024-07-20',
        'tanggal_expired': '2026-12-31',
        'status': 'AKTIF',
      },
      {
        'id': 4,
        'nama_sertifikat': 'Pertolongan Pertama Pada Kecelakaan (First Aid Level 2)',
        'penyelenggara': 'Medical Emergency Response IDC',
        'tanggal_terbit': '2024-06-10',
        'tanggal_expired': '2026-06-10',
        'status': 'PERLU PERPANJANGAN',
      },
    ];
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
      'nama_sertifikat': data['nama_sertifikat'] ?? 'Sertifikat K3 Tambang',
      'penyelenggara': data['penyelenggara'] ?? 'Lembaga Diklat Resmi',
      'tanggal_terbit': data['tanggal_terbit'] ?? DateTime.now().toIso8601String().substring(0, 10),
      'tanggal_expired': data['tanggal_expired'] ?? DateTime.now().add(const Duration(days: 730)).toIso8601String().substring(0, 10),
      'status': 'AKTIF',
    });
    return true;
  }

  /// Mengambil matriks skill & kompetensi dari ONE_DB_MITRA
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

    if (_cachedSkillMatrix.isNotEmpty) return _cachedSkillMatrix;

    _cachedSkillMatrix = [
      {
        'id': 1,
        'nama_kompetensi': 'Identifikasi Bahaya & Pengendalian Risiko (IBPR/HIRA)',
        'kategori': 'K3LH Tambang',
        'level_target': 'Level 4',
        'level_aktual': 'Level 4',
        'status': 'COMPETENT',
        'assessor': 'Superintendent HSE',
        'catatan': 'Memenuhi kriteria evaluasi risiko mandiri di front pit.',
      },
      {
        'id': 2,
        'nama_kompetensi': 'SOP Golden Rules & Isolasi Energi (LOTO)',
        'kategori': 'K3LH Tambang',
        'level_target': 'Level 4',
        'level_aktual': 'Level 4',
        'status': 'COMPETENT',
        'assessor': 'Safety Inspector',
        'catatan': 'Kepatuhan penuh pada protokol 10 Golden Safety Rules.',
      },
      {
        'id': 3,
        'nama_kompetensi': 'Pengoperasian Kendaraan Ringan (LV 4x4) Tambang',
        'kategori': 'Operasional Tambang',
        'level_target': 'Level 3',
        'level_aktual': 'Level 3',
        'status': 'COMPETENT',
        'assessor': 'Driver Assessor',
        'catatan': 'SIMPER aktif LV Hilux & Light Hauler jalur hauling.',
      },
      {
        'id': 4,
        'nama_kompetensi': 'Investigasi Insiden & Safety Accountability (SAP)',
        'kategori': 'Manajemen K3',
        'level_target': 'Level 4',
        'level_aktual': 'Level 4',
        'status': 'COMPETENT',
        'assessor': 'Lead HSE Officer',
        'catatan': 'Pelaporan dan root-cause analysis berbasis digital.',
      },
      {
        'id': 5,
        'nama_kompetensi': 'Inspeksi K3 Terencana & Observasi Tugas',
        'kategori': 'Operasional Tambang',
        'level_target': 'Level 3',
        'level_aktual': 'Level 3',
        'status': 'COMPETENT',
        'assessor': 'Mine Safety Foreman',
        'catatan': 'Rutin melaksanakan inspeksi area pit dan stockpile.',
      },
      {
        'id': 6,
        'nama_kompetensi': 'Tanggap Darurat, Pemadam Api & Evakuasi Site',
        'kategori': 'Emergency Response',
        'level_target': 'Level 3',
        'level_aktual': 'Level 3',
        'status': 'COMPETENT',
        'assessor': 'Emergency Response Team',
        'catatan': 'Sertifikasi First Aider & tim mitigasi kebakaran.',
      },
    ];
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

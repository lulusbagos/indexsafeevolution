import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../models/coaching_detail_model.dart';
import '../../services/api.dart';
import '../../services/database.dart';
import '../../services/offline_sync_service.dart';
import '../../services/preference.dart';
import '../../services/sync.dart';
import '../../utils/helpers.dart';
import '../../widgets/sap_form_widgets.dart';
import '../../widgets/top_bar.dart';

const _coachPurple = Color(0xFF9333EA);
const _coachDark = Color(0xFF0F172A);

class CoachingFormPage extends StatefulWidget {
  const CoachingFormPage({super.key, this.existingId});

  final int? existingId;

  @override
  State<CoachingFormPage> createState() => _CoachingFormPageState();
}

class _CoachingFormPageState extends State<CoachingFormPage> {
  final _scrollCtrl = ScrollController();
  final _db = DatabaseService();
  final _api = ApiService();
  final _profile = PreferenceService.getProfile();

  final _locationDetail = TextEditingController();
  final _title = TextEditingController(); // Komitmen bersama
  final _feedback = TextEditingController(); // Umpan balik
  final _traineeQuery = TextEditingController();

  DateTime? _date = DateTime.now();
  String? _time = DateFormat('HH:mm').format(DateTime.now());

  String? _area;
  String? _benchmark;
  String? _tema = 'Pembinaan';

  String? _image;
  String? _existingImageUrl;

  final List<String> _areasList = [];
  final List<String> _benchmarksList = [];
  final List<String> _temasList = [
    'Pembinaan',
    'Sosialisasi',
    'Sharing Knowledge',
    'K3 Operasional',
    'Bimbingan Teknis & SOP',
    'Evaluasi Kepatuhan APD',
  ];

  final List<Map<String, dynamic>> _traineeResults = [];
  final List<Map<String, dynamic>> _selectedTrainees = [];

  bool _isSaving = false;
  bool _isLoadingExisting = false;
  bool _isLoadingAreas = false;
  bool _isLoadingBenchmarks = false;
  bool _isSearchingTrainees = false;
  int? _localId;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _locationDetail.dispose();
    _title.dispose();
    _feedback.dispose();
    _traineeQuery.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    _fillGpsFromDevice(silent: true);
    await _loadAreas();
    await _loadTemas();

    if (widget.existingId != null) {
      await _loadExistingData(widget.existingId!);
    }
  }

  Future<void> _loadExistingData(int id) async {
    setState(() => _isLoadingExisting = true);
    try {
      final rows = await _db.rawQuery('SELECT * FROM coaching_trans WHERE id = ? LIMIT 1', [id]);
      if (rows.isNotEmpty) {
        final row = rows.first;
        _localId = row['id'] as int?;
        _date = DateTime.tryParse(row['date']?.toString() ?? '') ?? DateTime.now();
        _time = row['time']?.toString() ?? DateFormat('HH:mm').format(DateTime.now());
        _area = row['area']?.toString() ?? row['area_name']?.toString();
        _benchmark = row['lokasi']?.toString() ?? row['location_name']?.toString();
        _locationDetail.text = row['detil_lokasi']?.toString() ?? row['location_detail']?.toString() ?? '';
        _tema = row['tema']?.toString() ?? row['purpose']?.toString() ?? row['title']?.toString() ?? 'Pembinaan';
        _title.text = row['komitmen']?.toString() ?? row['title']?.toString() ?? '';
        _feedback.text = row['feedback']?.toString() ?? row['remark']?.toString() ?? '';

        final img = row['image']?.toString() ?? row['foto']?.toString();
        if (img != null && img.isNotEmpty) {
          if (File(img).existsSync()) {
            _image = img;
          } else {
            _existingImageUrl = img;
          }
        }

        if (_area != null && _area!.isNotEmpty) {
          await _loadBenchmarks(_area!);
        }

        // Load participants from coaching_details
        final details = await _db.rawQuery(
          'SELECT * FROM coaching_details WHERE tran_id = ? AND deleted_at IS NULL ORDER BY id ASC',
          [id],
        );
        _selectedTrainees.clear();
        for (final d in details) {
          final rawName = d['name']?.toString() ?? '';
          var nik = d['no_nik']?.toString() ?? d['nik']?.toString() ?? '';
          var nama = d['nama_lengkap']?.toString() ?? d['nama']?.toString() ?? '';
          if (nik.isEmpty && rawName.contains('-')) {
            final parts = rawName.split('-');
            nik = parts[0].trim();
            nama = parts.length > 1 ? parts.sublist(1).join('-').trim() : nik;
          } else if (nama.isEmpty) {
            nama = rawName;
          }
          _selectedTrainees.add({
            'no_nik': nik,
            'nik': nik,
            'nama_lengkap': nama,
            'nama': nama,
            'posisi': d['posisi']?.toString() ?? d['remark']?.toString() ?? '',
            'departemen': d['departemen']?.toString() ?? '',
            'perusahaan': d['perusahaan']?.toString() ?? '',
          });
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingExisting = false);
  }

  Future<void> _loadAreas() async {
    setState(() => _isLoadingAreas = true);
    final companyId = _profile?.companyId ?? 1;
    final set = <String>{};

    try {
      final sqldb = await _db.database;

      // Ensure tbl_m_benchmark exists
      await sqldb.execute('''
        CREATE TABLE IF NOT EXISTS tbl_m_benchmark (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          perusahaan_id INTEGER,
          area_utama TEXT,
          nama_benchmark TEXT,
          created_by_nik TEXT,
          created_by_name TEXT,
          created_at TEXT
        )
      ''');

      // 1. Baca dari tbl_m_benchmark lokal
      final rows = await sqldb.rawQuery(
        "SELECT DISTINCT area_utama FROM tbl_m_benchmark WHERE area_utama IS NOT NULL AND TRIM(area_utama) != '' AND area_utama NOT LIKE '%CAMP EKSPLORASI%' ORDER BY area_utama",
      );
      for (var r in rows) {
        final val = r['area_utama']?.toString().trim();
        if (val != null && val.isNotEmpty) set.add(val);
      }

      // 2. Fallback dari locations table jika kosong
      if (set.isEmpty) {
        try {
          final locRows = await sqldb.rawQuery(
            "SELECT DISTINCT area FROM locations WHERE area IS NOT NULL AND TRIM(area) != '' ORDER BY area",
          );
          for (var r in locRows) {
            final val = r['area']?.toString().trim();
            if (val != null && val.isNotEmpty) set.add(val);
          }
        } catch (_) {}
      }

      // 3. Fallback dari enum_masters
      if (set.isEmpty) {
        try {
          final enumRows = await sqldb.rawQuery(
            "SELECT DISTINCT name FROM enum_masters WHERE deleted_at IS NULL AND type = 'area' ORDER BY name",
          );
          for (var r in enumRows) {
            final val = r['name']?.toString().trim();
            if (val != null && val.isNotEmpty) set.add(val);
          }
        } catch (_) {}
      }

      if (mounted && set.isNotEmpty) {
        setState(() {
          _areasList
            ..clear()
            ..addAll(set)
            ..sort();
        });
      }

      // 4. Remote refresh dari server API jika online
      final serverAreas = await _api.getMasterAreas(perusahaanId: companyId);
      if (serverAreas.isNotEmpty) {
        for (final a in serverAreas) {
          final val = a.trim();
          if (val.isNotEmpty && !val.toUpperCase().contains('CAMP EKSPLORASI')) {
            set.add(val);
          }
        }
        if (mounted) {
          setState(() {
            _areasList
              ..clear()
              ..addAll(set)
              ..sort();
          });
        }
        // Cache ke SQLite
        final batch = sqldb.batch();
        for (final a in serverAreas) {
          batch.rawInsert(
            '''INSERT OR IGNORE INTO tbl_m_benchmark (perusahaan_id, area_utama, nama_benchmark, created_at)
               VALUES (?, ?, '', ?)''',
            [companyId, a.trim(), DateTime.now().toIso8601String()],
          );
        }
        await batch.commit(noResult: true);
      } else if (set.isEmpty) {
        // Coba dari SafetyTalk master bila masih kosong
        final stData = await _api.getSafetyTalkData();
        if (stData != null && stData['areas'] is List) {
          for (var item in (stData['areas'] as List)) {
            final name = item['name']?.toString().trim();
            if (name != null && name.isNotEmpty) set.add(name);
          }
          if (mounted && set.isNotEmpty) {
            setState(() {
              _areasList
                ..clear()
                ..addAll(set)
                ..sort();
            });
          }
        }
      }
    } catch (e) {
      debugPrint('[CoachingForm] Load areas error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingAreas = false);
    }

    // Baseline fallback if completely empty
    if (_areasList.isEmpty) {
      if (mounted) {
        setState(() {
          _areasList.addAll([
            'PIT TAMBANG',
            'WORKSHOP & HEAVY EQUIPMENT',
            'PORT & JETTY CONVEYOR',
            'HAULING ROAD & ROM',
            'OFFICE & CAMP',
            'PROCESSING PLANT / CPP',
            'EXPLORATION & DRILLING',
          ]);
        });
      }
    }
  }

  Future<void> _loadBenchmarks(String area) async {
    final cleanArea = area.trim();
    if (cleanArea.isEmpty) {
      if (mounted) {
        setState(() {
          _benchmarksList.clear();
          _isLoadingBenchmarks = false;
        });
      }
      return;
    }

    setState(() => _isLoadingBenchmarks = true);
    final companyId = _profile?.companyId ?? 1;
    final set = <String>{};

    try {
      final sqldb = await _db.database;

      // 1. Baca cache SQLite lokal dari tbl_m_benchmark
      final localRows = await sqldb.rawQuery(
        "SELECT DISTINCT nama_benchmark FROM tbl_m_benchmark WHERE (LOWER(TRIM(area_utama)) = ? OR area_utama = ?) AND nama_benchmark IS NOT NULL AND TRIM(nama_benchmark) != '' ORDER BY nama_benchmark",
        [cleanArea.toLowerCase(), cleanArea],
      );
      for (var r in localRows) {
        final val = r['nama_benchmark']?.toString().trim();
        if (val != null && val.isNotEmpty) set.add(val);
      }

      // 2. Fallback ke tabel locations jika kosong
      if (set.isEmpty) {
        try {
          final locRows = await sqldb.rawQuery(
            "SELECT DISTINCT name FROM locations WHERE LOWER(TRIM(area)) = ? AND name IS NOT NULL AND TRIM(name) != '' ORDER BY name",
            [cleanArea.toLowerCase()],
          );
          for (var r in locRows) {
            final val = r['name']?.toString().trim();
            if (val != null && val.isNotEmpty) set.add(val);
          }
        } catch (_) {}
      }

      if (mounted && set.isNotEmpty) {
        setState(() {
          _benchmarksList
            ..clear()
            ..addAll(set)
            ..sort();
        });
      }

      // 3. Ambil dari server API
      final serverBenchmarks = await _api.getBenchmarks(cleanArea, perusahaanId: companyId);
      if (serverBenchmarks.isNotEmpty) {
        for (final b in serverBenchmarks) {
          final val = b.trim();
          if (val.isNotEmpty) set.add(val);
        }
      }

      // Fallback ke MBS SafetyTalk benchmark jika server API kosong
      if (serverBenchmarks.isEmpty) {
        final mbsBenchmarks = await _api.getSafetyTalkBenchmarks(cleanArea);
        for (final b in mbsBenchmarks) {
          final val = b.trim();
          if (val.isNotEmpty) set.add(val);
        }
      }

      if (mounted) {
        setState(() {
          _benchmarksList
            ..clear()
            ..addAll(set)
            ..sort();
        });
      }

      // 4. Simpan ke SQLite tbl_m_benchmark untuk offline caching
      if (set.isNotEmpty) {
        final batch = sqldb.batch();
        for (final b in set) {
          batch.rawInsert(
            '''INSERT OR IGNORE INTO tbl_m_benchmark (perusahaan_id, area_utama, nama_benchmark, created_at)
               VALUES (?, ?, ?, ?)''',
            [companyId, cleanArea, b, DateTime.now().toIso8601String()],
          );
        }
        await batch.commit(noResult: true);
      }
    } catch (e) {
      debugPrint('[CoachingForm] Load benchmarks error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingBenchmarks = false);
    }
  }

  Future<void> _loadTemas() async {
    try {
      final rows = await _db.rawQuery(
        '''SELECT id, "name" as tema_name FROM coaching_masters 
           WHERE deleted_at IS NULL ORDER BY "name"''',
      );
      if (rows.isNotEmpty) {
        final set = <String>{};
        for (var r in rows) {
          final t = r['tema_name']?.toString().trim();
          if (t != null && t.isNotEmpty) set.add(t);
        }
        if (mounted && set.isNotEmpty) {
          setState(() {
            for (var item in set) {
              if (!_temasList.contains(item)) _temasList.add(item);
            }
          });
        }
      }
    } catch (_) {}
  }

  // SEARCH PARTICIPANTS DIRECTLY BY NIK OR NAME (NO COMPANY RESTRICTION)
  Future<void> _searchTrainees(String value) async {
    final query = value.trim();
    if (query.length < 2) {
      if (mounted) setState(() => _traineeResults.clear());
      return;
    }

    setState(() => _isSearchingTrainees = true);

    final combinedResults = <Map<String, dynamic>>[];
    final seenNiks = <String>{};

    // 1. Remote MBS Search (Cross Company / Lintas Perusahaan)
    try {
      final remoteRows = await _api.searchCoachingEmployees(query);
      if (remoteRows != null) {
        for (final r in remoteRows) {
          final nik = r['no_nik']?.toString().trim() ?? '';
          if (nik.isNotEmpty && seenNiks.add(nik.toLowerCase())) {
            combinedResults.add(r);
          }
        }
      }
    } catch (_) {}

    // 2. Local SQLite Search (Cross Company / Lintas Perusahaan)
    try {
      final escaped = query.replaceAll("'", "''").toLowerCase();
      final rows = await _db.rawQuery(
        '''SELECT e.id, e.no_nik, e.nama_lengkap, e.posisi, e.departemen, e.perusahaan
           FROM employees e 
           WHERE e.deleted_at IS NULL
             AND (LOWER(e.no_nik) LIKE '%$escaped%' OR LOWER(e.nama_lengkap) LIKE '%$escaped%')
           ORDER BY e.no_nik LIMIT 25''',
      );
      for (final r in rows) {
        final map = Map<String, dynamic>.from(r);
        final nik = map['no_nik']?.toString().trim() ?? '';
        if (nik.isNotEmpty && seenNiks.add(nik.toLowerCase())) {
          combinedResults.add(map);
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _traineeResults
          ..clear()
          ..addAll(combinedResults);
        _isSearchingTrainees = false;
      });
    }
  }

  void _addTrainee(Map<String, dynamic> trainee) {
    final nik = trainee['no_nik']?.toString().trim() ?? trainee['nik']?.toString().trim() ?? '';
    final nama = trainee['nama_lengkap']?.toString().trim() ?? trainee['nama']?.toString().trim() ?? '';

    final alreadyExists = _selectedTrainees.any((item) {
      final curNik = (item['no_nik'] ?? item['nik'] ?? '').toString().trim();
      final curNama = (item['nama_lengkap'] ?? item['nama'] ?? '').toString().trim();
      return (nik.isNotEmpty && curNik.toLowerCase() == nik.toLowerCase()) ||
          (nama.isNotEmpty && curNama.toLowerCase() == nama.toLowerCase());
    });

    if (alreadyExists) {
      _showWarning('Peserta "$nama" ($nik) sudah ada dalam daftar.');
      return;
    }

    setState(() {
      _selectedTrainees.add(trainee);
      _traineeResults.clear();
      _traineeQuery.clear();
    });
  }

  void _addManualTrainee(String query) {
    final clean = query.trim().toUpperCase();
    if (clean.isEmpty) return;

    final trainee = <String, dynamic>{
      'no_nik': clean,
      'nik': clean,
      'nama_lengkap': clean,
      'nama': clean,
      'posisi': 'Peserta Coaching',
      'departemen': 'Operasional',
      'perusahaan': 'Kontraktor/Karyawan',
    };

    _addTrainee(trainee);
  }

  void _removeTrainee(int index) {
    setState(() => _selectedTrainees.removeAt(index));
  }

  void _showWarning(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Color(0xFFD97706)),
            SizedBox(width: 8),
            Text('Perhatian', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _coachPurple),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  void _fillGpsFromDevice({bool silent = false}) {
    fillGpsCoordinate(
      context,
      _locationDetail,
      () => setState(() {}),
      silent: silent,
    );
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: _coachPurple),
                title: const Text('Kamera', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF16A34A)),
                title: const Text('Galeri', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;
    final file = await pickImage(source: source);
    if (file != null && mounted) {
      setState(() => _image = file.path);
    }
  }

  void _previewImage({
    required String? localPath,
    required String? remoteUrl,
    required String title,
  }) {
    final hasLocal = localPath != null && localPath.isNotEmpty;
    final hasRemote = remoteUrl != null && remoteUrl.isNotEmpty;
    if (!hasLocal && !hasRemote) return;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                child: hasLocal
                    ? Image.file(File(localPath), fit: BoxFit.contain)
                    : Image.network(
                        remoteUrl!.startsWith('http') ? remoteUrl : '${_api.dio.options.baseUrl}$remoteUrl',
                        fit: BoxFit.contain,
                      ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // BOTTOM SHEET MODAL PICKER UNTUK AREA UTAMA
  void _showAreaPickerModal() {
    String filter = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final query = filter.trim().toLowerCase();
          final filtered = _areasList.where((a) => a.toLowerCase().contains(query)).toList();
          final canAddCustom = filter.trim().isNotEmpty &&
              !_areasList.any((a) => a.trim().toLowerCase() == filter.trim().toLowerCase());

          return DraggableScrollableSheet(
            initialChildSize: 0.75,
            maxChildSize: 0.92,
            minChildSize: 0.45,
            expand: false,
            builder: (_, scrollCtrl) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Pilih Area Utama',
                        style: TextStyle(
                          color: _coachDark,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(modalCtx),
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      onChanged: (val) => setModalState(() => filter = val),
                      style: const TextStyle(fontSize: 14, color: _coachDark),
                      decoration: InputDecoration(
                        hintText: 'Ketik untuk mencari atau menambah area...',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                        suffixIcon: filter.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () => setModalState(() => filter = ''),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                if (canAddCustom)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: InkWell(
                      onTap: () async {
                        final newArea = filter.trim().toUpperCase();
                        Navigator.pop(modalCtx);
                        setState(() {
                          if (!_areasList.contains(newArea)) {
                            _areasList.add(newArea);
                            _areasList.sort();
                          }
                          _area = newArea;
                          _benchmark = null;
                        });
                        _loadBenchmarks(newArea);
                        try {
                          final sqldb = await _db.database;
                          await sqldb.rawInsert(
                            '''INSERT OR IGNORE INTO tbl_m_benchmark (perusahaan_id, area_utama, nama_benchmark, created_at)
                               VALUES (?, ?, '', ?)''',
                            [_profile?.companyId ?? 1, newArea, DateTime.now().toIso8601String()],
                          );
                        } catch (_) {}
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF5FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE9D5FF)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _coachPurple,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.add, color: Colors.white, size: 16),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Gunakan Area Baru:',
                                    style: TextStyle(color: _coachPurple, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    '"${filter.trim().toUpperCase()}"',
                                    style: const TextStyle(
                                      color: _coachDark,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, color: _coachPurple, size: 14),
                          ],
                        ),
                      ),
                    ),
                  ),

                Expanded(
                  child: _isLoadingAreas && _areasList.isEmpty
                      ? const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: _coachPurple),
                          ),
                        )
                      : filtered.isEmpty && !canAddCustom
                          ? const Center(
                              child: Text('Area tidak ditemukan', style: TextStyle(color: Color(0xFF94A3B8))),
                            )
                          : ListView.separated(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            final isSelected = item == _area;
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              title: Text(
                                item,
                                style: TextStyle(
                                  color: isSelected ? _coachPurple : _coachDark,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 14,
                                ),
                              ),
                              trailing: isSelected
                                  ? const Icon(Icons.check_circle_rounded, color: _coachPurple, size: 20)
                                  : null,
                              onTap: () {
                                Navigator.pop(modalCtx);
                                setState(() {
                                  _area = item;
                                  _benchmark = null;
                                });
                                _loadBenchmarks(item);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // BOTTOM SHEET MODAL PICKER UNTUK BENCHMARK
  void _showBenchmarkPickerModal() {
    if (_area == null || _area!.isEmpty) {
      _showWarning('Pilih Area Utama terlebih dahulu.');
      return;
    }

    String filter = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final query = filter.trim().toLowerCase();
          final filtered = _benchmarksList.where((b) => b.toLowerCase().contains(query)).toList();
          final canAddCustom = filter.trim().isNotEmpty &&
              !_benchmarksList.any((b) => b.trim().toLowerCase() == filter.trim().toLowerCase());

          return DraggableScrollableSheet(
            initialChildSize: 0.75,
            maxChildSize: 0.92,
            minChildSize: 0.45,
            expand: false,
            builder: (_, scrollCtrl) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pilih Detail Lokasi / Benchmark',
                            style: TextStyle(
                              color: _coachDark,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Area: $_area',
                            style: const TextStyle(color: _coachPurple, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(modalCtx),
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      onChanged: (val) => setModalState(() => filter = val),
                      style: const TextStyle(fontSize: 14, color: _coachDark),
                      decoration: InputDecoration(
                        hintText: 'Ketik untuk mencari benchmark...',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                        suffixIcon: filter.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () => setModalState(() => filter = ''),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                if (canAddCustom)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: InkWell(
                      onTap: () async {
                        final newBm = filter.trim().toUpperCase();
                        Navigator.pop(modalCtx);
                        setState(() {
                          if (!_benchmarksList.contains(newBm)) {
                            _benchmarksList.add(newBm);
                            _benchmarksList.sort();
                          }
                          _benchmark = newBm;
                        });
                        try {
                          final sqldb = await _db.database;
                          await sqldb.rawInsert(
                            '''INSERT OR IGNORE INTO tbl_m_benchmark (perusahaan_id, area_utama, nama_benchmark, created_at)
                               VALUES (?, ?, ?, ?)''',
                            [_profile?.companyId ?? 1, _area, newBm, DateTime.now().toIso8601String()],
                          );
                        } catch (_) {}
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF5FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE9D5FF)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _coachPurple,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.add, color: Colors.white, size: 16),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Gunakan Benchmark Baru:',
                                    style: TextStyle(color: _coachPurple, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    '"${filter.trim().toUpperCase()}"',
                                    style: const TextStyle(
                                      color: _coachDark,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, color: _coachPurple, size: 14),
                          ],
                        ),
                      ),
                    ),
                  ),

                Expanded(
                  child: _isLoadingBenchmarks && _benchmarksList.isEmpty
                      ? const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: _coachPurple),
                          ),
                        )
                      : filtered.isEmpty && !canAddCustom
                          ? const Center(
                              child: Text('Benchmark tidak ditemukan', style: TextStyle(color: Color(0xFF94A3B8))),
                            )
                          : ListView.separated(
                              controller: scrollCtrl,
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                              itemBuilder: (context, index) {
                                final item = filtered[index];
                                final isSelected = item == _benchmark;
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  title: Text(
                                    item,
                                    style: TextStyle(
                                      color: isSelected ? _coachPurple : _coachDark,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 14,
                                    ),
                                  ),
                                  trailing: isSelected
                                      ? const Icon(Icons.check_circle_rounded, color: _coachPurple, size: 20)
                                      : null,
                                  onTap: () {
                                    Navigator.pop(modalCtx);
                                    setState(() => _benchmark = item);
                                  },
                                );
                              },
                            ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // BOTTOM SHEET PICKER UNTUK TEMA COACHING
  void _showTemaPickerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.60,
        maxChildSize: 0.88,
        minChildSize: 0.40,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pilih Tema Coaching',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _coachDark),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Expanded(
              child: ListView.separated(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                itemCount: _temasList.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, index) {
                  final t = _temasList[index];
                  final isSelected = t == _tema;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    leading: Icon(
                      isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                      color: isSelected ? _coachPurple : const Color(0xFF94A3B8),
                    ),
                    title: Text(
                      t,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? _coachPurple : _coachDark,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded, color: _coachPurple, size: 20)
                        : null,
                    onTap: () {
                      setState(() => _tema = t);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoDocumentation() {
    final hasLocal = _image != null && _image!.isNotEmpty;
    final hasRemote = _existingImageUrl != null && _existingImageUrl!.isNotEmpty;
    final hasImage = hasLocal || hasRemote;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.camera_alt_rounded, size: 16, color: _coachPurple),
                SizedBox(width: 6),
                Text(
                  'FOTO BUKTI COACHING *',
                  style: TextStyle(
                    color: _coachDark,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
              decoration: BoxDecoration(
                color: hasImage ? const Color(0xFFECFDF5) : _coachPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: hasImage ? const Color(0xFFA7F3D0) : _coachPurple.withValues(alpha: 0.25),
                ),
              ),
              child: Text(
                hasImage ? 'Terlampir ✓' : 'Wajib 1 Foto',
                style: TextStyle(
                  color: hasImage ? const Color(0xFF059669) : _coachPurple,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (hasImage)
          Container(
            height: 165,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                InkWell(
                  onTap: () => _previewImage(
                    localPath: _image,
                    remoteUrl: _existingImageUrl,
                    title: 'Foto Coaching',
                  ),
                  child: hasLocal
                      ? Image.file(File(_image!), fit: BoxFit.cover)
                      : Image.network(
                          _existingImageUrl!.startsWith('http')
                              ? _existingImageUrl!
                              : '${_api.dio.options.baseUrl}$_existingImageUrl',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 36),
                          ),
                        ),
                ),

                // Top Zoom & Delete
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x99000000), Colors.transparent],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          onTap: () => _previewImage(
                            localPath: _image,
                            remoteUrl: _existingImageUrl,
                            title: 'Foto Coaching',
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Lihat Penuh',
                                  style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => setState(() {
                            _image = null;
                            _existingImageUrl = null;
                          }),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Ganti Foto
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: InkWell(
                    onTap: _pickPhoto,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white38),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.camera_alt_outlined, color: Colors.white, size: 13),
                          SizedBox(width: 5),
                          Text(
                            'Ganti Foto',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          InkWell(
            onTap: _pickPhoto,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 76,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _coachPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _coachPurple.withValues(alpha: 0.2)),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: _coachPurple, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ambil Foto Bukti Coaching',
                          style: TextStyle(
                            color: _coachDark,
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Foto pembina bersama seluruh peserta bimbingan',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _coachPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _coachPurple.withValues(alpha: 0.25)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_a_photo_rounded, color: _coachPurple, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Ambil Foto',
                          style: TextStyle(
                            color: _coachPurple,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _submitForm() async {
    // Validasi
    if (_area == null || _area!.trim().isEmpty) {
      _showWarning('Pilih Area Utama terlebih dahulu.');
      return;
    }
    if (_benchmark == null || _benchmark!.trim().isEmpty) {
      _showWarning('Pilih Lokasi / Benchmark terlebih dahulu.');
      return;
    }
    if (_title.text.trim().isEmpty) {
      _showWarning('Komitmen bersama hasil coaching wajib diisi.');
      return;
    }
    if (_feedback.text.trim().isEmpty) {
      _showWarning('Umpan balik (feedback) hasil evaluasi wajib diisi.');
      return;
    }
    if (_selectedTrainees.isEmpty) {
      _showWarning('Tambahkan minimal satu peserta coaching dengan mengetikkan NIK pada kolom peserta.');
      return;
    }
    final hasPhoto = (_image != null && _image!.isNotEmpty) ||
        (_existingImageUrl != null && _existingImageUrl!.isNotEmpty);
    if (!hasPhoto) {
      _showWarning('Foto bukti kegiatan coaching wajib diambil.');
      return;
    }

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_date ?? DateTime.now());
      final timeStr = _time ?? DateFormat('HH:mm').format(DateTime.now());
      final temaStr = _tema ?? 'Safety Coaching';
      final komitmenStr = _title.text.trim();
      final feedbackStr = _feedback.text.trim();
      final locDetailStr = _locationDetail.text.trim();

      // Encode participants JSON
      final participantsJson = jsonEncode(_selectedTrainees.map((t) {
        final nik = (t['no_nik'] ?? t['nik'] ?? '').toString();
        final nama = (t['nama_lengkap'] ?? t['nama'] ?? '').toString();
        return {
          'no_nik': nik,
          'nik': nik,
          'nama_lengkap': nama,
          'nama': nama,
          'posisi': (t['posisi'] ?? '').toString(),
          'departemen': (t['departemen'] ?? '').toString(),
          'perusahaan': (t['perusahaan'] ?? '').toString(),
        };
      }).toList());

      int targetLocalId = _localId ?? 0;

      if (_localId != null && _localId! > 0) {
        // Mode UPDATE record lokal
        final updateData = <String, dynamic>{
          'title': komitmenStr,
          'komitmen': komitmenStr,
          'purpose': temaStr,
          'tema': temaStr,
          'remark': feedbackStr,
          'feedback': feedbackStr,
          'area': _area,
          'lokasi': _benchmark,
          'detil_lokasi': locDetailStr,
          'location_detail': locDetailStr,
          'date': dateStr,
          'time': timeStr,
          if (_image != null) 'image': _image,
          if (_image != null) 'foto': _image,
          'participants_json': participantsJson,
          'updated_at': DateTime.now().toIso8601String(),
          'sync_id': null, // trigger resync
        };
        await _db.update('coaching_trans', updateData, _localId!);
        targetLocalId = _localId!;

        // Delete old details and reinsert
        final sqldb = await _db.database;
        await sqldb.rawDelete('DELETE FROM coaching_details WHERE tran_id = ?', [targetLocalId]);
      } else {
        // Mode INSERT baru
        final insertData = <String, dynamic>{
          'code': '${_profile?.noNik ?? 'EMP'}-${DateTime.now().millisecondsSinceEpoch}',
          'title': komitmenStr,
          'komitmen': komitmenStr,
          'purpose': temaStr,
          'tema': temaStr,
          'remark': feedbackStr,
          'feedback': feedbackStr,
          'area': _area,
          'lokasi': _benchmark,
          'detil_lokasi': locDetailStr,
          'location_detail': locDetailStr,
          'date': dateStr,
          'time': timeStr,
          'image': _image,
          'foto': _image,
          'participants_json': participantsJson,
          'status': 0,
          'company_id': _profile?.companyId,
          'employee_id': _profile?.id,
          'trainer_id': _profile?.id,
          'nik': _profile?.noNik,
          'nama': _profile?.namaLengkap,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };
        targetLocalId = await _db.insert('coaching_trans', insertData);
      }

      // Insert participants into coaching_details table
      for (final trainee in _selectedTrainees) {
        final nik = (trainee['no_nik'] ?? trainee['nik'] ?? '').toString();
        final nama = (trainee['nama_lengkap'] ?? trainee['nama'] ?? '').toString();
        final posisi = (trainee['posisi'] ?? '').toString();
        final dept = (trainee['departemen'] ?? '').toString();
        final comp = (trainee['perusahaan'] ?? '').toString();

        await _db.insert(
          'coaching_details',
          CoachingDetailModel(
            tranId: targetLocalId,
            name: '$nik - $nama',
            remark: posisi,
            status: 0,
          ).toJson()
            ..addAll({
              'no_nik': nik,
              'nik': nik,
              'nama_lengkap': nama,
              'posisi': posisi,
              'departemen': dept,
              'perusahaan': comp,
            }),
        );
      }

      // Sync ke backend
      bool synced = false;
      try {
        synced = await syncTran(_db, _api, 'coaching', targetLocalId);
      } catch (_) {
        synced = false;
      }

      if (!mounted) return;
      setState(() => _isSaving = false);
      OfflineSyncService.instance.refresh();

      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(synced ? Icons.check_circle_rounded : Icons.cloud_off_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  synced
                      ? 'Sesi Coaching berhasil disimpan & disinkronkan ke server.'
                      : 'Sesi Coaching tersimpan di perangkat (Offline). Akan dikirim saat internet aktif.',
                ),
              ),
            ],
          ),
          backgroundColor: synced ? const Color(0xFF16A34A) : const Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
        ),
      );

      navigator.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan sesi coaching: $e'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingId != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: TopBar(title: isEdit ? 'Edit Sesi Coaching' : 'Buat Sesi Coaching'),
      body: _isLoadingExisting
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: _coachPurple),
                  SizedBox(height: 14),
                  Text('Memuat data sesi coaching...', style: TextStyle(color: Color(0xFF64748B))),
                ],
              ),
            )
          : SingleChildScrollView(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // SECTION 1: Waktu & Lokasi Kegiatan
                  SapSectionCard(
                    stepNumber: '1',
                    title: 'WAKTU & LOKASI KEGIATAN',
                    subtitle: 'Tanggal, jam dan titik area bimbingan coaching',
                    icon: Icons.place_rounded,
                    accentColor: _coachPurple,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _date ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) {
                                  setState(() => _date = picked);
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today_rounded, size: 18, color: _coachPurple),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Tanggal', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                          Text(
                                            DateFormat('dd MMM yyyy').format(_date ?? DateTime.now()),
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _coachDark),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.now(),
                                );
                                if (time != null) {
                                  final hour = time.hour.toString().padLeft(2, '0');
                                  final minute = time.minute.toString().padLeft(2, '0');
                                  setState(() => _time = '$hour:$minute');
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.access_time_rounded, size: 18, color: _coachPurple),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Jam', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                          Text(
                                            _time ?? DateFormat('HH:mm').format(DateTime.now()),
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _coachDark),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Area Utama
                      const Text(
                        'AREA UTAMA *',
                        style: TextStyle(
                          color: _coachDark,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _PickerTile(
                        icon: Icons.place_rounded,
                        value: _area,
                        hint: 'Pilih Area Utama',
                        enabled: true,
                        accentColor: _coachPurple,
                        onTap: _showAreaPickerModal,
                      ),
                      const SizedBox(height: 14),

                      // Benchmark
                      const Text(
                        'LOKASI / BENCHMARK *',
                        style: TextStyle(
                          color: _coachDark,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _PickerTile(
                        icon: Icons.near_me_rounded,
                        value: _benchmark,
                        hint: _area == null ? 'Pilih Area Utama dulu' : 'Pilih Detail Lokasi',
                        enabled: _area != null && _area!.isNotEmpty,
                        accentColor: _coachPurple,
                        onTap: _showBenchmarkPickerModal,
                      ),
                      const SizedBox(height: 14),

                      // GPS
                      const Text(
                        'DETAIL LOKASI / GPS KOORDINAT',
                        style: TextStyle(
                          color: _coachDark,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _locationDetail,
                        decoration: InputDecoration(
                          hintText: 'Titik kerja spesifik / GPS otomatis',
                          hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.gps_fixed_rounded, color: _coachPurple, size: 20),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.my_location_rounded, color: _coachPurple, size: 20),
                            tooltip: 'Ambil GPS Terkini',
                            onPressed: () => _fillGpsFromDevice(silent: false),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _coachPurple, width: 1.6),
                          ),
                        ),
                        style: const TextStyle(fontSize: 13, color: _coachDark),
                      ),
                    ],
                  ),

                  // SECTION 2: Tema & Materi Coaching
                  SapSectionCard(
                    stepNumber: '2',
                    title: 'TEMA & MATERI COACHING',
                    subtitle: 'Topik pembinaan, evaluasi feedback dan komitmen bersama',
                    icon: Icons.menu_book_rounded,
                    accentColor: _coachPurple,
                    children: [
                      const Text(
                        'TEMA COACHING *',
                        style: TextStyle(
                          color: _coachDark,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _PickerTile(
                        icon: Icons.menu_book_outlined,
                        value: _tema,
                        hint: 'Pilih Tema Coaching',
                        enabled: true,
                        accentColor: _coachPurple,
                        onTap: _showTemaPickerModal,
                      ),
                      const SizedBox(height: 14),

                      const Text(
                        'KOMITMEN BERSAMA *',
                        style: TextStyle(
                          color: _coachDark,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _title,
                        decoration: InputDecoration(
                          hintText: 'Contoh: Pekerja berkomitmen selalu menggunakan full body harness',
                          hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.handshake_outlined, color: _coachPurple, size: 20),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _coachPurple, width: 1.6),
                          ),
                        ),
                        style: const TextStyle(fontSize: 13, color: _coachDark, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 14),

                      const Text(
                        'UMPAN BALIK (FEEDBACK) & CATATAN EVALUASI *',
                        style: TextStyle(
                          color: _coachDark,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _feedback,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Tuliskan catatan bimbingan, poin evaluasi tugas, dan arahan keselamatan...',
                          hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.all(14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _coachPurple, width: 1.6),
                          ),
                        ),
                        style: const TextStyle(fontSize: 13, color: _coachDark),
                      ),
                    ],
                  ),

                  // SECTION 3: Peserta Coaching (Trainee) - LANGSUNG KETIK NIK TANPA PERUSAHAAN
                  SapSectionCard(
                    stepNumber: '3',
                    title: 'PESERTA COACHING (TRAINEE)',
                    subtitle: 'Langsung ketik NIK atau nama untuk menambahkan peserta (bisa beberapa orang)',
                    icon: Icons.person_search_rounded,
                    accentColor: const Color(0xFF059669),
                    children: [
                      // Input Pencarian Langsung NIK
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'CARI / KETIK NIK PESERTA *',
                            style: TextStyle(
                              color: _coachDark,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.4,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: Text(
                              '${_selectedTrainees.length} Peserta Ditambahkan',
                              style: const TextStyle(
                                color: Color(0xFF059669),
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      TextField(
                        controller: _traineeQuery,
                        onChanged: _searchTrainees,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.badge_rounded, color: Color(0xFF059669), size: 20),
                          hintText: 'Ketik NIK atau nama pekerja (contoh: 2100... / Budi)',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          suffixIcon: _isSearchingTrainees
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF059669)),
                                  ),
                                )
                              : (_traineeQuery.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 18),
                                      onPressed: () {
                                        _traineeQuery.clear();
                                        setState(() => _traineeResults.clear());
                                      },
                                    )
                                  : null),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF059669), width: 1.6),
                          ),
                        ),
                        style: const TextStyle(fontSize: 13, color: _coachDark),
                      ),

                      // Dropdown Hasil Pencarian
                      if (_traineeResults.isNotEmpty || (_traineeQuery.text.trim().length >= 2)) ...[
                        const SizedBox(height: 8),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 240),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                            boxShadow: const [
                              BoxShadow(color: Color(0x0C000000), blurRadius: 10, offset: Offset(0, 3)),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: ListView(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                            children: [
                              // Tombol Add Manual NIK jika query tidak ada di list
                              if (_traineeQuery.text.trim().isNotEmpty &&
                                  !_traineeResults.any((r) =>
                                      (r['no_nik'] ?? r['nik'] ?? '').toString().toLowerCase() ==
                                      _traineeQuery.text.trim().toLowerCase()))
                                InkWell(
                                  onTap: () => _addManualTrainee(_traineeQuery.text),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFFAF5FF),
                                      border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: _coachPurple,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.add, color: Colors.white, size: 14),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Tambah NIK Baru / Manual:',
                                                style: TextStyle(
                                                    fontSize: 11, color: _coachPurple, fontWeight: FontWeight.bold),
                                              ),
                                              Text(
                                                '"${_traineeQuery.text.trim().toUpperCase()}"',
                                                style: const TextStyle(
                                                    fontSize: 13, fontWeight: FontWeight.bold, color: _coachDark),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: _coachPurple),
                                      ],
                                    ),
                                  ),
                                ),

                              // Daftar Hasil Rekomendasi
                              ..._traineeResults.map((trainee) {
                                final nik = (trainee['no_nik'] ?? trainee['nik'] ?? '').toString();
                                final nama = (trainee['nama_lengkap'] ?? trainee['nama'] ?? '').toString();
                                final posisi = (trainee['posisi'] ?? '').toString();
                                final dept = (trainee['departemen'] ?? '').toString();
                                final comp = (trainee['perusahaan'] ?? '').toString();

                                final isAlreadyAdded = _selectedTrainees.any((item) {
                                  final cNik = (item['no_nik'] ?? item['nik'] ?? '').toString();
                                  return cNik.isNotEmpty && cNik.toLowerCase() == nik.toLowerCase();
                                });

                                return ListTile(
                                  dense: true,
                                  leading: const CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Color(0xFFECFDF5),
                                    child: Icon(Icons.person_rounded, size: 18, color: Color(0xFF059669)),
                                  ),
                                  title: Text(
                                    '$nik - $nama',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: isAlreadyAdded ? const Color(0xFF94A3B8) : _coachDark,
                                    ),
                                  ),
                                  subtitle: Text(
                                    [posisi, dept, comp].where((s) => s.isNotEmpty).join(' • '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                  trailing: isAlreadyAdded
                                      ? const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20)
                                      : const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF059669), size: 20),
                                  onTap: isAlreadyAdded ? null : () => _addTrainee(trainee),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    ],
                      const SizedBox(height: 12),

                      // Daftar Peserta Terpilih
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: _selectedTrainees.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF94A3B8)),
                                    SizedBox(width: 8),
                                    Text(
                                      'Belum ada peserta. Ketik NIK di atas untuk menambahkan.',
                                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                    ),
                                  ],
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Daftar Peserta Terdaftar (${_selectedTrainees.length}):',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF334155),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () => setState(() => _selectedTrainees.clear()),
                                        child: const Text(
                                          'Hapus Semua',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFDC2626),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: _selectedTrainees.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                                    itemBuilder: (context, index) {
                                      final t = _selectedTrainees[index];
                                      final nik = (t['no_nik'] ?? t['nik'] ?? '').toString();
                                      final nama = (t['nama_lengkap'] ?? t['nama'] ?? '').toString();
                                      final dept = (t['departemen'] ?? t['perusahaan'] ?? '').toString();

                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0xFFCBD5E1)),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(5),
                                              decoration: BoxDecoration(
                                                color: _coachPurple.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '${index + 1}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: _coachPurple,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '$nik - $nama',
                                                    style: const TextStyle(
                                                      fontSize: 12.5,
                                                      fontWeight: FontWeight.bold,
                                                      color: _coachDark,
                                                    ),
                                                  ),
                                                  if (dept.isNotEmpty)
                                                    Text(
                                                      dept,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Color(0xFF64748B),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFFDC2626)),
                                              onPressed: () => _removeTrainee(index),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),

                  // SECTION 4: Dokumentasi Foto Kegiatan
                  SapSectionCard(
                    stepNumber: '4',
                    title: 'DOKUMENTASI FOTO KEGIATAN',
                    subtitle: 'Foto sesi coaching dan bukti pembinaan bersama pekerja',
                    icon: Icons.camera_alt_rounded,
                    accentColor: _coachPurple,
                    children: [
                      _buildPhotoDocumentation(),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.verified_outlined, size: 18, color: Color(0xFF64748B)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Pastikan foto pembina dan peserta terlihat jelas bersama di area kerja.',
                                style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: FilledButton.icon(
            onPressed: _isSaving ? null : _submitForm,
            style: FilledButton.styleFrom(
              backgroundColor: _coachPurple,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(
              _isSaving
                  ? 'Menyimpan...'
                  : (isEdit ? 'Perbarui Sesi Coaching' : 'Simpan Sesi Coaching'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.value,
    required this.hint,
    required this.enabled,
    required this.onTap,
    this.accentColor = _coachPurple,
  });

  final IconData icon;
  final String? value;
  final String hint;
  final bool enabled;
  final VoidCallback onTap;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasValue ? accentColor.withValues(alpha: 0.5) : const Color(0xFFE2E8F0),
            width: hasValue ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: hasValue ? accentColor : const Color(0xFF94A3B8)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasValue ? value! : hint,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: hasValue ? FontWeight.bold : FontWeight.normal,
                  color: hasValue ? _coachDark : const Color(0xFF94A3B8),
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: hasValue ? accentColor : const Color(0xFF94A3B8),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

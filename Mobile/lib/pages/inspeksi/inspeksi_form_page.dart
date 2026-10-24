import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../services/database.dart';
import '../../services/offline_sync_service.dart';
import '../../services/preference.dart';
import '../../utils/enums.dart';
import '../../widgets/sap_form_widgets.dart';
import '../../widgets/snackbar_msg.dart';
import '../../widgets/top_bar.dart';

class InspeksiFormPage extends StatefulWidget {
  const InspeksiFormPage(this.module, {this.idx, super.key});

  final Module module;
  final int? idx;

  @override
  State<InspeksiFormPage> createState() => _InspeksiFormPageState();
}

class _CheckpointItem {
  final String key;
  final String moduleTitle;
  final String question;
  int score = 2; // 2: YA, 1: N/A, 0: TIDAK
  File? photo;
  String? remark;

  _CheckpointItem({
    required this.key,
    required this.moduleTitle,
    required this.question,
  });
}

class _CustomQuestion {
  final String id;
  final String question;
  final int optionType; // 2: YA/TIDAK, 3: YA/N/A/TIDAK
  int score;
  File? photo;
  String? remark;

  _CustomQuestion({
    required this.id,
    required this.question,
    this.optionType = 3,
    this.score = 2,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'question': question,
        'option_type': optionType,
        'score': score,
        'photo_path': photo?.path,
        'remark': remark,
      };
}

class _PjaCandidate {
  final int id;
  final String nik;
  final String nama;
  final String jabatan;
  final String departemen;
  final String perusahaan;

  const _PjaCandidate({
    required this.id,
    required this.nik,
    required this.nama,
    required this.jabatan,
    required this.departemen,
    required this.perusahaan,
  });
}

class _InspeksiFormPageState extends State<InspeksiFormPage> {
  final _db = DatabaseService();
  final _profile = PreferenceService.getProfile();

  // Controllers
  final _lokasiSpesifikCtrl = TextEditingController();
  final _detilLokasiCtrl = TextEditingController();
  final _catatanCtrl = TextEditingController();
  final _pjaSearchCtrl = TextEditingController();

  // Form State
  DateTime _tanggal = DateTime.now();
  TimeOfDay _waktu = TimeOfDay.now();
  String _jenisInspeksi = 'INSPEKSI TERENCANA (PLANNED)';
  String _area = '';
  String? _selectedBenchmark;
  List<String> _masterAreas = [];
  List<String> _benchmarksList = [];
  bool _isLoadingAreas = false;
  bool _isLoadingBenchmarks = false;
  bool _isSaving = false;

  // PJA Selection
  _PjaCandidate? _selectedPja;
  List<_PjaCandidate> _pjaSearchResults = [];
  bool _isSearchingPja = false;
  bool _isMitraMode = false;

  // 15 Standard Checkpoints dari Web /Inspection/Index
  late final List<_CheckpointItem> _checkpoints;

  // Dynamic Custom Questions (Standardisasi Form)
  final List<_CustomQuestion> _customQuestions = [];

  // Theme Colors
  static const Color primaryGreen = Color(0xFF0F766E); // Deep Teal / Emerald
  static const Color lightGreen = Color(0xFFECFDF5);
  static const Color borderGreen = Color(0xFFA7F3D0);

  final List<String> _defaultAreas = [
    'PIT AREA',
    'DISPOSAL AREA',
    'HAULING ROAD',
    'ROM STOCKPILE',
    'WORKSHOP',
    'WAREHOUSE',
    'PORT / JETTY',
    'CAMP / MESS',
    'OFFICE AREA',
    'FUEL STATION',
    'WATER TREATMENT',
    'EXPLORATION',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.module == Module.inspectionWeekly) {
      _jenisInspeksi = 'INSPEKSI MINGGUAN (WEEKLY)';
    }
    _initCheckpoints();
    _loadAreasFromMaster();
    _fillGpsFromDevice(silent: true);
  }

  @override
  void dispose() {
    _lokasiSpesifikCtrl.dispose();
    _detilLokasiCtrl.dispose();
    _catatanCtrl.dispose();
    _pjaSearchCtrl.dispose();
    super.dispose();
  }

  void _initCheckpoints() {
    _checkpoints = [
      // Modul 1. Kepatuhan & Sistem
      _CheckpointItem(
        key: '1_1',
        moduleTitle: 'Modul 1: Kepatuhan & Sistem',
        question: 'Apakah pekerjaan yang diamati dilakukan sesuai prosedur yang berlaku?',
      ),
      _CheckpointItem(
        key: '1_2',
        moduleTitle: 'Modul 1: Kepatuhan & Sistem',
        question: 'Apakah dokumen/izin yang diperlukan tersedia dan masih berlaku?',
      ),
      _CheckpointItem(
        key: '1_3',
        moduleTitle: 'Modul 1: Kepatuhan & Sistem',
        question: 'Apakah temuan inspeksi sebelumnya sudah ditindaklanjuti?',
      ),

      // Modul 2. Risiko & Keselamatan
      _CheckpointItem(
        key: '2_1',
        moduleTitle: 'Modul 2: Risiko & Keselamatan',
        question: 'Apakah risiko utama pekerjaan telah diidentifikasi sebelum pekerjaan dilakukan?',
      ),
      _CheckpointItem(
        key: '2_2',
        moduleTitle: 'Modul 2: Risiko & Keselamatan',
        question: 'Apakah pengendali risiko kritis telah diterapkan secara efektif?',
      ),
      _CheckpointItem(
        key: '2_3',
        moduleTitle: 'Modul 2: Risiko & Keselamatan',
        question: 'Apakah pekerja memahami risiko dan langkah mitigasi saat terjadi bahaya?',
      ),

      // Modul 3. Lingkungan Kerja & Housekeeping
      _CheckpointItem(
        key: '3_1',
        moduleTitle: 'Modul 3: Lingkungan Kerja & Housekeeping',
        question: 'Apakah area kerja bersih, rapi, dan bebas dari bahaya tersandung atau terpeleset?',
      ),
      _CheckpointItem(
        key: '3_2',
        moduleTitle: 'Modul 3: Lingkungan Kerja & Housekeeping',
        question: 'Apakah pencahayaan dan ventilasi di area kerja memadai untuk aktivitas yang dilakukan?',
      ),
      _CheckpointItem(
        key: '3_3',
        moduleTitle: 'Modul 3: Lingkungan Kerja & Housekeeping',
        question: 'Apakah limbah B3 dan sampah operasional dikelola dan dipisahkan dengan benar?',
      ),

      // Modul 4. Peralatan & APD
      _CheckpointItem(
        key: '4_1',
        moduleTitle: 'Modul 4: Peralatan & APD',
        question: 'Apakah alat pelindung diri (APD) yang dipersyaratkan digunakan secara lengkap dan benar?',
      ),
      _CheckpointItem(
        key: '4_2',
        moduleTitle: 'Modul 4: Peralatan & APD',
        question: 'Apakah peralatan kerja dan unit telah diinspeksi (P2H) sebelum dioperasikan?',
      ),
      _CheckpointItem(
        key: '4_3',
        moduleTitle: 'Modul 4: Peralatan & APD',
        question: 'Apakah pengaman mesin / safety device berfungsi dengan baik tanpa modifikasi terlarang?',
      ),

      // Modul 5. Monitoring & Perbaikan
      _CheckpointItem(
        key: '5_1',
        moduleTitle: 'Modul 5: Monitoring & Perbaikan',
        question: 'Apakah pengawas melakukan interaksi keselamatan / observasi secara berkala?',
      ),
      _CheckpointItem(
        key: '5_2',
        moduleTitle: 'Modul 5: Monitoring & Perbaikan',
        question: 'Apakah temuan K3 dicatat dan ditindaklanjuti rencana perbaikannya?',
      ),
      _CheckpointItem(
        key: '5_3',
        moduleTitle: 'Modul 5: Monitoring & Perbaikan',
        question: 'Apakah tersedia bukti bahwa tindakan perbaikan telah dilakukan dan efektif?',
      ),
    ];
  }

  Future<void> _loadAreasFromMaster() async {
    if (_isLoadingAreas) return;
    setState(() => _isLoadingAreas = true);
    try {
      final db = await _db.database;
      final rows = await db.rawQuery('SELECT DISTINCT area FROM locations WHERE area IS NOT NULL ORDER BY area');
      final list = rows.map((r) => r['area']?.toString() ?? '').where((s) => s.isNotEmpty).toList();

      final subRows = await db.rawQuery('SELECT DISTINCT area FROM sublocations WHERE area IS NOT NULL ORDER BY area');
      final subList = subRows.map((r) => r['area']?.toString() ?? '').where((s) => s.isNotEmpty).toList();

      final combined = {..._defaultAreas, ...list, ...subList}.toList()..sort();
      setState(() {
        _masterAreas = combined;
        if (_area.isEmpty && _masterAreas.isNotEmpty) {
          _area = _masterAreas.first;
          _loadBenchmarksForArea(_area);
        }
      });
    } catch (_) {
      setState(() {
        _masterAreas = _defaultAreas;
        if (_area.isEmpty) _area = _defaultAreas.first;
      });
    } finally {
      if (mounted) setState(() => _isLoadingAreas = false);
    }
  }

  Future<void> _loadBenchmarksForArea(String areaName) async {
    if (_isLoadingBenchmarks) return;
    setState(() => _isLoadingBenchmarks = true);
    try {
      final db = await _db.database;
      final rows = await db.rawQuery(
        'SELECT nama_benchmark FROM tbl_m_benchmark WHERE area_utama = ? ORDER BY nama_benchmark',
        [areaName],
      );
      final fromBench = rows.map((r) => r['nama_benchmark']?.toString() ?? '').where((s) => s.isNotEmpty).toList();

      final subRows = await db.rawQuery(
        'SELECT DISTINCT sublocation FROM sublocations WHERE area = ? AND sublocation IS NOT NULL ORDER BY sublocation',
        [areaName],
      );
      final fromSub = subRows.map((r) => r['sublocation']?.toString() ?? '').where((s) => s.isNotEmpty).toList();

      final combined = {...fromBench, ...fromSub}.toList()..sort();
      setState(() {
        _benchmarksList = combined;
        if (_benchmarksList.isNotEmpty && (_selectedBenchmark == null || !_benchmarksList.contains(_selectedBenchmark))) {
          _selectedBenchmark = _benchmarksList.first;
          _detilLokasiCtrl.text = _selectedBenchmark!;
        }
      });
    } catch (_) {
      setState(() => _benchmarksList = []);
    } finally {
      if (mounted) setState(() => _isLoadingBenchmarks = false);
    }
  }

  void _fillGpsFromDevice({bool silent = false}) {
    fillGpsCoordinate(
      context,
      _detilLokasiCtrl,
      () => setState(() {}),
      silent: silent,
    );
  }

  Future<void> _searchPja(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _pjaSearchResults = [];
        _isSearchingPja = false;
      });
      return;
    }

    setState(() => _isSearchingPja = true);
    try {
      final db = await _db.database;
      final q = '%${query.trim()}%';
      final rows = await db.rawQuery(
        '''
        SELECT id, nik, nama, jabatan, departemen, perusahaan 
        FROM employees 
        WHERE (nama LIKE ? OR nik LIKE ? OR departemen LIKE ?)
        LIMIT 25
        ''',
        [q, q, q],
      );

      final List<_PjaCandidate> results = [];
      for (var r in rows) {
        results.add(
          _PjaCandidate(
            id: (r['id'] as num?)?.toInt() ?? 0,
            nik: r['nik']?.toString() ?? '',
            nama: r['nama']?.toString() ?? '',
            jabatan: r['jabatan']?.toString() ?? '',
            departemen: r['departemen']?.toString() ?? '',
            perusahaan: r['perusahaan']?.toString() ?? 'PT Indexim Coalindo',
          ),
        );
      }

      setState(() => _pjaSearchResults = results);
    } catch (_) {
      setState(() => _pjaSearchResults = []);
    } finally {
      if (mounted) setState(() => _isSearchingPja = false);
    }
  }

  Future<void> _pickImageForCheckpoint(_CheckpointItem item) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 14),
              const Text('Unggah Foto Bukti Temuan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 4),
              const Text('Wajib menyertakan foto kondisi tidak sesuai untuk temuan K3', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF2563EB)),
                ),
                title: const Text('Kamera Lapangan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: const Text('Ambil foto langsung di lokasi temuan', style: TextStyle(fontSize: 11)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.photo_library_rounded, color: Color(0xFF16A34A)),
                ),
                title: const Text('Galeri Gambar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: const Text('Pilih dari media penyimpanan perangkat', style: TextStyle(fontSize: 11)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source != null) {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 70);
      if (picked != null) {
        setState(() => item.photo = File(picked.path));
      }
    }
  }

  Future<void> _pickImageForCustomQuestion(_CustomQuestion cq) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 14),
              const Text('Unggah Foto Bukti Pertanyaan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF2563EB)),
                title: const Text('Kamera Lapangan', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF16A34A)),
                title: const Text('Galeri Gambar', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source != null) {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 70);
      if (picked != null) {
        setState(() => cq.photo = File(picked.path));
      }
    }
  }

  void _showAreaPickerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String filter = '';
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final filtered = _masterAreas.where((a) => a.toLowerCase().contains(filter.toLowerCase())).toList();
            final hasExactMatch = _masterAreas.any((a) => a.toLowerCase() == filter.trim().toLowerCase());
            final canAddCustom = filter.trim().isNotEmpty && !hasExactMatch;

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 14),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pilih Area Utama',
                              style: TextStyle(color: Color(0xFF0F172A), fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 2),
                            Text('Pilih area lokasi kerja atau ketik area baru', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
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
                      ),
                      child: TextField(
                        onChanged: (val) => setModalState(() => filter = val),
                        decoration: const InputDecoration(
                          hintText: 'Cari atau ketik nama area...',
                          hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  if (canAddCustom)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: InkWell(
                        onTap: () {
                          final newArea = filter.trim().toUpperCase();
                          setState(() {
                            if (!_masterAreas.contains(newArea)) {
                              _masterAreas.add(newArea);
                              _masterAreas.sort();
                            }
                            _area = newArea;
                            _selectedBenchmark = null;
                          });
                          _loadBenchmarksForArea(newArea);
                          Navigator.pop(modalCtx);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.add_circle_outline_rounded, color: primaryGreen, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('Gunakan Area Baru: "${filter.trim().toUpperCase()}"',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: primaryGreen)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(color: Color(0xFFF1F5F9), height: 1),
                      itemBuilder: (ctx, idx) {
                        final a = filtered[idx];
                        final isSel = a == _area;
                        return ListTile(
                          onTap: () {
                            setState(() {
                              _area = a;
                              _selectedBenchmark = null;
                            });
                            _loadBenchmarksForArea(a);
                            Navigator.pop(modalCtx);
                          },
                          leading: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: isSel ? primaryGreen : const Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.layers_rounded, size: 18, color: isSel ? Colors.white : const Color(0xFF64748B)),
                          ),
                          title: Text(a, style: TextStyle(fontWeight: isSel ? FontWeight.bold : FontWeight.w600, fontSize: 13, color: isSel ? primaryGreen : const Color(0xFF0F172A))),
                          trailing: isSel ? const Icon(Icons.check_rounded, color: primaryGreen, size: 20) : null,
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showBenchmarkPickerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String filter = '';
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final filtered = _benchmarksList.where((b) => b.toLowerCase().contains(filter.toLowerCase())).toList();
            final hasExactMatch = _benchmarksList.any((b) => b.toLowerCase() == filter.trim().toLowerCase());
            final canAddCustom = filter.trim().isNotEmpty && !hasExactMatch;

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 14),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Detail Lokasi / Benchmark', style: TextStyle(color: Color(0xFF0F172A), fontSize: 17, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text('Area: $_area', style: const TextStyle(color: primaryGreen, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
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
                      ),
                      child: TextField(
                        onChanged: (val) => setModalState(() => filter = val),
                        decoration: const InputDecoration(
                          hintText: 'Cari atau ketik benchmark baru...',
                          hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  if (canAddCustom)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: InkWell(
                        onTap: () async {
                          final newBench = filter.trim().toUpperCase();
                          try {
                            final db = await _db.database;
                            await db.rawInsert(
                              '''INSERT INTO tbl_m_benchmark (perusahaan_id, area_utama, nama_benchmark, created_by_nik, created_by_name, created_at)
                                 VALUES (?, ?, ?, ?, ?, ?)''',
                              [_profile?.companyId ?? 1, _area, newBench, _profile?.noNik ?? '', _profile?.namaLengkap ?? '', DateTime.now().toIso8601String()],
                            );
                          } catch (_) {}

                          setState(() {
                            if (!_benchmarksList.contains(newBench)) {
                              _benchmarksList.add(newBench);
                              _benchmarksList.sort();
                            }
                            _selectedBenchmark = newBench;
                            _detilLokasiCtrl.text = newBench;
                          });
                          if (modalCtx.mounted) Navigator.pop(modalCtx);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.add_location_alt_rounded, color: primaryGreen, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('Simpan Benchmark Baru Offline: "$filter"',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: primaryGreen)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  Expanded(
                    child: _benchmarksList.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Text(
                                'Belum ada data benchmark di area ini.\nKetik nama titik di atas untuk menambahkan secara offline.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(color: Color(0xFFF1F5F9), height: 1),
                            itemBuilder: (ctx, idx) {
                              final b = filtered[idx];
                              final isSel = b == _selectedBenchmark;
                              return ListTile(
                                onTap: () {
                                  setState(() {
                                    _selectedBenchmark = b;
                                    _detilLokasiCtrl.text = b;
                                  });
                                  Navigator.pop(modalCtx);
                                },
                                leading: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: isSel ? primaryGreen : const Color(0xFFF1F5F9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.place_rounded, size: 18, color: isSel ? Colors.white : const Color(0xFF64748B)),
                                ),
                                title: Text(b, style: TextStyle(fontWeight: isSel ? FontWeight.bold : FontWeight.w600, fontSize: 13, color: isSel ? primaryGreen : const Color(0xFF0F172A))),
                                trailing: isSel ? const Icon(Icons.check_rounded, color: primaryGreen, size: 20) : null,
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showAddCustomQuestionDialog() async {
    final qCtrl = TextEditingController();
    int optionType = 3;

    final res = await showDialog<({String question, int optionType})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.add_task_rounded, color: primaryGreen),
              SizedBox(width: 10),
              Expanded(
                child: Text('Tambah Pertanyaan Kustom', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pertanyaan / Checkpoint Baru', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              TextField(
                controller: qCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Misal: Apakah APD khusus ketinggian tersedia?',
                  hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                ),
                style: const TextStyle(fontSize: 13),
                autofocus: true,
              ),
              const SizedBox(height: 14),
              const Text('Tipe Pilihan Jawaban', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setDialogState(() => optionType = 3),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: optionType == 3 ? primaryGreen : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: optionType == 3 ? primaryGreen : const Color(0xFFCBD5E1)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '3 Pilihan\n(YA, N/A, TIDAK)',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: optionType == 3 ? Colors.white : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => setDialogState(() => optionType = 2),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: optionType == 2 ? primaryGreen : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: optionType == 2 ? primaryGreen : const Color(0xFFCBD5E1)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '2 Pilihan\n(YA, TIDAK)',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: optionType == 2 ? Colors.white : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                if (qCtrl.text.trim().isEmpty) return;
                Navigator.pop(dialogCtx, (question: qCtrl.text.trim(), optionType: optionType));
              },
              child: const Text('Tambahkan', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (res != null) {
      setState(() {
        _customQuestions.add(
          _CustomQuestion(
            id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
            question: res.question,
            optionType: res.optionType,
            score: 2,
          ),
        );
      });
    }
  }

  Future<void> _submitInspection() async {
    // 1. Validasi Area
    if (_area.trim().isEmpty) {
      SnackBarMsg.danger(context, 'Harap pilih Area Utama terlebih dahulu.');
      return;
    }

    // 2. Validasi PJA
    if (_selectedPja == null && _pjaSearchCtrl.text.trim().isEmpty) {
      SnackBarMsg.danger(context, 'Harap tetapkan Penanggung Jawab Area (PJA).');
      return;
    }

    // 3. Validasi foto jika ada temuan (skor 0 / TIDAK)
    for (var cp in _checkpoints) {
      if (cp.score == 0 && cp.photo == null) {
        SnackBarMsg.danger(context, 'Temuan pada "${cp.question}" wajib melampirkan foto bukti kondisi.');
        return;
      }
    }

    for (var cq in _customQuestions) {
      if (cq.score == 0 && cq.photo == null) {
        SnackBarMsg.danger(context, 'Temuan pada pertanyaan kustom wajib melampirkan foto bukti kondisi.');
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final db = await _db.database;
      final profileId = _profile?.id ?? 0;
      final nowStr = DateTime.now().toIso8601String();

      final pjaName = _selectedPja?.nama ?? _pjaSearchCtrl.text.trim();
      final pjaNik = _selectedPja?.nik ?? '';
      final pjaDept = _selectedPja?.departemen ?? '';
      final pjaId = _selectedPja?.id ?? 0;

      // Kumpulkan skor checkpoint
      final Map<String, dynamic> payload = {
        'jenis_inspeksi': _jenisInspeksi,
        'area': _area,
        'lokasi': _selectedBenchmark ?? _detilLokasiCtrl.text.trim(),
        'lokasi_spesifik': _lokasiSpesifikCtrl.text.trim(),
        'catatan': _catatanCtrl.text.trim(),
        'pja': pjaName,
        'nik_pja': pjaNik,
        'departemen_pja': pjaDept,
        'custom_questions': _customQuestions.map((q) => q.toJson()).toList(),
      };

      final Map<String, dynamic> insertValues = {
        'employee_id': profileId,
        'tanggal': DateFormat('yyyy-MM-dd').format(_tanggal),
        'waktu': '${_waktu.hour.toString().padLeft(2, '0')}:${_waktu.minute.toString().padLeft(2, '0')}',
        'jenis_inspeksi': _jenisInspeksi,
        'area': _area,
        'lokasi': _selectedBenchmark ?? _detilLokasiCtrl.text.trim(),
        'detil_lokasi': _lokasiSpesifikCtrl.text.trim(),
        'pja': pjaName,
        'nik_pja': pjaNik,
        'departemen_pja': pjaDept,
        'pja_id': pjaId,
        'catatan': _catatanCtrl.text.trim(),
        'payload_json': jsonEncode(payload),
        'created_at': nowStr,
        'sync_id': null, // Mode Offline
        'status': 0, // In Progress
      };

      // Tambahkan nilai q1_1 ... q5_3
      for (var cp in _checkpoints) {
        insertValues['q${cp.key}'] = cp.score.toString();
      }

      // Ambil foto temuan pertama jika ada untuk disimpan sebagai cover foto
      File? primaryPhoto;
      for (var cp in _checkpoints) {
        if (cp.photo != null) {
          primaryPhoto = cp.photo;
          break;
        }
      }
      if (primaryPhoto == null) {
        for (var cq in _customQuestions) {
          if (cq.photo != null) {
            primaryPhoto = cq.photo;
            break;
          }
        }
      }
      if (primaryPhoto != null) {
        insertValues['image'] = primaryPhoto.path;
      }

      final insertedId = await db.insert('inspection_trans', insertValues);

      if (!mounted) return;
      setState(() => _isSaving = false);

      // Trigger sync jika online
      OfflineSyncService.instance.syncNow();

      _showSuccessDialog(insertedId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      SnackBarMsg.danger(context, 'Gagal menyimpan laporan inspeksi: $e');
    }
  }

  void _showSuccessDialog(int localId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFECFDF5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: primaryGreen, size: 40),
            ),
            const SizedBox(height: 16),
            const Text(
              'Laporan Berhasil Disimpan!',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Laporan inspeksi tersimpan di database lokal (Offline Mode #$localId) dan siap disinkronkan ke server pusat.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, true);
              },
              child: const Text('Kembali ke Hub', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI BUILDER METHODS SAMA PERSIS DENGAN HAZARD CREATE PAGE ---

  Widget _buildSectionCard({
    required String stepNumber,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    stepNumber,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, size: 14, color: accentColor),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                color: accentColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker({required String label, required DateTime date, required VoidCallback onTap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600)),
            const Text('Aktual', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_rounded, color: primaryGreen, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    DateFormat('dd/MM/yyyy').format(date),
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimePicker({required String label, required TimeOfDay time, required VoidCallback onTap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded, color: primaryGreen, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormProgressBanner() {
    int totalSteps = 4;
    int completed = 0;
    final List<String> missing = [];

    // 1. Lokasi & Area
    if (_area.isNotEmpty) {
      completed++;
    } else {
      missing.add('Area');
    }

    // 2. PJA
    if (_selectedPja != null || _pjaSearchCtrl.text.trim().isNotEmpty) {
      completed++;
    } else {
      missing.add('PJA');
    }

    // 3. Evaluasi Checkpoints (apakah semua temuan tidak ada yang belum ada foto)
    bool photosComplete = true;
    for (var c in _checkpoints) {
      if (c.score == 0 && c.photo == null) {
        photosComplete = false;
        break;
      }
    }
    if (photosComplete) {
      completed++;
    } else {
      missing.add('Foto Bukti Temuan');
    }

    // 4. Checklist dijawab
    completed++; // default 15 pertanyaan sudah memiliki nilai default

    final double pct = completed / totalSteps;
    final Color barColor = pct >= 1.0 ? primaryGreen : (pct >= 0.5 ? const Color(0xFF0284C7) : const Color(0xFFEA580C));

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    pct >= 1.0 ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                    color: barColor,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Kelengkapan Formulir Inspeksi',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(pct * 100).toInt()}%',
                  style: TextStyle(
                    color: barColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 5,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Belum lengkap: ${missing.join(', ')}',
              style: const TextStyle(color: Color(0xFFDC2626), fontSize: 10.5, fontWeight: FontWeight.w500),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: const InputDecorationTheme(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          filled: false,
          fillColor: Colors.transparent,
          contentPadding: EdgeInsets.zero,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: const TopBar(title: 'Safety Inspeksi'),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card Identik dengan Hazard Create Page
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF64748B).withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: lightGreen,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderGreen),
                      ),
                      child: const Icon(Icons.assignment_turned_in_rounded, color: primaryGreen, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Formulir Pemeriksaan Inspeksi',
                            style: TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Evaluasi kepatuhan operasional K3 dan pantau temuan di lapangan.',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Form Progress Indicator
              _buildFormProgressBanner(),

              // SECTION 1: Waktu & Lokasi Pemeriksaan
              _buildSectionCard(
                stepNumber: '1',
                title: 'WAKTU & LOKASI PEMERIKSAAN',
                subtitle: 'Titik koordinat satelit dan area kerja inspeksi',
                icon: Icons.location_on_rounded,
                accentColor: const Color(0xFF0284C7),
                children: [
                  // Tanggal & Waktu
                  Row(
                    children: [
                      Expanded(
                        child: _buildDatePicker(
                          label: 'Tanggal Inspeksi',
                          date: _tanggal,
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _tanggal,
                              firstDate: DateTime.now().subtract(const Duration(days: 30)),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) setState(() => _tanggal = picked);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTimePicker(
                          label: 'Waktu Inspeksi',
                          time: _waktu,
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _waktu,
                            );
                            if (picked != null) setState(() => _waktu = picked);
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Jenis Inspeksi Segmented Pills
                  const Text('JENIS INSPEKSI *', style: TextStyle(color: Color(0xFF0F172A), fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      'INSPEKSI TERENCANA (PLANNED)',
                      'INSPEKSI MINGGUAN (WEEKLY)',
                      'INSPEKSI TIDAK TERENCANA',
                      'PEMERIKSAAN ALAT KERJA',
                      'INSPEKSI K3 LAPANGAN',
                    ].map((j) {
                      final isSel = _jenisInspeksi == j;
                      return InkWell(
                        onTap: () => setState(() => _jenisInspeksi = j),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSel ? primaryGreen : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isSel ? primaryGreen : const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            j,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                              color: isSel ? Colors.white : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 14),

                  // Area Utama Picker Modal
                  const Text('AREA UTAMA *', style: TextStyle(color: Color(0xFF0F172A), fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: _showAreaPickerModal,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _area.isNotEmpty ? const Color(0xFFBAE6FD) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.layers_rounded, color: Color(0xFF0284C7), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _area.isNotEmpty ? _area : 'Pilih Area Utama...',
                              style: TextStyle(
                                color: _area.isNotEmpty ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                fontSize: 13,
                                fontWeight: _area.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Detail Lokasi / Benchmark
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('DETAIL LOKASI / BENCHMARK *', style: TextStyle(color: Color(0xFF0F172A), fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      if (_area.isNotEmpty)
                        Text(
                          '${_benchmarksList.length} titik',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: _showBenchmarkPickerModal,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _detilLokasiCtrl.text.isNotEmpty ? const Color(0xFFBAE6FD) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.place_rounded, color: Color(0xFF0284C7), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _detilLokasiCtrl.text.isNotEmpty ? _detilLokasiCtrl.text : 'Pilih atau buat titik benchmark...',
                              style: TextStyle(
                                color: _detilLokasiCtrl.text.isNotEmpty ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                fontSize: 13,
                                fontWeight: _detilLokasiCtrl.text.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Koordinat Satelit GPS Aktual
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.my_location_rounded, color: Color(0xFF0284C7), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Koordinat Satelit Perangkat', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              const SizedBox(height: 2),
                              Text(
                                _detilLokasiCtrl.text.startsWith('-') || _detilLokasiCtrl.text.contains('.') ? _detilLokasiCtrl.text : 'GPS Aktual terdeteksi',
                                style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _fillGpsFromDevice(silent: false),
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Update GPS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: TextButton.styleFrom(foregroundColor: const Color(0xFF0284C7)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Lokasi Spesifik
                  const Text('LOKASI SPESIFIK / DETAIL KERJA', style: TextStyle(color: Color(0xFF0F172A), fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: _lokasiSpesifikCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Misal: Area Front Loading 02, Sisi Timur Pit',
                        hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),

              // SECTION 2: Penanggung Jawab Area (PJA)
              _buildSectionCard(
                stepNumber: '2',
                title: 'PENANGGUNG JAWAB AREA (PJA)',
                subtitle: 'Delegasi pengawas yang bertanggung jawab di lokasi kerja',
                icon: Icons.person_pin_rounded,
                accentColor: primaryGreen,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('STATUS PJA MITRA', style: TextStyle(color: Color(0xFF0F172A), fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      Row(
                        children: [
                          const Text('Lintas Mitra / Bebas Ketik', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          const SizedBox(width: 6),
                          Switch(
                            value: _isMitraMode,
                            activeThumbColor: primaryGreen,
                            onChanged: (val) {
                              setState(() {
                                _isMitraMode = val;
                                if (val) _selectedPja = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  if (_selectedPja != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: lightGreen,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderGreen),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: primaryGreen,
                            child: Text(
                              _selectedPja!.nama.isNotEmpty ? _selectedPja!.nama[0].toUpperCase() : 'P',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_selectedPja!.nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                                const SizedBox(height: 2),
                                Text('${_selectedPja!.nik} • ${_selectedPja!.departemen}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                Text(_selectedPja!.perusahaan, style: const TextStyle(fontSize: 10.5, color: primaryGreen, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Color(0xFFDC2626), size: 20),
                            onPressed: () => setState(() => _selectedPja = null),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: TextField(
                        controller: _pjaSearchCtrl,
                        onChanged: _searchPja,
                        decoration: InputDecoration(
                          hintText: _isMitraMode ? 'Ketik nama PJA / Pengawas Mitra...' : 'Ketik nama atau NIK pengawas...',
                          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          icon: const Icon(Icons.search_rounded, color: primaryGreen, size: 20),
                          border: InputBorder.none,
                          suffixIcon: _isSearchingPja
                              ? const SizedBox(width: 16, height: 16, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: primaryGreen)))
                              : null,
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),

                    if (_pjaSearchCtrl.text.trim().isNotEmpty && _isMitraMode) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () {
                          final name = _pjaSearchCtrl.text.trim();
                          setState(() {
                            _selectedPja = _PjaCandidate(
                              id: 0,
                              nik: '-',
                              nama: name,
                              jabatan: 'Pengawas Mitra',
                              departemen: 'Mitra Kerja',
                              perusahaan: 'Kontraktor Eksternal',
                            );
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('Gunakan: "${_pjaSearchCtrl.text.trim()}" sebagai PJA Mitra',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF1D4ED8))),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    if (_pjaSearchResults.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _pjaSearchResults.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (ctx, idx) {
                            final p = _pjaSearchResults[idx];
                            return ListTile(
                              dense: true,
                              title: Text(p.nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                              subtitle: Text('${p.nik} • ${p.departemen}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              onTap: () {
                                setState(() {
                                  _selectedPja = p;
                                  _pjaSearchResults = [];
                                  _pjaSearchCtrl.clear();
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ],
              ),

              // SECTION 3: CHECKLIST EVALUASI K3 (15 POIN STANDAR)
              _buildSectionCard(
                stepNumber: '3',
                title: 'CHECKLIST EVALUASI K3 (15 POIN)',
                subtitle: 'Evaluasi 5 modul standar K3 operasional (Web MBS)',
                icon: Icons.checklist_rounded,
                accentColor: const Color(0xFFEA580C),
                children: [
                  const Text(
                    'Pilih YA jika sesuai, N/A jika tidak berlaku, atau TIDAK jika ditemukan penyimpangan (wajib sertakan foto).',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.4),
                  ),
                  const SizedBox(height: 14),

                  // Daftar 15 Checkpoint terkelompok per modul
                  ..._buildGroupedCheckpoints(),
                ],
              ),

              // SECTION 4: STANDARDISASI & PERTANYAAN KUSTOM
              _buildSectionCard(
                stepNumber: '4',
                title: 'STANDARDISASI FORM INSPEKSI',
                subtitle: 'Fitur dinamis tambah pertanyaan custom lapangan seperti di web',
                icon: Icons.tune_rounded,
                accentColor: const Color(0xFF7C3AED),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFDDD6FE)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF7C3AED), size: 22),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Perlu item evaluasi khusus? Anda dapat membuat form pertanyaan tambahan yang langsung tersimpan di laporan.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF5B21B6), height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  if (_customQuestions.isNotEmpty) ...[
                    ..._customQuestions.map((cq) => _buildCustomQuestionItem(cq)),
                    const SizedBox(height: 8),
                  ],

                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF7C3AED),
                      side: const BorderSide(color: Color(0xFF7C3AED)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      minimumSize: const Size(double.infinity, 44),
                    ),
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                    label: const Text('Tambah Pertanyaan Kustom', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: _showAddCustomQuestionDialog,
                  ),
                ],
              ),

              // SECTION 5: CATATAN AKHIR & PENGIRIMAN
              _buildSectionCard(
                stepNumber: '5',
                title: 'CATATAN AKHIR & PENGIRIMAN',
                subtitle: 'Catatan umum, rekomendasi perbaikan & simpan draf offline',
                icon: Icons.send_rounded,
                accentColor: const Color(0xFF10B981),
                children: [
                  const Text('CATATAN TEMUAN / REKOMENDASI', style: TextStyle(color: Color(0xFF0F172A), fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: _catatanCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Tuliskan catatan umum, temuan khusus, atau saran perbaikan tindak lanjut...',
                        hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),

                  const SizedBox(height: 18),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 3,
                    ),
                    onPressed: _isSaving ? null : _submitInspection,
                    child: _isSaving
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                              SizedBox(width: 10),
                              Text('Menyimpan Laporan...'),
                            ],
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_rounded, size: 20),
                              SizedBox(width: 8),
                              Text('KIRIM LAPORAN INSPEKSI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, letterSpacing: 0.5)),
                            ],
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildGroupedCheckpoints() {
    final List<Widget> widgets = [];
    String? currentModule;

    for (int i = 0; i < _checkpoints.length; i++) {
      final cp = _checkpoints[i];
      if (currentModule != cp.moduleTitle) {
        currentModule = cp.moduleTitle;
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(color: primaryGreen, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 8),
                Text(
                  currentModule,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
                ),
              ],
            ),
          ),
        );
      }

      widgets.add(_buildCheckpointCard(cp, i + 1));
      widgets.add(const SizedBox(height: 10));
    }

    return widgets;
  }

  Widget _buildCheckpointCard(_CheckpointItem cp, int number) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: cp.score == 0 ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0),
          width: cp.score == 0 ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: primaryGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text('$number', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryGreen)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  cp.question,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: Color(0xFF0F172A), height: 1.3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Pilihan Jawaban 3 Pill Buttons
          Row(
            children: [
              Expanded(
                child: _buildAnswerPill(
                  label: 'YA',
                  score: 2,
                  currentScore: cp.score,
                  activeColor: primaryGreen,
                  onTap: () => setState(() => cp.score = 2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildAnswerPill(
                  label: 'N/A',
                  score: 1,
                  currentScore: cp.score,
                  activeColor: const Color(0xFF64748B),
                  onTap: () => setState(() => cp.score = 1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildAnswerPill(
                  label: 'TIDAK',
                  score: 0,
                  currentScore: cp.score,
                  activeColor: const Color(0xFFDC2626),
                  onTap: () => setState(() => cp.score = 0),
                ),
              ),
            ],
          ),

          // Jika TIDAK (Temuan K3): Tampilkan Box Upload Foto dan Catatan Perbaikan
          if (cp.score == 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 16),
                      SizedBox(width: 6),
                      Text('Temuan K3 - Wajib Sertakan Bukti Foto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFFB91C1C))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (cp.photo != null)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(cp.photo!, height: 120, width: double.infinity, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: InkWell(
                            onTap: () => setState(() => cp.photo = null),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    InkWell(
                      onTap: () => _pickImageForCheckpoint(cp),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFCA5A5), style: BorderStyle.solid),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt_rounded, color: Color(0xFFDC2626), size: 18),
                            SizedBox(width: 6),
                            Text('Ambil / Pilih Foto Bukti', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFFDC2626))),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      onChanged: (v) => cp.remark = v,
                      decoration: const InputDecoration(
                        hintText: 'Rencana tindakan perbaikan temuan ini...',
                        hintStyle: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                      ),
                      style: const TextStyle(fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomQuestionItem(_CustomQuestion cq) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF5FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9D5FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFF7C3AED), borderRadius: BorderRadius.circular(6)),
                child: const Text('KUSTOM', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(cq.question, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A))),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 18),
                onPressed: () => setState(() => _customQuestions.remove(cq)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildAnswerPill(
                  label: 'YA',
                  score: 2,
                  currentScore: cq.score,
                  activeColor: primaryGreen,
                  onTap: () => setState(() => cq.score = 2),
                ),
              ),
              if (cq.optionType == 3) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _buildAnswerPill(
                    label: 'N/A',
                    score: 1,
                    currentScore: cq.score,
                    activeColor: const Color(0xFF64748B),
                    onTap: () => setState(() => cq.score = 1),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Expanded(
                child: _buildAnswerPill(
                  label: 'TIDAK',
                  score: 0,
                  currentScore: cq.score,
                  activeColor: const Color(0xFFDC2626),
                  onTap: () => setState(() => cq.score = 0),
                ),
              ),
            ],
          ),
          if (cq.score == 0) ...[
            const SizedBox(height: 8),
            if (cq.photo != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(cq.photo!, height: 100, width: double.infinity, fit: BoxFit.cover),
              )
            else
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                  side: const BorderSide(color: Color(0xFFFCA5A5)),
                  minimumSize: const Size(double.infinity, 36),
                ),
                icon: const Icon(Icons.camera_alt_rounded, size: 16),
                label: const Text('Foto Bukti Temuan Kustom', style: TextStyle(fontSize: 11)),
                onPressed: () => _pickImageForCustomQuestion(cq),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnswerPill({
    required String label,
    required int score,
    required int currentScore,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    final isSel = currentScore == score;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSel ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSel ? activeColor : const Color(0xFFCBD5E1),
            width: isSel ? 1.5 : 1,
          ),
          boxShadow: isSel
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSel ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}

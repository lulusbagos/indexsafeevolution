import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../services/api.dart';
import '../../services/database.dart';
import '../../services/p5m_share_service.dart';
import '../../services/preference.dart';
import '../../services/sync.dart';
import '../../utils/enums.dart';
import '../../widgets/alert_app.dart';
import '../../widgets/snackbar_msg.dart';
import '../../widgets/top_bar.dart';

class P5MFormPage extends StatefulWidget {
  const P5MFormPage({this.editData, super.key});

  final Map<String, dynamic>? editData;

  @override
  State<P5MFormPage> createState() => _P5MFormPageState();
}

class _P5MFormPageState extends State<P5MFormPage> {
  final _scrollCtrl = ScrollController();
  final _db = DatabaseService();
  final _api = ApiService();
  final _profile = PreferenceService.getProfile();

  // Form Fields
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  int? _companyId;

  String _area = '';
  String _benchmark = '';
  final _lokasiCtrl = TextEditingController();
  final _detilLokasiCtrl = TextEditingController();
  final _topicCtrl = TextEditingController(text: 'K3 Operasional');
  final _titleCtrl = TextEditingController(text: 'P5M Awal Shift - Siap Bekerja');
  final _keteranganCtrl = TextEditingController();
  final _catatanCtrl = TextEditingController();

  String? _imagePath;
  bool _isSubmitting = false;

  // Area & Benchmark State (Hazard Concept)
  List<String> _masterAreas = [];
  List<String> _benchmarksList = [];
  bool _isLoadingAreas = false;
  bool _isLoadingBenchmarks = false;
  bool _isDetectingGps = false;
  VoidCallback? _onAreasLoadedModal;
  VoidCallback? _onBenchmarksLoadedModal;

  // Fit to Work 4 Official Questions
  final List<Map<String, dynamic>> _fitQuestions = [
    {
      'id': 1,
      'question': 'Apakah Anda dalam keadaan sehat ?',
      'label': 'Kesehatan Fisik',
      'answer': 'Yes', // 'Yes' or 'No'
    },
    {
      'id': 2,
      'question': 'Apakah Anda saat ini bebas dari masalah dan beban pikiran sebelum memulai aktivitas kerja ?',
      'label': 'Bebas Masalah & Beban Pikiran',
      'answer': 'Yes',
    },
    {
      'id': 3,
      'question': 'Apakah Anda cukup tidur (minimal 6 jam) sebelum memulai shift ?',
      'label': 'Kecukupan Tidur (Min. 6 Jam)',
      'answer': 'Yes',
    },
    {
      'id': 4,
      'question': 'Apakah Anda memakai APD lengkap dan layak pakai?',
      'label': 'APD Lengkap & Layak Pakai',
      'answer': 'Yes',
    },
  ];

  final List<String> _topicSuggestions = [
    'K3 Operasional',
    'Pekerjaan Umum',
    'P5M Shift Pagi',
    'P5M Shift Malam',
    'Pemeriksaan APD & Alat Kerja',
    'Keselamatan Berkendara & Traffic',
    'Housekeeping & Lingkungan Kerja',
  ];

  @override
  void initState() {
    super.initState();
    _companyId = _profile?.companyId ?? 1;

    if (widget.editData != null) {
      final d = widget.editData!;
      if (d['date'] != null && d['date'].toString().isNotEmpty) {
        final parsed = DateTime.tryParse(d['date'].toString());
        if (parsed != null) _date = parsed;
      }
      if (d['time'] != null && d['time'].toString().isNotEmpty) {
        try {
          final parts = d['time'].toString().split(':');
          if (parts.length >= 2) {
            _time = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
          }
        } catch (_) {}
      }
      _area = (d['area'] ?? d['area_name'])?.toString() ?? '';
      _benchmark = (d['lokasi'] ?? d['detil_lokasi'])?.toString() ?? '';
      _detilLokasiCtrl.text = _benchmark;
      _lokasiCtrl.text = (d['location_detail'] ?? d['lokasi'])?.toString() ?? '';
      _topicCtrl.text = (d['topik'] ?? d['topic_name'])?.toString() ?? 'K3 Operasional';
      _titleCtrl.text = (d['title'] ?? d['judul'])?.toString() ?? 'P5M Awal Shift - Siap Bekerja';
      _keteranganCtrl.text = (d['remark'] ?? d['keterangan'])?.toString() ?? '';
      _catatanCtrl.text = d['catatan']?.toString() ?? '';
      _imagePath = (d['image'] ?? d['foto_kegiatan'])?.toString();

      // Restore questions if available
      if (d['answers_json'] != null && d['answers_json'].toString().isNotEmpty) {
        try {
          final answers = jsonDecode(d['answers_json'].toString());
          if (answers is List && answers.length == _fitQuestions.length) {
            for (int i = 0; i < answers.length; i++) {
              _fitQuestions[i]['answer'] = answers[i]?.toString() ?? 'Yes';
            }
          }
        } catch (_) {}
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMasterAreas();
      if (_area.isNotEmpty) {
        _loadBenchmarksForArea(_area);
      }
      if (_lokasiCtrl.text.isEmpty) {
        _fetchCurrentGps(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _lokasiCtrl.dispose();
    _detilLokasiCtrl.dispose();
    _topicCtrl.dispose();
    _titleCtrl.dispose();
    _keteranganCtrl.dispose();
    _catatanCtrl.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------
  // GPS Detection
  // -------------------------------------------------------------
  Future<void> _fetchCurrentGps({bool silent = false}) async {
    if (!mounted) return;
    setState(() => _isDetectingGps = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        if (!silent && mounted) {
          SnackBarMsg.warning(context, 'Izin GPS tidak diberikan. Silakan aktifkan izin lokasi.');
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 7),
      );

      if (mounted) {
        final coord = '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}';
        setState(() {
          _lokasiCtrl.text = coord;
        });
        if (!silent) {
          SnackBarMsg.success(context, 'GPS berhasil dikunci: $coord');
        }
      }
    } catch (e) {
      debugPrint('[P5MForm] Error GPS: $e');
    } finally {
      if (mounted) setState(() => _isDetectingGps = false);
    }
  }

  // -------------------------------------------------------------
  // Master Areas (Hazard Concept)
  // -------------------------------------------------------------
  Future<void> _loadMasterAreas({VoidCallback? onDone}) async {
    if (mounted) setState(() => _isLoadingAreas = true);
    final companyId = _companyId ?? _profile?.companyId ?? 1;

    try {
      final sqldb = await _db.database;

      // 1. Read SQLite cache
      final localAreas = await sqldb.rawQuery(
        "SELECT DISTINCT area_utama FROM tbl_m_benchmark WHERE area_utama IS NOT NULL AND area_utama != '' AND area_utama NOT LIKE '%CAMP EKSPLORASI%' ORDER BY area_utama",
      );
      if (localAreas.isNotEmpty && mounted) {
        setState(() {
          _masterAreas = localAreas
              .map((e) => e['area_utama'].toString().trim())
              .where((s) => s.isNotEmpty && !s.toUpperCase().contains('CAMP EKSPLORASI'))
              .toSet()
              .toList()..sort();
        });
        onDone?.call();
        _onAreasLoadedModal?.call();
      }

      // 2. Fetch fresh areas from API
      final serverAreas = await _api.getMasterAreas(perusahaanId: companyId);
      if (serverAreas.isNotEmpty && mounted) {
        setState(() {
          _masterAreas = serverAreas.where((s) => !s.toUpperCase().contains('CAMP EKSPLORASI')).toList();
        });
        onDone?.call();
        _onAreasLoadedModal?.call();

        // Cache into SQLite
        final batch = sqldb.batch();
        for (final a in serverAreas) {
          batch.rawInsert(
            '''INSERT OR IGNORE INTO tbl_m_benchmark (perusahaan_id, area_utama, nama_benchmark, created_at)
               VALUES (?, ?, '', ?)''',
            [companyId, a, DateTime.now().toIso8601String()],
          );
        }
        await batch.commit(noResult: true);
      }
    } catch (e) {
      debugPrint('[P5MForm] Error loading master areas: $e');
    } finally {
      if (mounted) setState(() => _isLoadingAreas = false);
      onDone?.call();
      _onAreasLoadedModal?.call();
    }
  }

  Future<void> _addNewArea(String newArea) async {
    final cleanArea = newArea.trim().toUpperCase();
    if (cleanArea.isEmpty) return;

    final companyId = _companyId ?? _profile?.companyId ?? 1;
    final sqldb = await _db.database;
    await sqldb.rawInsert(
      '''INSERT INTO tbl_m_benchmark (perusahaan_id, area_utama, nama_benchmark, created_by_nik, created_by_name, created_at)
         VALUES (?, ?, '', ?, ?, ?)''',
      [
        companyId,
        cleanArea,
        _profile?.noNik ?? '',
        _profile?.namaLengkap ?? '',
        DateTime.now().toIso8601String(),
      ],
    );

    setState(() {
      if (!_masterAreas.contains(cleanArea)) {
        _masterAreas.add(cleanArea);
        _masterAreas.sort();
      }
      _area = cleanArea;
      _benchmark = '';
      _detilLokasiCtrl.text = '';
    });
    _loadBenchmarksForArea(cleanArea);
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
            _onAreasLoadedModal = () {
              if (modalCtx.mounted) setModalState(() {});
            };

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
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
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
                              style: TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Pilih area kerja atau cari lokasi tambang',
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
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
                        autofocus: false,
                        onChanged: (val) => setModalState(() => filter = val),
                        style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'Ketik untuk mencari area...',
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
                          Navigator.pop(modalCtx);
                          await _addNewArea(filter.trim());
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F3FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFDDD6FE)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D9488),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.add, color: Colors.white, size: 16),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Gunakan / Tambah Area Baru:',
                                      style: TextStyle(color: Colors.purple.shade700, fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      '"${filter.trim()}"',
                                      style: const TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF0D9488), size: 14),
                            ],
                          ),
                        ),
                      ),
                    ),

                  Expanded(
                    child: _isLoadingAreas && _masterAreas.isEmpty
                        ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF0D9488)))
                        : filtered.isEmpty && !canAddCustom
                            ? const Center(child: Text('Area tidak ditemukan', style: TextStyle(color: Color(0xFF94A3B8))))
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                itemBuilder: (context, index) {
                                  final item = filtered[index];
                                  final isSelected = item == _area;
                                  return ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    leading: Icon(
                                      Icons.place_rounded,
                                      color: isSelected ? const Color(0xFF0D9488) : const Color(0xFF94A3B8),
                                      size: 20,
                                    ),
                                    title: Text(
                                      item,
                                      style: TextStyle(
                                        color: isSelected ? const Color(0xFF0D9488) : const Color(0xFF1E293B),
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                    trailing: isSelected
                                        ? const Icon(Icons.check_circle_rounded, color: Color(0xFF0D9488), size: 20)
                                        : null,
                                    onTap: () {
                                      Navigator.pop(modalCtx);
                                      setState(() {
                                        _area = item;
                                        _benchmark = '';
                                        _detilLokasiCtrl.text = '';
                                      });
                                      _loadBenchmarksForArea(item);
                                    },
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

  // -------------------------------------------------------------
  // Benchmark / Lokasi Detail (Hazard Concept)
  // -------------------------------------------------------------
  Future<void> _loadBenchmarksForArea(String area, {VoidCallback? onDone}) async {
    final cleanArea = area.trim();
    if (cleanArea.isEmpty) {
      if (mounted) setState(() => _benchmarksList = []);
      return;
    }

    if (mounted) setState(() => _isLoadingBenchmarks = true);
    final companyId = _companyId ?? _profile?.companyId ?? 1;

    try {
      final sqldb = await _db.database;

      // 1. Read local SQLite benchmarks
      final localRows = await sqldb.rawQuery(
        "SELECT DISTINCT nama_benchmark FROM tbl_m_benchmark WHERE area_utama = ? AND nama_benchmark IS NOT NULL AND nama_benchmark != '' ORDER BY nama_benchmark",
        [cleanArea],
      );
      if (localRows.isNotEmpty && mounted) {
        setState(() {
          _benchmarksList = localRows
              .map((e) => e['nama_benchmark'].toString().trim())
              .where((s) => s.isNotEmpty)
              .toSet()
              .toList()..sort();
        });
        onDone?.call();
        _onBenchmarksLoadedModal?.call();
      }

      // 2. Fetch fresh benchmarks from API
      final serverBenchmarks = await _api.getBenchmarks(cleanArea, perusahaanId: companyId);
      if (serverBenchmarks.isNotEmpty && mounted) {
        setState(() {
          _benchmarksList = serverBenchmarks;
        });
        onDone?.call();
        _onBenchmarksLoadedModal?.call();

        final batch = sqldb.batch();
        for (final b in serverBenchmarks) {
          batch.rawInsert(
            '''INSERT OR IGNORE INTO tbl_m_benchmark (perusahaan_id, area_utama, nama_benchmark, created_at)
               VALUES (?, ?, ?, ?)''',
            [companyId, cleanArea, b, DateTime.now().toIso8601String()],
          );
        }
        await batch.commit(noResult: true);
      }
    } catch (e) {
      debugPrint('[P5MForm] Error loading benchmarks: $e');
    } finally {
      if (mounted) setState(() => _isLoadingBenchmarks = false);
      onDone?.call();
      _onBenchmarksLoadedModal?.call();
    }
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
            _onBenchmarksLoadedModal = () {
              if (modalCtx.mounted) setModalState(() {});
            };

            final filtered = _benchmarksList.where((b) => b.toLowerCase().contains(filter.toLowerCase())).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
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
                              const Text(
                                'Detail Lokasi / Benchmark',
                                style: TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Area: $_area',
                                style: const TextStyle(color: Color(0xFF0D9488), fontSize: 12, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
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
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        autofocus: false,
                        onChanged: (val) => setModalState(() => filter = val),
                        style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'Cari benchmark di area ini...',
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

                  Expanded(
                    child: _isLoadingBenchmarks && _benchmarksList.isEmpty
                        ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF0D9488)))
                        : filtered.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.explore_off_rounded, color: Color(0xFF94A3B8), size: 40),
                                      SizedBox(height: 10),
                                      Text(
                                        'Belum ada benchmark di area ini',
                                        style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                      ),
                                      SizedBox(height: 6),
                                      Text(
                                        'Gunakan tombol + untuk menambahkan titik lokasi baru.',
                                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                itemBuilder: (context, index) {
                                  final item = filtered[index];
                                  final isSelected = item == _benchmark;
                                  return ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    leading: Icon(
                                      Icons.explore_rounded,
                                      color: isSelected ? const Color(0xFF0D9488) : const Color(0xFF94A3B8),
                                      size: 20,
                                    ),
                                    title: Text(
                                      item,
                                      style: TextStyle(
                                        color: isSelected ? const Color(0xFF0D9488) : const Color(0xFF1E293B),
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                    trailing: isSelected
                                        ? const Icon(Icons.check_circle_rounded, color: Color(0xFF0D9488), size: 20)
                                        : null,
                                    onTap: () {
                                      Navigator.pop(modalCtx);
                                      setState(() {
                                        _benchmark = item;
                                        _detilLokasiCtrl.text = item;
                                      });
                                    },
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

  void _showAddBenchmarkDialog() {
    final textCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.add_location_alt_rounded, color: Color(0xFF0D9488), size: 20),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Tambah Benchmark',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Area: $_area', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0D9488))),
            const SizedBox(height: 12),
            TextField(
              controller: textCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'Nama titik benchmark / lokasi...',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final newName = textCtrl.text.trim().toUpperCase();
              if (newName.isEmpty) return;
              Navigator.pop(dlgCtx);

              final companyId = _companyId ?? _profile?.companyId ?? 1;
              final sqldb = await _db.database;
              await sqldb.rawInsert(
                '''INSERT INTO tbl_m_benchmark (perusahaan_id, area_utama, nama_benchmark, created_by_nik, created_by_name, created_at)
                   VALUES (?, ?, ?, ?, ?, ?)''',
                [
                  companyId,
                  _area,
                  newName,
                  _profile?.noNik ?? '',
                  _profile?.namaLengkap ?? '',
                  DateTime.now().toIso8601String(),
                ],
              );

              // Push to backend API
              try {
                await _api.createBenchmark(
                  areaUtama: _area,
                  namaBenchmark: newName,
                  perusahaanId: _profile?.companyId ?? 1,
                  createdByNik: _profile?.noNik ?? 'USER',
                  createdByName: _profile?.namaLengkap ?? 'User Mobile',
                );
              } catch (_) {}

              setState(() {
                if (!_benchmarksList.contains(newName)) {
                  _benchmarksList.add(newName);
                  _benchmarksList.sort();
                }
                _benchmark = newName;
                _detilLokasiCtrl.text = newName;
              });

              if (mounted) {
                SnackBarMsg.success(context, 'Benchmark "$newName" berhasil ditambahkan.');
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // Photo Picker
  // -------------------------------------------------------------
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1280,
      );
      if (picked != null) {
        setState(() => _imagePath = picked.path);
      }
    } catch (e) {
      debugPrint('[P5MForm] Error picking image: $e');
    }
  }

  // -------------------------------------------------------------
  // Premium Photo Evidence Helpers
  // -------------------------------------------------------------
  Widget _buildPhotoEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF8FAFC), Color(0xFFF0FDFA)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCCFBF1), width: 1.2),
      ),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF14B8A6), Color(0xFF0D9488)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(Icons.add_a_photo_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 12),
          const Text(
            'Lampirkan Foto Briefing Awal Shift',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              'Ambil foto kru/pekerja di lokasi kerja dengan APD lengkap atau pilih foto dari galeri ponsel.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.35),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _pickImage(ImageSource.camera),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0D9488).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_camera_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Buka Kamera',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _pickImage(ImageSource.gallery),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.1),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_library_rounded, color: Color(0xFF0D9488), size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Pilih Galeri',
                            style: TextStyle(
                              color: Color(0xFF334155),
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoPreviewCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              // Photo Image with Tap to Zoom
              InkWell(
                onTap: _showFullScreenPhoto,
                child: Container(
                  width: double.infinity,
                  height: 220,
                  color: const Color(0xFF0F172A),
                  child: _buildImageWidget(_imagePath!),
                ),
              ),

              // Top Scrim with Action Pills
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.65),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24, width: 0.8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_user_rounded, color: Color(0xFF2DD4BF), size: 13),
                            SizedBox(width: 5),
                            Text(
                              'Bukti Briefing P5M',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Change Photo Button
                      InkWell(
                        onTap: _showChangePhotoModal,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.cameraswitch_rounded, color: Color(0xFF0D9488), size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Ganti',
                                style: TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Delete Photo Button
                      InkWell(
                        onTap: () => setState(() => _imagePath = null),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 15),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Scrim with Zoom Indicator
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.75),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.zoom_in_rounded, color: Colors.white70, size: 15),
                      const SizedBox(width: 6),
                      const Text(
                        'Ketuk foto untuk memperbesar tampilan',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                      const Spacer(),
                      Text(
                        DateFormat('dd/MM HH:mm').format(DateTime.now()),
                        style: const TextStyle(color: Colors.white70, fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 14),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Foto berhasil dilampirkan & siap disinkronkan ke server SAP.',
                  style: TextStyle(color: Color(0xFF15803D), fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageWidget(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _buildImageError(),
      );
    }
    final file = File(path);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _buildImageError(),
      );
    }
    final remoteUrl = path.startsWith('/')
        ? '${_api.baseUrl}$path'
        : '${_api.baseUrl}/uploads/$path';
    return Image.network(
      remoteUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => _buildImageError(),
    );
  }

  Widget _buildImageError() {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_rounded, color: Color(0xFF94A3B8), size: 36),
            SizedBox(height: 6),
            Text(
              'Gagal memuat pratinjau gambar',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePhotoModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_a_photo_rounded, color: Color(0xFF0D9488), size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Ubah Foto Briefing P5M',
                    style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.photo_camera_rounded, color: Color(0xFF0D9488), size: 20),
              ),
              title: const Text('Ambil Foto Baru (Kamera)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              subtitle: const Text('Gunakan kamera langsung di lokasi kerja', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
              trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            const SizedBox(height: 6),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.photo_library_rounded, color: Color(0xFF475569), size: 20),
              ),
              title: const Text('Pilih dari Galeri', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              subtitle: const Text('Pilih foto dokumentasi yang sudah tersimpan', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
              trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFullScreenPhoto() {
    if (_imagePath == null || _imagePath!.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _buildImageWidget(_imagePath!),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: InkWell(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black87,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // Form Submission
  // -------------------------------------------------------------
  Future<void> _submitForm() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final chosenDate = DateTime(_date.year, _date.month, _date.day);
    if (chosenDate.isBefore(today)) {
      SnackBarMsg.warning(context, 'Tanggal P5M tidak boleh backdate (kurang dari hari ini).');
      return;
    }

    if (_area.isEmpty) {
      SnackBarMsg.warning(context, 'Area Utama wajib dipilih.');
      return;
    }
    if (_titleCtrl.text.trim().isEmpty) {
      SnackBarMsg.warning(context, 'Judul P5M wajib diisi.');
      return;
    }

    final hasUnfit = _fitQuestions.any((q) => q['answer'] == 'No');
    final isFit = !hasUnfit;

    setState(() => _isSubmitting = true);

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_date);
      final timeStr = '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';
      final isEdit = widget.editData != null;
      final editId = isEdit ? (widget.editData!['id'] as int) : 0;
      final code = isEdit
          ? (widget.editData!['code']?.toString() ?? 'P5M-${_profile?.noNik ?? '0000'}-${now.millisecondsSinceEpoch}')
          : 'P5M-${_profile?.noNik ?? '0000'}-${now.millisecondsSinceEpoch}'.toUpperCase();

      final questionsList = _fitQuestions.map((e) => e['question'].toString()).toList();
      final answersList = _fitQuestions.map((e) => e['answer'].toString()).toList();

      final p5mMap = <String, dynamic>{
        'code': code,
        'title': _titleCtrl.text.trim(),
        'area': _area,
        'lokasi': _detilLokasiCtrl.text.trim().isNotEmpty ? _detilLokasiCtrl.text.trim() : _lokasiCtrl.text.trim(),
        'location_detail': _lokasiCtrl.text.trim(),
        'topik': _topicCtrl.text.trim(),
        'judul': _titleCtrl.text.trim(),
        'remark': _keteranganCtrl.text.trim().isNotEmpty ? _keteranganCtrl.text.trim() : '.',
        'catatan': _catatanCtrl.text.trim(),
        'date': dateStr,
        'time': timeStr,
        'image': _imagePath,
        'foto_kegiatan': _imagePath,
        'status': isFit ? 1 : 0,
        'fit_status': isFit ? 'FIT TO WORK' : 'UNFIT',
        'questions_json': jsonEncode(questionsList),
        'answers_json': jsonEncode(answersList),
        'company_id': _companyId ?? _profile?.companyId ?? 1,
        'employee_id': _profile?.id ?? 0,
        'nik': _profile?.noNik ?? '',
        'nama': _profile?.namaLengkap ?? '',
        'updated_at': now.toString(),
      };

      int tranId = editId;
      if (isEdit) {
        await _db.update('p5m_trans', p5mMap, editId);
      } else {
        p5mMap['created_at'] = now.toString();
        tranId = await _db.insert('p5m_trans', p5mMap);
      }

      if (tranId > 0) {
        // 2. Manage detail rows in SQLite p5m_details
        final sqldb = await _db.database;
        await sqldb.delete('p5m_details', where: 'tran_id = ?', whereArgs: [tranId]);

        for (var q in _fitQuestions) {
          await _db.insert('p5m_details', {
            'tran_id': tranId,
            'name': q['question'],
            'type': 'detail',
            'status': q['answer'] == 'Yes' ? 1 : 0,
            'yesno': q['answer'] == 'Yes' ? 1 : 0,
            'remark': q['label'],
            'created_at': now.toString(),
            'updated_at': now.toString(),
          });
        }

        // 3. Trigger immediate sync
        final synced = await syncTran(_db, _api, 'p5m', tranId);
        if (!mounted) return;

        if (isEdit) {
          SnackBarMsg.success(context, 'Laporan P5M berhasil diperbarui!');
          Navigator.pop(context);
        } else {
          if (synced) {
            SnackBarMsg.success(context, 'Laporan P5M berhasil disinkronkan ke server!');
          } else {
            SnackBarMsg.info(context, 'Tersimpan lokal di HP. Akan disinkron otomatis saat online.');
          }

          // 4. Show success & options to share
          p5mMap['id'] = tranId;
          _showPostSubmitShareDialog(p5mMap);
        }
      } else {
        if (mounted) alertFailed(context, Module.p5m);
      }
    } catch (e) {
      debugPrint('[P5MForm] Submit error: $e');
      if (mounted) alertFailed(context, Module.p5m);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showPostSubmitShareDialog(Map<String, dynamic> data) {
    final eval = P5mShareService.evaluateFitStatus(data);
    final isFit = eval['isFit'] as bool;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isFit ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFit ? Icons.check_circle_rounded : Icons.warning_rounded,
                color: isFit ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                size: 38,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Laporan P5M Berhasil!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              isFit ? 'STATUS: FIT TO WORK (SIAP BEKERJA)' : 'STATUS: UNFIT (PERLU TINDAK LANJUT)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isFit ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: const Text(
          'Laporan briefing dan kesiapan kerja Anda telah berhasil dicatat. Apakah Anda ingin langsung membagikan hasil laporan?',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          textAlign: TextAlign.center,
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.pop(dlgCtx);
                    Navigator.pop(context);
                  },
                  child: const Text('Selesai', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: const Text('Bagikan', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.pop(dlgCtx);
                    Navigator.pop(context);
                    P5mShareService.showShareModal(context, data);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // Build UI
  // -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final hasUnfit = _fitQuestions.any((q) => q['answer'] == 'No');
    final isFit = !hasUnfit;

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: TopBar(title: widget.editData != null ? 'Edit Fit to Work & P5M' : 'Fit to Work & P5M', back: 1),
        body: SingleChildScrollView(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Banner Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D9488), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.health_and_safety_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.editData != null ? 'Edit P5M & Kelayakan Kerja' : 'P5M & Kelayakan Kerja',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Pertemuan 5 Menit & Pemeriksaan Kesiapan Kerja sebelum shift operasional dimulai.',
                            style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // SECTION 1: WAKTU PELAKSANAAN & DATA PEKERJA
              _buildSectionHeader('1. WAKTU PELAKSANAAN & DATA PEKERJA', Icons.schedule_rounded),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final now = DateTime.now();
                        final today = DateTime(now.year, now.month, now.day);
                        final initial = _date.isBefore(today) ? today : _date;
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: initial,
                          firstDate: today, // Tidak bisa backdate!
                          lastDate: DateTime(now.year + 2),
                        );
                        if (picked != null) setState(() => _date = picked);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, color: Color(0xFF0D9488), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                DateFormat('dd MMM yyyy').format(_date),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _time,
                        );
                        if (picked != null) setState(() => _time = picked);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time_rounded, color: Color(0xFF0D9488), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Info Identitas & Perusahaan Terdeteksi Otomatis dari Akun Login (Tanpa Perlu Memilih Manual)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFF0D9488).withValues(alpha: 0.15),
                      child: const Icon(Icons.person_pin_rounded, color: Color(0xFF0D9488), size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _profile?.namaLengkap ?? 'Pekerja Lapangan',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D9488),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Terdeteksi dari Login',
                                  style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'NIK: ${_profile?.noNik ?? "-"} • ${_profile?.depart ?? _profile?.posisi ?? "Operasional"}',
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.business_rounded, size: 14, color: Color(0xFF0D9488)),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  _profile?.company ?? 'PT INDEXIM COALINDO',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0D9488)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // SECTION 2: LOKASI KERJA (HAZARD CONCEPT)
              _buildSectionHeader('2. LOKASI KERJA (AREA UTAMA & BENCHMARK)', Icons.location_on_rounded),
              const SizedBox(height: 10),

              // Area Utama Field
              const Text('AREA UTAMA *', style: TextStyle(color: Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              const SizedBox(height: 6),
              InkWell(
                onTap: _showAreaPickerModal,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _area.isNotEmpty ? const Color(0xFFDDD6FE) : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.place_rounded, color: Color(0xFF0D9488), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _area.isNotEmpty ? _area : 'KETIK UNTUK MENCARI AREA...',
                          style: TextStyle(
                            color: _area.isNotEmpty ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                            fontSize: 13,
                            fontWeight: _area.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (_isLoadingAreas)
                        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D9488)))
                      else
                        const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 20),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Detail Lokasi / Benchmark Field
              const Text('DETAIL LOKASI / BENCHMARK', style: TextStyle(color: Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        if (_area.isEmpty) {
                          SnackBarMsg.warning(context, 'Pilih Area Utama terlebih dahulu.');
                          return;
                        }
                        _showBenchmarkPickerModal();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.explore_rounded, color: Color(0xFF0D9488), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _area.isEmpty
                                    ? 'PILIH AREA UTAMA DULU...'
                                    : (_detilLokasiCtrl.text.isNotEmpty
                                        ? _detilLokasiCtrl.text
                                        : 'PILIH ATAU CARI BENCHMARK...'),
                                style: TextStyle(
                                  color: _detilLokasiCtrl.text.isNotEmpty ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                  fontSize: 13,
                                  fontWeight: _detilLokasiCtrl.text.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (_isLoadingBenchmarks)
                              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D9488)))
                            else
                              const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      if (_area.isEmpty) {
                        SnackBarMsg.warning(context, 'Pilih Area Utama terlebih dahulu.');
                        return;
                      }
                      _showAddBenchmarkDialog();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0D9488).withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.add_location_alt_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Lokasi Spesifik / GPS
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('KOORDINAT GPS / LOKASI SPESIFIK', style: TextStyle(color: Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  Row(
                    children: [
                      Icon(
                        _lokasiCtrl.text.isNotEmpty ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded,
                        size: 13,
                        color: _lokasiCtrl.text.isNotEmpty ? const Color(0xFF10B981) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _lokasiCtrl.text.isNotEmpty ? 'Satelit Terkunci' : 'Auto-Deteksi',
                        style: TextStyle(
                          color: _lokasiCtrl.text.isNotEmpty ? const Color(0xFF10B981) : const Color(0xFF64748B),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _lokasiCtrl.text.isNotEmpty ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.my_location_rounded,
                      color: _lokasiCtrl.text.isNotEmpty ? const Color(0xFF16A34A) : const Color(0xFF0D9488),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _lokasiCtrl,
                        style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Titik koordinat GPS...',
                          hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        ),
                      ),
                    ),
                    if (_isDetectingGps)
                      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D9488)))
                    else
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0D9488), size: 20),
                        onPressed: () => _fetchCurrentGps(silent: false),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // SECTION 3: MATERI P5M
              _buildSectionHeader('3. TOPIK & MATERI BRIEFING P5M', Icons.record_voice_over_rounded),
              const SizedBox(height: 10),

              const Text('TOPIK P5M', style: TextStyle(color: Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _topicCtrl,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.campaign_rounded, color: Color(0xFF0D9488), size: 20),
                    suffixIcon: PopupMenuButton<String>(
                      icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF64748B)),
                      onSelected: (val) => setState(() => _topicCtrl.text = val),
                      itemBuilder: (context) => _topicSuggestions.map((t) => PopupMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              const Text('JUDUL BRIEFING P5M *', style: TextStyle(color: Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _titleCtrl,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.title_rounded, color: Color(0xFF0D9488), size: 20),
                    border: InputBorder.none,
                    hintText: 'Judul pertemuan...',
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              const Text('KETERANGAN / RINGKASAN MATERI', style: TextStyle(color: Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _keteranganCtrl,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.notes_rounded, color: Color(0xFF0D9488), size: 20),
                    border: InputBorder.none,
                    hintText: 'Poin utama materi keselamatan yang disampaikan...',
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // SECTION 4: CHECKLIST FIT TO WORK
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionHeader('4. CHECKLIST KESIAPAN KERJA (FIT TO WORK)', Icons.health_and_safety_rounded),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isFit ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isFit ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isFit ? Icons.check_circle_rounded : Icons.cancel_rounded,
                          size: 13,
                          color: isFit ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isFit ? 'FIT TO WORK' : 'UNFIT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isFit ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Questions List
              ..._fitQuestions.asMap().entries.map((entry) {
                final idx = entry.key;
                final q = entry.value;
                final isAnswerYes = q['answer'] == 'Yes';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isAnswerYes ? const Color(0xFFE2E8F0) : const Color(0xFFFCA5A5),
                      width: isAnswerYes ? 1 : 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: Text(
                                '${idx + 1}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0D9488)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              q['question'],
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          // YES Button
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => q['answer'] = 'Yes'),
                              borderRadius: BorderRadius.circular(10),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: isAnswerYes ? const Color(0xFF10B981) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isAnswerYes ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 16,
                                      color: isAnswerYes ? Colors.white : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'YES (SEHAT)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isAnswerYes ? Colors.white : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // NO Button
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => q['answer'] = 'No'),
                              borderRadius: BorderRadius.circular(10),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: !isAnswerYes ? const Color(0xFFEF4444) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: !isAnswerYes ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.cancel_rounded,
                                      size: 16,
                                      color: !isAnswerYes ? Colors.white : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'NO (UNFIT)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: !isAnswerYes ? Colors.white : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 12),

              // SECTION 5: CATATAN & FOTO
              _buildSectionHeader('5. CATATAN & FOTO KEGIATAN', Icons.camera_alt_rounded),
              const SizedBox(height: 10),

              const Text('CATATAN / TINDAKAN PENCEGAHAN', style: TextStyle(color: Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _catatanCtrl,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF0D9488), size: 20),
                    border: InputBorder.none,
                    hintText: 'Tindakan atau arahan keselamatan tambahan...',
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // CARD FOTO BUKTI BRIEFING P5M (PREMIUM EXECUTIVE CARD)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (_imagePath != null && _imagePath!.isNotEmpty)
                        ? const Color(0xFF0D9488).withValues(alpha: 0.3)
                        : const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Card Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Color(0xFF0D9488),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Foto Bukti Briefing P5M',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Wajib melampirkan dokumentasi tim saat briefing',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: (_imagePath != null && _imagePath!.isNotEmpty)
                                  ? const Color(0xFFECFDF5)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: (_imagePath != null && _imagePath!.isNotEmpty)
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFCBD5E1),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  (_imagePath != null && _imagePath!.isNotEmpty)
                                      ? Icons.check_circle_rounded
                                      : Icons.info_outline_rounded,
                                  size: 12,
                                  color: (_imagePath != null && _imagePath!.isNotEmpty)
                                      ? const Color(0xFF059669)
                                      : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  (_imagePath != null && _imagePath!.isNotEmpty)
                                      ? 'Terlampir'
                                      : 'Wajib Ada',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: (_imagePath != null && _imagePath!.isNotEmpty)
                                        ? const Color(0xFF059669)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 1, color: Color(0xFFF1F5F9)),

                    // Card Content
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: (_imagePath != null && _imagePath!.isNotEmpty)
                          ? _buildPhotoPreviewCard()
                          : _buildPhotoEmptyState(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_rounded),
                label: Text(
                  _isSubmitting ? 'MENYIMPAN LAPORAN...' : 'SIMPAN BRIEFING P5M',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                onPressed: _isSubmitting ? null : _submitForm,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF0D9488)),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

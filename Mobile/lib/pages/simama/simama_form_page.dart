import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../services/api.dart';
import '../../services/database.dart';
import '../../services/preference.dart';
import '../../services/sync.dart';
import '../../utils/enums.dart';
import '../../widgets/alert_app.dart';
import '../../widgets/button_app.dart';
import '../../widgets/sap_form_widgets.dart';
import '../../widgets/snackbar_msg.dart';
import '../../widgets/top_bar.dart';

class SimamaChecklistItem {
  final int id;
  final String category;
  final String title;
  final String hint;
  bool? isOk; // true: Sesuai, false: Temuan
  String findingRemark;

  SimamaChecklistItem({
    required this.id,
    required this.category,
    required this.title,
    required this.hint,
    this.isOk = true,
    this.findingRemark = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'title': title,
        'isOk': isOk,
        'findingRemark': findingRemark,
      };
}

class SimamaFormPage extends StatefulWidget {
  const SimamaFormPage(this.module, {this.editData, super.key});

  final Module module;
  final Map<String, dynamic>? editData;

  @override
  State<SimamaFormPage> createState() => _SimamaFormPageState();
}

class _SimamaFormPageState extends State<SimamaFormPage> {
  final _scrollCtrl = ScrollController();
  final _db = DatabaseService();
  final _api = ApiService();
  final _profile = PreferenceService.getProfile();
  final _picker = ImagePicker();

  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();

  final _timPendampingCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _lokasiCtrl = TextEditingController();
  final _detilLokasiCtrl = TextEditingController();
  final _catatanCtrl = TextEditingController();

  String _area = '';
  List<String> _masterAreas = [];
  List<String> _benchmarksList = [];
  bool _isLoadingAreas = false;
  bool _isLoadingBenchmarks = false;
  VoidCallback? _onAreasLoadedModal;
  VoidCallback? _onBenchmarksLoadedModal;

  double? _latitude;
  double? _longitude;
  double? _gpsAccuracy;
  bool _isDetectingGps = false;

  File? _imageFile;
  String? _existingImageUrl;
  bool _isSubmitting = false;

  // 6 Core Night Inspection Pillars (10 Standard Checkpoints)
  final List<SimamaChecklistItem> _checkpoints = [
    SimamaChecklistItem(
      id: 1,
      category: 'Kebugaran & Anti-Fatigue Pekerja',
      title: 'Kebugaran Fisik & Kewaspadaan (Anti-Fatigue)',
      hint:
          'Pekerja tidak mengantuk, fit to work, dan siap bekerja shift malam.',
      isOk: true,
    ),
    SimamaChecklistItem(
      id: 2,
      category: 'Kebugaran & Anti-Fatigue Pekerja',
      title: 'Fasilitas Rest Area & Minuman Hangat',
      hint:
          'Fasilitas rest room / crib room bersih, air minum & fasilitas hangat tersedia.',
      isOk: true,
    ),
    SimamaChecklistItem(
      id: 3,
      category: 'Penerangan & Pencahayaan Lapangan',
      title: 'Pencahayaan Area Kerja Aktif',
      hint:
          'Pencahayaan mencukupi di area kerja aktif, disposal, dan front loading.',
      isOk: true,
    ),
    SimamaChecklistItem(
      id: 4,
      category: 'Penerangan & Pencahayaan Lapangan',
      title: 'Fungsi & Posisi Tower Lamp',
      hint:
          'Tower lamp berfungsi optimal, terarah baik, dan tidak menyilaukan operator.',
      isOk: true,
    ),
    SimamaChecklistItem(
      id: 5,
      category: 'Kelayakan Sarana & Komunikasi',
      title: 'Sistem Penerangan & Lampu Unit',
      hint:
          'Lampu kerja, lampu mundur, dan rotary lamp unit kendaraan menyala normal.',
      isOk: true,
    ),
    SimamaChecklistItem(
      id: 6,
      category: 'Kelayakan Sarana & Komunikasi',
      title: 'Komunikasi Radio Dua Arah (Two-Way Radio)',
      hint:
          'Saluran radio komunikasi aktif dan respon channel shift malam jelas.',
      isOk: true,
    ),
    SimamaChecklistItem(
      id: 7,
      category: 'Visibilitas & Kepatuhan APD Malam',
      title: 'Rompi & Scotlite Reflektif (High-Visibility)',
      hint:
          'Pekerja mengenakan rompi/seragam dengan scotlite reflektif yang memantulkan cahaya.',
      isOk: true,
    ),
    SimamaChecklistItem(
      id: 8,
      category: 'Visibilitas & Kepatuhan APD Malam',
      title: 'Kelengkapan APD Standar Shift Malam',
      hint:
          'APD wajib (helm, sepatu safety, kacamata malam/bening) dipakai dengan benar.',
      isOk: true,
    ),
    SimamaChecklistItem(
      id: 9,
      category: 'Jalan Angkut & Tanggul Pengaman',
      title: 'Patok Delineator & Reflektor Jalan',
      hint:
          'Patok delineator / reflektor haul road terlihat jelas dan tidak tertimbun lumpur/debu.',
      isOk: true,
    ),
    SimamaChecklistItem(
      id: 10,
      category: 'Pengawasan Lapangan Shift Malam',
      title: 'Keberadaan & Patroli Pengawas Lapangan',
      hint:
          'Pengawas operasional / Foreman standby aktif melakukan kontrol keselamatan di lapangan.',
      isOk: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initFormData();
    _loadAreasFromMaster();
    if (_area.isNotEmpty) {
      _loadBenchmarksForArea(_area);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_lokasiCtrl.text.isEmpty) {
        _fetchCurrentGps(silent: true);
      }
    });
  }

  void _initFormData() {
    if (widget.editData != null) {
      final d = widget.editData!;
      if (d['date'] != null && d['date'].toString().isNotEmpty) {
        _date = DateTime.tryParse(d['date'].toString()) ?? DateTime.now();
      }
      if (d['time'] != null && d['time'].toString().isNotEmpty) {
        try {
          final parts = d['time'].toString().split(':');
          if (parts.length >= 2) {
            _time = TimeOfDay(
                hour: int.parse(parts[0]), minute: int.parse(parts[1]));
          }
        } catch (_) {}
      }
      _area = d['area']?.toString() ?? '';
      _areaCtrl.text = _area;
      _lokasiCtrl.text = d['lokasi']?.toString() ?? '';
      _detilLokasiCtrl.text =
          (d['location_detail'] ?? d['detil_lokasi'])?.toString() ?? '';
      _timPendampingCtrl.text = d['pja']?.toString() ?? '';
      _catatanCtrl.text = d['remark']?.toString() ?? '';
      _existingImageUrl = d['image']?.toString();

      // Restore checkpoints from payload_json if available
      if (d['payload_json'] != null &&
          d['payload_json'].toString().isNotEmpty) {
        try {
          final payload = jsonDecode(d['payload_json'].toString()) as Map;
          if (payload['checkpoints'] is List) {
            final savedList = payload['checkpoints'] as List;
            for (var saved in savedList) {
              if (saved is Map) {
                final id = saved['id'];
                final item = _checkpoints.firstWhere((c) => c.id == id,
                    orElse: () => _checkpoints.first);
                if (saved.containsKey('isOk')) {
                  item.isOk = saved['isOk'] == true;
                }
                if (saved.containsKey('findingRemark')) {
                  item.findingRemark = saved['findingRemark']?.toString() ?? '';
                }
              }
            }
          }
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _timPendampingCtrl.dispose();
    _areaCtrl.dispose();
    _lokasiCtrl.dispose();
    _detilLokasiCtrl.dispose();
    _catatanCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAreasFromMaster({VoidCallback? onDone}) async {
    if (mounted) setState(() => _isLoadingAreas = true);
    final companyId = _profile?.companyId ?? 1;

    try {
      final sqldb = await _db.database;

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

      await sqldb.execute(
          "DELETE FROM tbl_m_benchmark WHERE area_utama LIKE '%CAMP EKSPLORASI%' OR nama_benchmark = 'CAMP EKSPLORASI BLOCK CENTRAL'");

      final localAreas = await sqldb.rawQuery(
        "SELECT DISTINCT area_utama FROM tbl_m_benchmark WHERE area_utama IS NOT NULL AND area_utama != '' AND area_utama NOT LIKE '%CAMP EKSPLORASI%' ORDER BY area_utama",
      );
      if (localAreas.isNotEmpty && mounted) {
        setState(() {
          _masterAreas = localAreas
              .map((e) => e['area_utama'].toString().trim())
              .where((s) =>
                  s.isNotEmpty && !s.toUpperCase().contains('CAMP EKSPLORASI'))
              .toSet()
              .toList()
            ..sort();
        });
        onDone?.call();
        _onAreasLoadedModal?.call();
      }

      final serverAreas = await _api.getMasterAreas(perusahaanId: companyId);
      if (serverAreas.isNotEmpty && mounted) {
        setState(() {
          _masterAreas = serverAreas
              .where((s) => !s.toUpperCase().contains('CAMP EKSPLORASI'))
              .toList();
        });
        onDone?.call();
        _onAreasLoadedModal?.call();

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
      debugPrint('[SimamaFormPage] Error loading areas: $e');
    } finally {
      if (mounted) setState(() => _isLoadingAreas = false);
      onDone?.call();
      _onAreasLoadedModal?.call();
    }
  }

  Future<void> _loadBenchmarksForArea(String area,
      {VoidCallback? onDone}) async {
    final cleanArea = area.trim();
    if (cleanArea.isEmpty) {
      if (mounted) {
        setState(() {
          _benchmarksList = [];
          _isLoadingBenchmarks = false;
        });
      }
      onDone?.call();
      _onBenchmarksLoadedModal?.call();
      return;
    }

    if (mounted) setState(() => _isLoadingBenchmarks = true);
    final companyId = _profile?.companyId ?? 1;

    try {
      final sqldb = await _db.database;

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
              .toList()
            ..sort();
        });
        onDone?.call();
        _onBenchmarksLoadedModal?.call();
      }

      final serverBenchmarks =
          await _api.getBenchmarks(cleanArea, perusahaanId: companyId);
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
      debugPrint('[SimamaFormPage] Error loading benchmarks: $e');
    } finally {
      if (mounted) setState(() => _isLoadingBenchmarks = false);
      onDone?.call();
      _onBenchmarksLoadedModal?.call();
    }
  }

  void _showAreaPickerModal() {
    const primaryPurple = Color(0xFF6D28D9);
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

            if (_masterAreas.isEmpty && !_isLoadingAreas) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _loadAreasFromMaster();
              });
            }

            final filtered = _masterAreas
                .where((a) => a.toLowerCase().contains(filter.toLowerCase()))
                .toList();
            final hasExactMatch = _masterAreas
                .any((a) => a.toLowerCase() == filter.trim().toLowerCase());
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
                              'Pilih atau ketik untuk mencari & menambah area',
                              style: TextStyle(
                                  color: Color(0xFF64748B), fontSize: 12),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(modalCtx),
                          icon: const Icon(Icons.close_rounded,
                              color: Color(0xFF64748B)),
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
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'Ketik untuk mencari area...',
                          hintStyle: const TextStyle(
                              color: Color(0xFF94A3B8), fontSize: 13),
                          prefixIcon: const Icon(Icons.search_rounded,
                              color: Color(0xFF64748B)),
                          suffixIcon: filter.isNotEmpty
                              ? IconButton(
                                  icon:
                                      const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () =>
                                      setModalState(() => filter = ''),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (canAddCustom)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 4),
                      child: InkWell(
                        onTap: () async {
                          Navigator.pop(modalCtx);
                          await _addNewArea(filter.trim());
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
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
                                  color: primaryPurple,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.add,
                                    color: Colors.white, size: 16),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Gunakan / Tambah Area Baru:',
                                      style: TextStyle(
                                          color: primaryPurple,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600),
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
                              const Icon(Icons.arrow_forward_ios_rounded,
                                  color: primaryPurple, size: 14),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: _isLoadingAreas && _masterAreas.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5, color: primaryPurple),
                                ),
                                SizedBox(height: 14),
                                Text(
                                  'Memuat daftar area...',
                                  style: TextStyle(
                                      color: Color(0xFF64748B), fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : filtered.isEmpty && !canAddCustom
                            ? const Center(
                                child: Text('Area tidak ditemukan',
                                    style: TextStyle(color: Color(0xFF94A3B8))),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 8),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const Divider(
                                    height: 1, color: Color(0xFFF1F5F9)),
                                itemBuilder: (context, index) {
                                  final item = filtered[index];
                                  final isSelected = item == _area;
                                  return ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    leading: Icon(
                                      Icons.place_rounded,
                                      color: isSelected
                                          ? primaryPurple
                                          : const Color(0xFF94A3B8),
                                      size: 20,
                                    ),
                                    title: Text(
                                      item,
                                      style: TextStyle(
                                        color: isSelected
                                            ? primaryPurple
                                            : const Color(0xFF1E293B),
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                    trailing: isSelected
                                        ? const Icon(Icons.check_circle_rounded,
                                            color: primaryPurple, size: 20)
                                        : null,
                                    onTap: () {
                                      Navigator.pop(modalCtx);
                                      setState(() {
                                        _area = item;
                                        _areaCtrl.text = item;
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

  Future<void> _addNewArea(String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;

    final userNik = _profile?.noNik ?? 'USER';
    final userName = _profile?.namaLengkap ?? 'User Mobile';

    setState(() {
      if (!_masterAreas.contains(cleanName)) {
        _masterAreas.add(cleanName);
        _masterAreas.sort();
      }
      _area = cleanName;
      _areaCtrl.text = cleanName;
      _detilLokasiCtrl.text = '';
      _benchmarksList = [];
    });

    try {
      final sqldb = await _db.database;
      await sqldb.rawInsert(
        '''INSERT INTO tbl_m_benchmark (perusahaan_id, area_utama, nama_benchmark, created_by_nik, created_by_name, created_at)
           VALUES (?, ?, '', ?, ?, ?)''',
        [
          _profile?.companyId ?? 1,
          cleanName,
          userNik,
          userName,
          DateTime.now().toIso8601String()
        ],
      );
    } catch (_) {}

    try {
      await _api.createArea(
        namaArea: cleanName,
        createdByNik: userNik,
        createdByName: userName,
      );
      if (mounted) {
        SnackBarMsg.success(context, 'Area "$cleanName" berhasil ditambahkan!');
      }
    } catch (_) {}

    _loadBenchmarksForArea(cleanName);
  }

  void _showBenchmarkPickerModal() {
    const primaryPurple = Color(0xFF6D28D9);
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

            if (_benchmarksList.isEmpty &&
                !_isLoadingBenchmarks &&
                _area.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _loadBenchmarksForArea(_area);
              });
            }

            final filtered = _benchmarksList
                .where((b) => b.toLowerCase().contains(filter.toLowerCase()))
                .toList();
            final hasExactMatch = _benchmarksList
                .any((b) => b.toLowerCase() == filter.trim().toLowerCase());
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
                                style: const TextStyle(
                                    color: primaryPurple,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(modalCtx),
                          icon: const Icon(Icons.close_rounded,
                              color: Color(0xFF64748B)),
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
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'Ketik untuk mencari benchmark...',
                          hintStyle: const TextStyle(
                              color: Color(0xFF94A3B8), fontSize: 13),
                          prefixIcon: const Icon(Icons.search_rounded,
                              color: Color(0xFF64748B)),
                          suffixIcon: filter.isNotEmpty
                              ? IconButton(
                                  icon:
                                      const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () =>
                                      setModalState(() => filter = ''),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (canAddCustom)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 4),
                      child: InkWell(
                        onTap: () async {
                          Navigator.pop(modalCtx);
                          await _addNewBenchmark(filter.trim());
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
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
                                  color: primaryPurple,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.add,
                                    color: Colors.white, size: 16),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Tambah acuan baru:',
                                      style: TextStyle(
                                          color: primaryPurple,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600),
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
                              const Icon(Icons.arrow_forward_ios_rounded,
                                  color: primaryPurple, size: 14),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: _isLoadingBenchmarks && _benchmarksList.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5, color: primaryPurple),
                                ),
                                SizedBox(height: 14),
                                Text(
                                  'Memuat data acuan...',
                                  style: TextStyle(
                                      color: Color(0xFF64748B), fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : filtered.isEmpty && !canAddCustom
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.explore_off_rounded,
                                          color: Color(0xFF94A3B8), size: 48),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Belum ada benchmark terdaftar untuk area "$_area".',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 13),
                                      ),
                                      const SizedBox(height: 12),
                                      FilledButton.icon(
                                        onPressed: () {
                                          Navigator.pop(modalCtx);
                                          _showAddBenchmarkDialog();
                                        },
                                        icon: const Icon(Icons.add, size: 18),
                                        label:
                                            const Text('Tambah Benchmark Baru'),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: primaryPurple,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 8),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const Divider(
                                    height: 1, color: Color(0xFFF1F5F9)),
                                itemBuilder: (context, index) {
                                  final item = filtered[index];
                                  final isSelected =
                                      item == _detilLokasiCtrl.text;
                                  return ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    leading: Icon(
                                      Icons.explore_rounded,
                                      color: isSelected
                                          ? primaryPurple
                                          : const Color(0xFF94A3B8),
                                      size: 20,
                                    ),
                                    title: Text(
                                      item,
                                      style: TextStyle(
                                        color: isSelected
                                            ? primaryPurple
                                            : const Color(0xFF1E293B),
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                    trailing: isSelected
                                        ? const Icon(Icons.check_circle_rounded,
                                            color: primaryPurple, size: 20)
                                        : null,
                                    onTap: () {
                                      Navigator.pop(modalCtx);
                                      setState(() {
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

  void _showAddBenchmarkDialog([String? initialName]) {
    const primaryPurple = Color(0xFF6D28D9);
    final ctrl = TextEditingController(text: initialName ?? '');
    showDialog(
      context: context,
      builder: (dlgCtx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add_location_alt_rounded,
                    color: primaryPurple, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Tambah Benchmark Baru',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Area Utama: $_area',
                style: const TextStyle(
                    color: primaryPurple,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Nama Benchmark / Detail Lokasi',
                  hintText: 'Contoh: RL 50, BM-22, Front Loading Ex-201',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.explore_rounded),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Data acuan ini akan langsung tersimpan dan tersedia untuk pilihan berikutnya.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                final text = ctrl.text.trim();
                if (text.isEmpty) return;
                Navigator.pop(dlgCtx);
                await _addNewBenchmark(text);
              },
              style: FilledButton.styleFrom(
                backgroundColor: primaryPurple,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Simpan Benchmark'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addNewBenchmark(String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;
    if (_area.isEmpty) {
      SnackBarMsg.warning(context, 'Pilih Area Utama terlebih dahulu.');
      return;
    }

    final userNik = _profile?.noNik ?? 'USER';
    final userName = _profile?.namaLengkap ?? 'User Mobile';

    setState(() {
      if (!_benchmarksList.contains(cleanName)) {
        _benchmarksList.add(cleanName);
        _benchmarksList.sort();
      }
      _detilLokasiCtrl.text = cleanName;
    });

    try {
      final sqldb = await _db.database;
      await sqldb.rawInsert(
        '''INSERT INTO tbl_m_benchmark (perusahaan_id, area_utama, nama_benchmark, created_by_nik, created_by_name, created_at)
           VALUES (?, ?, ?, ?, ?, ?)''',
        [
          _profile?.companyId ?? 1,
          _area,
          cleanName,
          userNik,
          userName,
          DateTime.now().toIso8601String()
        ],
      );
    } catch (_) {}

    try {
      final result = await _api.createBenchmark(
        areaUtama: _area,
        namaBenchmark: cleanName,
        perusahaanId: _profile?.companyId ?? 1,
        createdByNik: userNik,
        createdByName: userName,
      );
      if (mounted) {
        if (result != null) {
          SnackBarMsg.success(
              context, 'Data acuan "$cleanName" berhasil disimpan.');
        } else {
          SnackBarMsg.info(
              context, 'Benchmark "$cleanName" tersimpan di HP (Mode Offline)');
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarMsg.info(context, 'Benchmark "$cleanName" tersimpan lokal');
      }
    }
  }

  Future<void> _fetchCurrentGps({bool silent = false}) async {
    if (!mounted) return;
    setState(() => _isDetectingGps = true);
    try {
      await fillGpsCoordinate(
        context,
        _lokasiCtrl,
        () {
          if (mounted) {
            setState(() {
              final parts = _lokasiCtrl.text.split(',');
              if (parts.length == 2) {
                _latitude = double.tryParse(parts[0].trim());
                _longitude = double.tryParse(parts[1].trim());
              }
            });
          }
        },
        silent: silent,
      );
    } finally {
      if (mounted) {
        setState(() => _isDetectingGps = false);
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1280,
      );
      if (picked != null) {
        setState(() {
          _imageFile = File(picked.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      SnackBarMsg.danger(context, 'Gagal mengambil foto: $e');
    }
  }

  Future<void> _submit() async {
    final areaVal = _area.isNotEmpty ? _area : _areaCtrl.text.trim();
    if (areaVal.isEmpty) {
      SnackBarMsg.warning(context, 'Pilih Area Utama terlebih dahulu.');
      return;
    }
    if (_lokasiCtrl.text.trim().isEmpty) {
      SnackBarMsg.warning(
          context, 'Titik koordinat GPS atau lokasi spesifik wajib terisi.');
      return;
    }

    final hasUnanswered = _checkpoints.any((c) => c.isOk == null);
    if (hasUnanswered) {
      SnackBarMsg.warning(
          context, 'Harap lengkapi semua checklist fokus K3 shift malam.');
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final chosenDate = DateTime(_date.year, _date.month, _date.day);
    final isEdit = widget.editData != null;
    if (!isEdit && chosenDate.isBefore(today)) {
      SnackBarMsg.warning(context,
          'Tanggal SiMaMa tidak boleh backdate (kurang dari hari ini).');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_date);
      final timeStr =
          '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';
      final isEdit = widget.editData != null;
      final editId = isEdit ? widget.editData!['id'] as int : 0;

      // Construct checkpoint answers map
      final checkpointMap = <String, dynamic>{
        'checkpoints': _checkpoints.map((c) => c.toJson()).toList(),
        'tim_pendamping': _timPendampingCtrl.text.trim(),
        'latitude': _latitude,
        'longitude': _longitude,
        'gps_accuracy': _gpsAccuracy,
      };

      // Map up to 10 questions to q1_1 .. q4_1 format for legacy compat
      final row = <String, dynamic>{
        'title': 'Sidak Malam Management (SiMaMa)',
        'category': 'simama',
        'date': dateStr,
        'time': timeStr,
        'area': areaVal,
        'lokasi': _lokasiCtrl.text.trim(),
        'location_detail': _detilLokasiCtrl.text.trim(),
        'remark': _catatanCtrl.text.trim().isEmpty
            ? 'Sidak Malam Management'
            : _catatanCtrl.text.trim(),
        'pja': _timPendampingCtrl.text.trim(),
        'employee_id': _profile?.id ?? 0,
        'status': 1,
        'payload_json': jsonEncode(checkpointMap),
        'updated_at': DateTime.now().toString(),
      };

      for (int i = 0; i < _checkpoints.length; i++) {
        final group = (i ~/ 3) + 1;
        final qNum = (i % 3) + 1;
        row['q${group}_$qNum'] = _checkpoints[i].isOk == true ? 1 : 0;
      }

      if (_imageFile != null) {
        row['image'] = _imageFile!.path;
      } else if (_existingImageUrl != null) {
        row['image'] = _existingImageUrl;
      }

      int tranId = editId;
      if (isEdit) {
        await _db.update('inspection_trans', row, editId);
      } else {
        row['code'] =
            'SIMAMA-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
        row['created_at'] = DateTime.now().toString();
        tranId = await _db.insert('inspection_trans', row);
      }

      // Save inspection_details locally
      if (tranId > 0) {
        final sqldb = await _db.database;
        await sqldb.delete('inspection_details',
            where: 'tran_id = ?', whereArgs: [tranId]);

        for (var c in _checkpoints) {
          await _db.insert('inspection_details', {
            'tran_id': tranId,
            'point_id': c.id,
            'name': c.title,
            'status': c.isOk == true ? 1 : 0,
            'yesno': c.isOk == true ? 1 : 0,
            'remark': c.findingRemark,
            'location_id': 0,
            'type': c.category,
          });
        }

        // Direct online sync in background or immediately
        syncTran(_db, _api, 'simama', tranId).then((syncOk) {
          debugPrint('[SimamaFormPage] syncTran result: $syncOk');
        });

        if (!mounted) return;
        alertSuccess(context, widget.module, lastId: tranId);
      } else {
        if (!mounted) return;
        alertFailed(context, widget.module);
      }
    } catch (e) {
      debugPrint('[SimamaFormPage] Error submitting: $e');
      if (!mounted) return;
      alertFailed(context, widget.module);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryPurple = Color(0xFF6D28D9);
    const darkNightNavy = Color(0xFF1E1B4B);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: TopBar(
        title: widget.editData != null
            ? 'Edit Sidak Malam'
            : 'Sidak Malam (SiMaMa)',
      ),
      body: SingleChildScrollView(
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Night Header Banner
            _buildNightHeader(primaryPurple, darkNightNavy),
            const SizedBox(height: 16),

            // Card 1: Waktu & Tim Pemeriksa
            _buildCard(
              title: 'Waktu & Tim Pemeriksa Sidak Malam',
              icon: Icons.schedule_rounded,
              accentColor: primaryPurple,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildDatePicker(primaryPurple),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTimePicker(primaryPurple),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Pelapor Utama Info Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: primaryPurple.withValues(alpha: .15),
                          child: const Icon(Icons.person_pin_rounded,
                              color: primaryPurple, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _profile?.namaLengkap ?? 'Pemeriksa Utama',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFF0F172A)),
                              ),
                              Text(
                                'NIK: ${_profile?.noNik ?? "-"} • ${_profile?.depart ?? _profile?.posisi ?? "K3 Operasional"}',
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF312E81),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Shift Malam',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Tim Pendamping
                  TextField(
                    controller: _timPendampingCtrl,
                    decoration: InputDecoration(
                      labelText: 'Tim Pendamping / Anggota Sidak (Opsional)',
                      hintText:
                          'Misal: Spv Pit Barat, Foreman Elektrikal, Safety Officer',
                      hintStyle: const TextStyle(
                          fontSize: 12, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.group_rounded,
                          color: primaryPurple, size: 20),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Card 2: Area & Lokasi Sidak
            _buildCard(
              title: 'Area & Lokasi Sidak Malam',
              icon: Icons.location_on_rounded,
              accentColor: primaryPurple,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Area Utama
                  const Text(
                    'AREA UTAMA *',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: _showAreaPickerModal,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _area.isNotEmpty
                              ? primaryPurple.withValues(alpha: 0.35)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.place_rounded,
                              color: primaryPurple, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _area.isNotEmpty
                                  ? _area
                                  : 'KETIK UNTUK MENCARI AREA...',
                              style: TextStyle(
                                color: _area.isNotEmpty
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFF94A3B8),
                                fontSize: 13,
                                fontWeight: _area.isNotEmpty
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (_isLoadingAreas)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: primaryPurple),
                            )
                          else
                            const Icon(Icons.keyboard_arrow_down_rounded,
                                color: Color(0xFF64748B), size: 20),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Detail Lokasi / Benchmark
                  const Text(
                    'DETAIL LOKASI / BENCHMARK',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            if (_area.isEmpty) {
                              SnackBarMsg.warning(
                                  context, 'Pilih Area Utama terlebih dahulu.');
                              return;
                            }
                            _showBenchmarkPickerModal();
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.explore_rounded,
                                    color: primaryPurple, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _area.isEmpty
                                        ? 'PILIH AREA UTAMA DULU...'
                                        : (_detilLokasiCtrl.text.isNotEmpty
                                            ? _detilLokasiCtrl.text
                                            : 'PILIH ATAU CARI BENCHMARK...'),
                                    style: TextStyle(
                                      color: _detilLokasiCtrl.text.isNotEmpty
                                          ? const Color(0xFF0F172A)
                                          : const Color(0xFF94A3B8),
                                      fontSize: 13,
                                      fontWeight:
                                          _detilLokasiCtrl.text.isNotEmpty
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (_isLoadingBenchmarks)
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: primaryPurple),
                                  )
                                else
                                  const Icon(Icons.keyboard_arrow_down_rounded,
                                      color: Color(0xFF64748B), size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Add benchmark button
                      InkWell(
                        onTap: () {
                          if (_area.isEmpty) {
                            SnackBarMsg.warning(context,
                                'Pilih Area Utama terlebih dahulu sebelum menambah benchmark.');
                            return;
                          }
                          _showAddBenchmarkDialog();
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: primaryPurple,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: primaryPurple.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.add_location_alt_rounded,
                              color: Colors.white, size: 22),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Lokasi Spesifik
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'LOKASI SPESIFIK (GPS) *',
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            _lokasiCtrl.text.isNotEmpty
                                ? Icons.gps_fixed_rounded
                                : Icons.gps_not_fixed_rounded,
                            size: 13,
                            color: _lokasiCtrl.text.isNotEmpty
                                ? const Color(0xFF10B981)
                                : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _lokasiCtrl.text.isNotEmpty
                                ? 'Satelit Terkunci'
                                : 'Auto-Deteksi',
                            style: TextStyle(
                              color: _lokasiCtrl.text.isNotEmpty
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF64748B),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _lokasiCtrl.text.isNotEmpty
                            ? const Color(0xFF86EFAC)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.place_rounded,
                          color: _lokasiCtrl.text.isNotEmpty
                              ? const Color(0xFF16A34A)
                              : primaryPurple,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _lokasiCtrl,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Titik koordinat GPS...',
                              hintStyle: TextStyle(
                                  color: Color(0xFF94A3B8), fontSize: 13),
                            ),
                          ),
                        ),
                        if (_isDetectingGps)
                          const Padding(
                            padding: EdgeInsets.all(6),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: primaryPurple,
                              ),
                            ),
                          )
                        else if (_lokasiCtrl.text.isNotEmpty)
                          InkWell(
                            onTap: () => _fetchCurrentGps(silent: false),
                            borderRadius: BorderRadius.circular(20),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF10B981),
                                size: 22,
                              ),
                            ),
                          )
                        else
                          InkWell(
                            onTap: () => _fetchCurrentGps(silent: false),
                            borderRadius: BorderRadius.circular(20),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(
                                Icons.my_location_rounded,
                                color: primaryPurple,
                                size: 22,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Card 3: Checklist Fokus K3 Shift Malam
            _buildCard(
              title: 'Checklist Fokus K3 Shift Malam (SiMaMa)',
              icon: Icons.checklist_rtl_rounded,
              accentColor: primaryPurple,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Evaluasi kondisi lapangan dan kepatuhan keselamatan kerja shift malam:',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),
                  ..._checkpoints.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return _buildChecklistItem(index + 1, item, primaryPurple);
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Card 4: Dokumentasi Foto Sidak
            _buildCard(
              title: 'Dokumentasi & Bukti Foto Sidak',
              icon: Icons.photo_camera_rounded,
              accentColor: primaryPurple,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_imageFile != null || _existingImageUrl != null)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _imageFile != null
                              ? Image.file(
                                  _imageFile!,
                                  width: double.infinity,
                                  height: 200,
                                  fit: BoxFit.cover,
                                )
                              : Image.network(
                                  _existingImageUrl!.startsWith('http')
                                      ? _existingImageUrl!
                                      : '${_api.baseUrl}${_existingImageUrl!.startsWith('/') ? '' : '/'}${_existingImageUrl!}',
                                  width: double.infinity,
                                  height: 200,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 200,
                                    color: Colors.grey.shade200,
                                    child: const Center(
                                        child: Icon(Icons.broken_image,
                                            size: 40, color: Colors.grey)),
                                  ),
                                ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _imageFile = null;
                                _existingImageUrl = null;
                              });
                            },
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor:
                                  Colors.black.withValues(alpha: .7),
                              child: const Icon(Icons.close_rounded,
                                  color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryPurple,
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () => _pickImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt_rounded),
                            label: const Text('Buka Kamera',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF475569),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_rounded),
                            label: const Text('Dari Galeri',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Card 5: Catatan Temuan & Rekomendasi
            _buildCard(
              title: 'Catatan Temuan & Rekomendasi Sidak',
              icon: Icons.notes_rounded,
              accentColor: primaryPurple,
              child: TextField(
                controller: _catatanCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText:
                      'Tuliskan catatan observasi lapangan, temuan positif, atau rekomendasi perbaikan untuk shift malam...',
                  hintStyle:
                      const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: buttonApp(
                label: _isSubmitting
                    ? 'Menyimpan Laporan...'
                    : (widget.editData != null
                        ? 'Perbarui Data Sidak Malam'
                        : 'Simpan Laporan Sidak Malam'),
                bgColor: primaryPurple,
                onPressed: _isSubmitting ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNightHeader(Color accent, Color dark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF3B0764),
            accent,
            const Color(0xFF9333EA),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: .35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.nights_stay_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OHS NIGHT SHIFT PATROL',
                      style: TextStyle(
                        color: Color(0xFFF3E8FF),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    Text(
                      'Sidak Malam Management',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Kontrol kepatuhan K3, kesiapan kerja shift malam, pencahayaan, anti-fatigue, dan keselamatan operasional tambang.',
            style: TextStyle(
                color: Color(0xFFFAF5FF), fontSize: 11.5, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Color accentColor,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20, thickness: 1, color: Color(0xFFF1F5F9)),
          child,
        ],
      ),
    );
  }

  Widget _buildDatePicker(Color accent) {
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final initial = _date.isBefore(today) ? today : _date;
        final picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: today, // STRICT: Tidak bisa backdate
          lastDate: DateTime(now.year + 2),
          helpText: 'PILIH TANGGAL SIDAK SIMAMA',
        );
        if (picked != null) {
          setState(() => _date = picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded, color: accent, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tanggal Sidak',
                      style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                  Text(
                    DateFormat('dd MMM yyyy').format(_date),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF0F172A)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePicker(Color accent) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: _time,
        );
        if (picked != null) {
          setState(() => _time = picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time_rounded, color: accent, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Waktu / Jam',
                      style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                  Text(
                    '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF0F172A)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistItem(
      int number, SimamaChecklistItem item, Color accent) {
    final isOk = item.isOk;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOk == true
            ? const Color(0xFFF0FDF4)
            : (isOk == false
                ? const Color(0xFFFEF2F2)
                : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOk == true
              ? const Color(0xFF86EFAC)
              : (isOk == false
                  ? const Color(0xFFFCA5A5)
                  : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: accent.withValues(alpha: .15),
                child: Text('$number',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: accent)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.hint,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => item.isOk = true),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color:
                          isOk == true ? const Color(0xFF16A34A) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isOk == true
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: isOk == true
                              ? Colors.white
                              : const Color(0xFF16A34A),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'SESUAI / AMAN',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isOk == true
                                ? Colors.white
                                : const Color(0xFF16A34A),
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
                  onTap: () => setState(() => item.isOk = false),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isOk == false
                          ? const Color(0xFFDC2626)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isOk == false
                            ? const Color(0xFFDC2626)
                            : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: isOk == false
                              ? Colors.white
                              : const Color(0xFFDC2626),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'TEMUAN / TIDAK',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isOk == false
                                ? Colors.white
                                : const Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (isOk == false) ...[
            const SizedBox(height: 10),
            TextField(
              onChanged: (val) => item.findingRemark = val,
              controller: TextEditingController(text: item.findingRemark)
                ..selection = TextSelection.fromPosition(
                    TextPosition(offset: item.findingRemark.length)),
              decoration: InputDecoration(
                hintText: 'Deskripsikan temuan / tindakan koreksi...',
                hintStyle:
                    const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFFCA5A5)),
                ),
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

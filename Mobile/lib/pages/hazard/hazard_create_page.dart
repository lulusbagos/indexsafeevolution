import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../models/hazard_hub_model.dart';
import '../../services/api.dart';
import '../../services/database.dart';
import '../../services/offline_sync_service.dart';
import '../../services/preference.dart';
import '../../widgets/sap_form_widgets.dart';
import '../../widgets/snackbar_msg.dart';
import '../../widgets/top_bar.dart';
import '../../widgets/professional_success_sheet.dart';

class JenisBahayaDef {
  final String name;
  final IconData icon;
  final Color color;
  final String subtitle;

  const JenisBahayaDef({
    required this.name,
    required this.icon,
    required this.color,
    required this.subtitle,
  });
}

const List<JenisBahayaDef> kJenisBahayaDefs = [
  JenisBahayaDef(
    name: 'Biologi',
    icon: Icons.pest_control_rounded,
    color: Color(0xFF059669),
    subtitle: 'Hewan liar, serangga berbisa, ular, tanaman beracun, bakteri',
  ),
  JenisBahayaDef(
    name: 'Ergonomi',
    icon: Icons.accessibility_new_rounded,
    color: Color(0xFF6366F1),
    subtitle: 'Postur janggal, angkat beban berlebih, getaran alat kerja',
  ),
  JenisBahayaDef(
    name: 'Fasilitas Emergency',
    icon: Icons.emergency_rounded,
    color: Color(0xFFE11D48),
    subtitle: 'APAR kadaluarsa, kotak P3K, rambu evakuasi, sirine, eyewash',
  ),
  JenisBahayaDef(
    name: 'Fisikal',
    icon: Icons.hearing_disabled_rounded,
    color: Color(0xFF0284C7),
    subtitle:
        'Kebisingan tinggi, pencahayaan kurang, suhu ekstrim, debu tambang',
  ),
  JenisBahayaDef(
    name: 'Kelistrikan',
    icon: Icons.bolt_rounded,
    color: Color(0xFFD97706),
    subtitle: 'Kabel terkelupas, panel tegangan tinggi terbuka, korsleting',
  ),
  JenisBahayaDef(
    name: 'Kimia',
    icon: Icons.science_rounded,
    color: Color(0xFF7C3AED),
    subtitle: 'Limbah B3, tumpahan solar/oli, uap kimia asam, gas beracun',
  ),
  JenisBahayaDef(
    name: 'Lingkungan',
    icon: Icons.eco_rounded,
    color: Color(0xFF16A34A),
    subtitle: 'Pencemaran air sungai, settling pond meluap, tumpahan ke tanah',
  ),
  JenisBahayaDef(
    name: 'Longsor',
    icon: Icons.landslide_rounded,
    color: Color(0xFFC2410C),
    subtitle:
        'Retakan lereng pit, slope failure highwall/disposal, batu runtuh',
  ),
  JenisBahayaDef(
    name: 'Mekanikal',
    icon: Icons.settings_suggest_rounded,
    color: Color(0xFF2563EB),
    subtitle:
        'Gir berputar tanpa penutup, rem blong, pinch point, hidrolik bocor',
  ),
  JenisBahayaDef(
    name: 'Perilaku',
    icon: Icons.engineering_rounded,
    color: Color(0xFFBE185D),
    subtitle: 'Tidak memakai APD, main HP saat operasi, melanggar SOP K3',
  ),
  JenisBahayaDef(
    name: 'Traffic',
    icon: Icons.traffic_rounded,
    color: Color(0xFFEA580C),
    subtitle: 'Jalan hauling amblas, blind spot, over-speed, interaksi LV & HD',
  ),
  JenisBahayaDef(
    name: 'Dan lain-lain',
    icon: Icons.category_rounded,
    color: Color(0xFF64748B),
    subtitle: 'Potensi bahaya keselamatan operasional lainnya',
  ),
];

class HazardCreatePage extends StatefulWidget {
  final HazardReportItem? editItem; // Jika mode edit temuan yang masih open

  const HazardCreatePage({this.editItem, super.key});

  @override
  State<HazardCreatePage> createState() => _HazardCreatePageState();
}

class _HazardCreatePageState extends State<HazardCreatePage> {
  final _api = ApiService();
  final _db = DatabaseService();
  final _picker = ImagePicker();

  DateTime _tanggal = DateTime.now();
  TimeOfDay _waktu = TimeOfDay.now();

  String _area = '';
  String _lokasi = '';
  String _detilLokasi = '';
  String _kategoriBahaya = 'Kondisi Tidak Aman';
  String _jenisBahaya = '';
  String _jenisKetidaksesuaian = '';
  String _tingkatResiko = 'Sedang';
  String _temuan = '';
  String _perbaikan = '';
  String _tindakanPerbaikan = '';

  PjaSearchResult? _selectedPja;
  File? _fotoTemuan;
  File? _fotoPerbaikan;
  bool _isSelfClosed = false;
  bool _isSubmitting = false;
  bool _lintasPerusahaan = true;

  final TextEditingController _lokasiCtrl = TextEditingController();
  final TextEditingController _detilLokasiCtrl = TextEditingController();
  final TextEditingController _ketidaksesuaianCtrl = TextEditingController();
  final TextEditingController _temuanCtrl = TextEditingController();
  final TextEditingController _perbaikanCtrl = TextEditingController();
  final TextEditingController _tindakanCtrl = TextEditingController();
  final TextEditingController _pjaSearchCtrl = TextEditingController();

  List<String> _masterAreas = [];
  List<String> _benchmarksList = [];
  bool _isLoadingAreas = false;
  bool _isLoadingBenchmarks = false;

  List<PjaSearchResult> _pjaSearchResults = [];
  bool _isSearchingPja = false;
  bool _isDetectingGps = false;

  @override
  void initState() {
    super.initState();
    _loadAreasFromMaster();

    if (widget.editItem != null) {
      final e = widget.editItem!;
      try {
        _tanggal = DateTime.parse(e.tanggal);
      } catch (_) {}
      _area = e.area ?? '';
      _lokasi = e.lokasi ?? '';
      _lokasiCtrl.text = _lokasi;
      _detilLokasi = e.detilLokasi ?? '';
      _detilLokasiCtrl.text = _detilLokasi;
      _kategoriBahaya = e.kategoriBahaya ?? 'Kondisi Tidak Aman';
      _jenisBahaya = e.jenisBahaya ?? '';
      _jenisKetidaksesuaian = e.jenisKetidaksesuaian ?? '';
      _ketidaksesuaianCtrl.text = _jenisKetidaksesuaian;
      _tingkatResiko = e.tingkatResiko;
      _temuan = e.temuan;
      _temuanCtrl.text = _temuan;
      _perbaikan = e.perbaikan ?? '';
      _perbaikanCtrl.text = _perbaikan;
      _tindakanPerbaikan = e.tindakanPerbaikan ?? '';
      _tindakanCtrl.text = _tindakanPerbaikan;

      if (e.pja != null && e.pja!.isNotEmpty) {
        _selectedPja = PjaSearchResult(
          nik: e.nikPja ?? '',
          nama: e.pja!,
          jabatan: 'PJA Terpilih',
          departemen: e.departemenPja ?? 'GENERAL',
          perusahaan: 'PT INDEXIM COALINDO',
        );
      }
      if (_area.isNotEmpty) {
        _loadBenchmarksForArea(_area);
      }
    }

    // Auto-deteksi lokasi GPS spesifik saat halaman form dibuka (bekerja online maupun offline)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_lokasiCtrl.text.isEmpty) {
        _fetchCurrentGps(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _lokasiCtrl.dispose();
    _detilLokasiCtrl.dispose();
    _ketidaksesuaianCtrl.dispose();
    _temuanCtrl.dispose();
    _perbaikanCtrl.dispose();
    _tindakanCtrl.dispose();
    _pjaSearchCtrl.dispose();
    super.dispose();
  }

  VoidCallback? _onBenchmarksLoadedModal;
  VoidCallback? _onAreasLoadedModal;

  Future<void> _loadAreasFromMaster({VoidCallback? onDone}) async {
    if (mounted) setState(() => _isLoadingAreas = true);
    final profile = PreferenceService.getProfile();
    final companyId = profile?.companyId ?? 1;

    try {
      final sqldb = await _db.database;

      // 1. Inisialisasi tabel SQLite tbl_m_benchmark lokal
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

      // Bersihkan entri invalid CAMP EKSPLORASI dari tabel lokal jika masih ada
      await sqldb.execute(
          "DELETE FROM tbl_m_benchmark WHERE area_utama LIKE '%CAMP EKSPLORASI%' OR nama_benchmark = 'CAMP EKSPLORASI BLOCK CENTRAL'");

      // 2. Baca dari database SQLite lokal (semua area yang tersimpan)
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

      // 3. Refresh dari server API tbl_m_benchmark sesuai perusahaan_id user login
      final serverAreas = await _api.getMasterAreas(perusahaanId: companyId);
      if (serverAreas.isNotEmpty && mounted) {
        setState(() {
          _masterAreas = serverAreas
              .where((s) => !s.toUpperCase().contains('CAMP EKSPLORASI'))
              .toList();
        });
        onDone?.call();
        _onAreasLoadedModal?.call();

        // Simpan ke SQLite untuk mode offline
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
      debugPrint('[HazardCreate] Error loading areas: $e');
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
    final profile = PreferenceService.getProfile();
    final companyId = profile?.companyId ?? 1;

    try {
      final sqldb = await _db.database;

      // 1. Inisialisasi tabel SQLite jika belum ada
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

      // 2. Baca cache lokal untuk area ini (semua benchmark yang tersimpan)
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

      // 3. Ambil dari server API tbl_m_benchmark sesuai perusahaan_id user login
      final serverBenchmarks =
          await _api.getBenchmarks(cleanArea, perusahaanId: companyId);
      if (serverBenchmarks.isNotEmpty && mounted) {
        setState(() {
          _benchmarksList = serverBenchmarks;
        });
        onDone?.call();
        _onBenchmarksLoadedModal?.call();

        // Simpan ke SQLite tbl_m_benchmark
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
      debugPrint('[HazardCreate] Error loading benchmarks: $e');
    } finally {
      if (mounted) setState(() => _isLoadingBenchmarks = false);
      onDone?.call();
      _onBenchmarksLoadedModal?.call();
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
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0284C7),
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
                                    Text(
                                      'Gunakan / Tambah Area Baru:',
                                      style: TextStyle(
                                          color: Colors.blue.shade700,
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
                                  color: Color(0xFF0284C7), size: 14),
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
                                      strokeWidth: 2.5),
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
                                          ? const Color(0xFF0284C7)
                                          : const Color(0xFF94A3B8),
                                      size: 20,
                                    ),
                                    title: Text(
                                      item,
                                      style: TextStyle(
                                        color: isSelected
                                            ? const Color(0xFF0284C7)
                                            : const Color(0xFF1E293B),
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                    trailing: isSelected
                                        ? const Icon(Icons.check_circle_rounded,
                                            color: Color(0xFF0284C7), size: 20)
                                        : null,
                                    onTap: () {
                                      Navigator.pop(modalCtx);
                                      setState(() {
                                        _area = item;
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

            // Auto fetch if empty (safely scheduled)
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
                                    color: Color(0xFF0284C7),
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
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF38BDF8),
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
                                    Text(
                                      'Tambah acuan baru:',
                                      style: TextStyle(
                                          color: Colors.blue.shade700,
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
                                  color: Color(0xFF0284C7), size: 14),
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
                                      strokeWidth: 2.5),
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
                                          backgroundColor:
                                              const Color(0xFF38BDF8),
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
                                          ? const Color(0xFF0284C7)
                                          : const Color(0xFF94A3B8),
                                      size: 20,
                                    ),
                                    title: Text(
                                      item,
                                      style: TextStyle(
                                        color: isSelected
                                            ? const Color(0xFF0284C7)
                                            : const Color(0xFF1E293B),
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                    trailing: isSelected
                                        ? const Icon(Icons.check_circle_rounded,
                                            color: Color(0xFF0284C7), size: 20)
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

  Widget _buildKategoriSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildKategoriCard(
            title: 'Kondisi Tidak Aman',
            code: 'KTA',
            subtitle: 'Kondisi fisik, fasilitas, atau alat kerja',
            icon: Icons.warning_amber_rounded,
            color: const Color(0xFFD97706),
            isSelected: _kategoriBahaya == 'Kondisi Tidak Aman',
            onTap: () => setState(() => _kategoriBahaya = 'Kondisi Tidak Aman'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildKategoriCard(
            title: 'Tindakan Tidak Aman',
            code: 'TTA',
            subtitle: 'Perilaku atau cara kerja melanggar SOP',
            icon: Icons.pan_tool_outlined,
            color: const Color(0xFFE11D48),
            isSelected: _kategoriBahaya == 'Tindakan Tidak Aman',
            onTap: () =>
                setState(() => _kategoriBahaya = 'Tindakan Tidak Aman'),
          ),
        ),
      ],
    );
  }

  Widget _buildKategoriCard({
    required String title,
    required String code,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.08)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected ? color : color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon,
                      color: isSelected ? Colors.white : color, size: 20),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: isSelected ? color : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    code,
                    style: TextStyle(
                      color:
                          isSelected ? Colors.white : const Color(0xFF475569),
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                color: isSelected
                    ? const Color(0xFF0F172A)
                    : const Color(0xFF334155),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 10.5,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJenisBahayaSelector() {
    final currentVal = kJenisBahayaDefs
            .any((d) => d.name.toLowerCase() == _jenisBahaya.toLowerCase())
        ? kJenisBahayaDefs
            .firstWhere(
                (d) => d.name.toLowerCase() == _jenisBahaya.toLowerCase())
            .name
        : null;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _jenisBahaya.isEmpty
              ? const Color(0xFFCBD5E1)
              : const Color(0xFFE2E8F0),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentVal,
          isExpanded: true,
          itemHeight: 56,
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(14),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF64748B), size: 22),
          hint: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Icon(Icons.category_outlined,
                    color: Color(0xFF94A3B8), size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'PILIH JENIS BAHAYA...',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          selectedItemBuilder: (context) {
            return kJenisBahayaDefs.map((def) {
              return Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: def.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(def.icon, color: def.color, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      def.name,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              );
            }).toList();
          },
          items: kJenisBahayaDefs.map((def) {
            return DropdownMenuItem<String>(
              value: def.name,
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: def.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(def.icon, color: def.color, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          def.name,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          def.subtitle,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() => _jenisBahaya = val);
            }
          },
        ),
      ),
    );
  }

  Widget _buildTingkatRisikoSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildRiskCard(
                label: 'Rendah',
                icon: Icons.shield_outlined,
                color: const Color(0xFF059669),
              ),
              const SizedBox(width: 8),
              _buildRiskCard(
                label: 'Sedang',
                icon: Icons.warning_amber_rounded,
                color: const Color(0xFFD97706),
              ),
              const SizedBox(width: 8),
              _buildRiskCard(
                label: 'Tinggi',
                icon: Icons.report_problem_outlined,
                color: const Color(0xFFEA580C),
              ),
              const SizedBox(width: 8),
              _buildRiskCard(
                label: 'Ekstrim',
                icon: Icons.dangerous_outlined,
                color: const Color(0xFFDC2626),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _buildRiskExplanationBanner(),
      ],
    );
  }

  Widget _buildRiskCard({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _tingkatResiko.toLowerCase() == label.toLowerCase();
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tingkatResiko = label),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.08) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? color : const Color(0xFFE2E8F0),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? color.withValues(alpha: 0.18)
                    : Colors.black.withValues(alpha: 0.02),
                blurRadius: isSelected ? 8 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Stylized Risk Icon Badge (Clean & Elegant)
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isSelected ? color : color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    size: 22,
                    color: isSelected ? Colors.white : color,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : const Color(0xFF0F172A),
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRiskExplanationBanner() {
    Color color;
    IconData icon;
    String text;

    switch (_tingkatResiko.toLowerCase()) {
      case 'ekstrim':
        color = const Color(0xFFDC2626);
        icon = Icons.error_outline_rounded;
        text =
            'STOP OPERASI (SWA)! Bahaya kritis berpotensi fatalitas / cacat permanen. Wajib dihentikan & dilaporkan segera!';
        break;
      case 'tinggi':
        color = const Color(0xFFEA580C);
        icon = Icons.warning_amber_rounded;
        text =
            'Prioritas Tinggi: Bahaya berpotensi cedera berat atau kerusakan aset signifikan. Memerlukan penanganan segera.';
        break;
      case 'sedang':
        color = const Color(0xFFD97706);
        icon = Icons.info_outline_rounded;
        text =
            'Perhatian Khusus: Bahaya berpotensi menimbulkan cedera ringan atau kerugian operasional. Memerlukan tindakan terencana.';
        break;
      default:
        color = const Color(0xFF059669);
        icon = Icons.check_circle_outline_rounded;
        text =
            'Tindakan Terjadwal: Bahaya berdampak minimal. Perbaikan dilakukan melalui pemeliharaan atau housekeeping berkala.';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddBenchmarkDialog([String? initialName]) {
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
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add_location_alt_rounded,
                    color: Color(0xFF0284C7), size: 20),
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
                    color: Color(0xFF0284C7),
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
                  hintText: 'Contoh: RL 50, BM-22, Seam B',
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
                backgroundColor: const Color(0xFF0284C7),
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

    final profile = PreferenceService.getProfile();
    final userNik = profile?.noNik ?? 'USER';
    final userName = profile?.namaLengkap ?? 'User Mobile';

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
          profile?.companyId ?? 1,
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
        perusahaanId: profile?.companyId ?? 1,
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

  Future<void> _addNewArea(String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;

    final profile = PreferenceService.getProfile();
    final userNik = profile?.noNik ?? 'USER';
    final userName = profile?.namaLengkap ?? 'User Mobile';

    setState(() {
      if (!_masterAreas.contains(cleanName)) {
        _masterAreas.add(cleanName);
        _masterAreas.sort();
      }
      _area = cleanName;
      _detilLokasiCtrl.text = '';
      _benchmarksList = [];
    });

    try {
      final sqldb = await _db.database;
      await sqldb.rawInsert(
        '''INSERT INTO tbl_m_benchmark (perusahaan_id, area_utama, nama_benchmark, created_by_nik, created_by_name, created_at)
           VALUES (?, ?, '', ?, ?, ?)''',
        [
          profile?.companyId ?? 1,
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

  Future<void> _fetchCurrentGps({bool silent = false}) async {
    if (!mounted) return;
    // Jika koordinat sudah terisi (GPS sudah nyala dan terkunci), tidak perlu deteksi ulang
    if (_lokasiCtrl.text.trim().isNotEmpty) return;
    setState(() => _isDetectingGps = true);
    try {
      await fillGpsCoordinate(
        context,
        _lokasiCtrl,
        () {
          if (mounted) {
            setState(() {
              _lokasi = _lokasiCtrl.text;
              _detilLokasi = _detilLokasiCtrl.text;
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

  void _searchPjaOnline(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _pjaSearchResults = [];
        _isSearchingPja = false;
      });
      return;
    }

    // 1. Tampilkan hasil lokal SQLite secara instan agar tidak menunggu timeout jaringan
    final localList = await _searchPjaLocal(q);
    if (mounted && _pjaSearchCtrl.text.trim() == q) {
      setState(() {
        _pjaSearchResults = localList;
      });
    }

    // 2. Coba update dari server jika online (background refresh)
    setState(() => _isSearchingPja = true);
    try {
      final res = await _api.searchPja(q, lintasPerusahaan: _lintasPerusahaan);
      if (!mounted) return;
      res.fold(
        (err) {
          if (mounted) setState(() => _isSearchingPja = false);
        },
        (data) {
          if (mounted && _pjaSearchCtrl.text.trim() == q) {
            setState(() {
              _isSearchingPja = false;
              if (data.isNotEmpty) {
                _pjaSearchResults =
                    data.map((e) => PjaSearchResult.fromJson(e)).toList();
              }
            });
          }
        },
      );
    } catch (_) {
      if (mounted) setState(() => _isSearchingPja = false);
    }
  }

  Future<List<PjaSearchResult>> _searchPjaLocal(String query) async {
    try {
      final safeQ = query.replaceAll("'", "''").trim();
      final sqldb = await _db.database;
      final rows = await sqldb.rawQuery(
        "SELECT no_nik, nama_lengkap, depart, posisi, departemen, jabatan, perusahaan FROM employees WHERE no_nik LIKE '%$safeQ%' OR nama_lengkap LIKE '%$safeQ%' LIMIT 30",
      );
      final list = rows
          .map((r) => PjaSearchResult(
                nik: r['no_nik']?.toString() ?? '',
                nama: r['nama_lengkap']?.toString() ?? '',
                departemen:
                    (r['departemen'] ?? r['depart'])?.toString() ?? 'GENERAL',
                jabatan:
                    (r['jabatan'] ?? r['posisi'])?.toString() ?? 'Karyawan',
                perusahaan:
                    r['perusahaan']?.toString() ?? 'PT INDEXIM COALINDO',
              ))
          .toList();

      return list;
    } catch (e) {
      debugPrint('[HazardCreate] Error local PJA search: $e');
      return [];
    }
  }

  Future<void> _pickImage(bool isBefore) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 42,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_photo_alternate_rounded,
                        color: Color(0xFFEA580C), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ambil Bukti Foto',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Pilih sumber foto temuan keselamatan kerja',
                          style: TextStyle(
                              fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Option 1: Kamera Lapangan
              InkWell(
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEA580C), Color(0xFFF97316)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEA580C)
                                  .withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.photo_camera_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Kamera Lapangan',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFECFDF5),
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(6)),
                                  ),
                                  child: const Text(
                                    'REKOMENDASI',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF059669),
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'Potret kondisi aktual langsung di lokasi kerja',
                              style: TextStyle(
                                  fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: Color(0xFF94A3B8), size: 22),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Option 2: Galeri Media
              InkWell(
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF3B82F6)
                                  .withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.photo_library_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pilih dari Galeri',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Gunakan foto dokumentasi yang tersimpan di HP',
                              style: TextStyle(
                                  fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: Color(0xFF94A3B8), size: 22),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (source != null) {
      try {
        final picked = await _picker.pickImage(
          source: source,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 80,
        );
        if (picked != null) {
          setState(() {
            if (isBefore) {
              _fotoTemuan = File(picked.path);
            } else {
              _fotoPerbaikan = File(picked.path);
            }
          });
        }
      } catch (err) {
        debugPrint('[PickImage] Error: $err');
        if (mounted) {
          SnackBarMsg.danger(context,
              'Tidak dapat membuka foto. Pastikan izin kamera/galeri telah diizinkan.');
        }
      }
    }
  }

  void _submitHazard() async {
    if (_jenisBahaya.trim().isEmpty) {
      SnackBarMsg.danger(context, 'Jenis bahaya wajib dipilih.');
      return;
    }
    if (_temuanCtrl.text.trim().isEmpty) {
      SnackBarMsg.danger(context, 'Detail temuan hazard wajib diisi.');
      return;
    }
    if (_lokasiCtrl.text.trim().isEmpty) {
      SnackBarMsg.danger(context, 'Lokasi spesifik wajib diisi.');
      return;
    }
    final profile = PreferenceService.getProfile();
    final profileNama = profile?.namaLengkap ?? 'Pelapor';
    final profileNik = profile?.noNik ?? '';
    final profileDepartemen = profile?.depart ?? 'OPERASIONAL';

    if (!_isSelfClosed && _selectedPja == null) {
      if (_pjaSearchCtrl.text.trim().isNotEmpty) {
        _selectedPja = PjaSearchResult(
          nik: 'MANUAL',
          nama: _pjaSearchCtrl.text.trim().toUpperCase(),
          departemen: 'LAPANGAN',
          jabatan: 'PJA Offline',
          perusahaan: 'INTERNAL',
        );
      } else {
        SnackBarMsg.danger(context,
            'Penanggung Jawab Area (PJA) wajib dipilih atau diketik untuk menindaklanjuti temuan.');
        return;
      }
    }
    if (_fotoTemuan == null && widget.editItem == null) {
      SnackBarMsg.danger(context, 'Foto bukti temuan (Before) wajib diunggah.');
      return;
    }
    if (_isSelfClosed &&
        _fotoPerbaikan == null &&
        widget.editItem?.fotoPerbaikan == null) {
      SnackBarMsg.danger(context,
          'Foto bukti perbaikan (After) wajib diunggah untuk status selesai langsung.');
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final minAllowed = today.subtract(const Duration(days: 2));
    final targetDate = DateTime(_tanggal.year, _tanggal.month, _tanggal.day);
    if (targetDate.isBefore(minAllowed)) {
      SnackBarMsg.danger(context,
          'Tanggal temuan tidak boleh backdate lebih dari 2 hari terakhir.');
      return;
    }
    if (targetDate.isAfter(today)) {
      SnackBarMsg.danger(
          context, 'Tanggal temuan tidak boleh melebihi hari ini.');
      return;
    }

    setState(() => _isSubmitting = true);

    final fields = <String, dynamic>{
      'tanggal': DateFormat('yyyy-MM-dd').format(_tanggal),
      'waktu':
          '${_waktu.hour.toString().padLeft(2, '0')}:${_waktu.minute.toString().padLeft(2, '0')}',
      'area': _area.isNotEmpty ? _area : 'PIT AREA',
      'lokasi': _lokasiCtrl.text.trim(),
      'detil_lokasi': _detilLokasiCtrl.text.trim(),
      'kategori_bahaya': _kategoriBahaya,
      'jenis_bahaya': _jenisBahaya,
      'jenis_ketidaksesuaian': _ketidaksesuaianCtrl.text.trim(),
      'tingkat_resiko': _tingkatResiko,
      'temuan': _temuanCtrl.text.trim(),
      'perbaikan': _perbaikanCtrl.text.trim(),
      'tindakan_perbaikan': _tindakanCtrl.text.trim(),
      'pja': _isSelfClosed
          ? profileNama
          : (_selectedPja?.nama ?? _pjaSearchCtrl.text.trim().toUpperCase()),
      'nik_pja': _isSelfClosed ? profileNik : (_selectedPja?.nik ?? 'MANUAL'),
      'departemen_pja': _isSelfClosed
          ? profileDepartemen
          : (_selectedPja?.departemen ?? 'LAPANGAN'),
      'status_temuan': _isSelfClosed ? 'Closed' : 'Open',
    };

    final con = await Connectivity().checkConnectivity();
    final isOnline = con.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet ||
        r == ConnectivityResult.vpn);

    if (!isOnline) {
      await _saveOffline(fields);
      return;
    }

    final result = await _api.createHazardReport(
      fields,
      fotoTemuan: _fotoTemuan,
      fotoPerbaikan: _fotoPerbaikan,
    );

    if (!mounted) return;

    await result.fold(
      (err) async {
        // Fallback simpan offline jika gagal koneksi/server
        await _saveOffline(fields);
      },
      (data) async {
        setState(() => _isSubmitting = false);
        await showProfessionalSuccessSheet(
          context: context,
          title: 'Laporan Hazard Sukses Dikirim!',
          subtitle: 'Temuan bahaya Anda telah terkirim dan berhasil tercatat.',
          referenceNumber:
              'HZD-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
          accentColor: const Color(0xFFF97316),
          icon: Icons.warning_amber_rounded,
          statusBadgeText: 'BERHASIL TERSIMPAN',
          receiptItems: [
            SuccessReceiptItem(
                label: 'Kategori Bahaya',
                value: fields['kategori_bahaya']?.toString() ?? '-',
                isHighlight: true),
            SuccessReceiptItem(
                label: 'Jenis Bahaya',
                value: fields['jenis_bahaya']?.toString() ?? '-'),
            SuccessReceiptItem(
                label: 'Tingkat Resiko',
                value: fields['tingkat_resiko']?.toString() ?? 'Sedang',
                highlightColor: const Color(0xFFEF4444)),
            SuccessReceiptItem(
                label: 'Area & Lokasi',
                value: '${fields['area']} - ${fields['lokasi']}'),
            SuccessReceiptItem(
                label: 'Penanggung Jawab (PJA)',
                value: fields['pja']?.toString() ?? '-'),
            SuccessReceiptItem(
                label: 'Status Temuan',
                value: fields['status_temuan']?.toString() ?? 'Open',
                isHighlight: true),
          ],
          primaryButtonText: 'Kembali ke Hub Hazard',
        );
        if (mounted) Navigator.pop(context, true);
      },
    );
  }

  Future<void> _saveOffline(Map<String, dynamic> fields) async {
    final profile = PreferenceService.getProfile();
    final profileId = profile?.id ?? 0;
    try {
      final code =
          '${profile?.noNik ?? "EMP"}-${DateTime.now().millisecondsSinceEpoch}'
              .padRight(20)
              .substring(0, 20);
      final row = <String, dynamic>{
        'code': code,
        'title': '${fields['kategori_bahaya']} - ${fields['jenis_bahaya']}',
        'location_detail':
            '${fields['lokasi']} ${fields['detil_lokasi']}'.trim(),
        'date': fields['tanggal'],
        'time': fields['waktu'],
        'remark': fields['temuan'],
        'image': _fotoTemuan?.path,
        'repair_remark': fields['perbaikan'],
        'repair_image': _fotoPerbaikan?.path,
        'status': _isSelfClosed ? 2 : 0,
        'pja_id': 0,
        'employee_id': profileId,
        'sync_id': null,
        'area': fields['area'],
        'lokasi': fields['lokasi'],
        'kategori_bahaya': fields['kategori_bahaya'],
        'jenis_bahaya': fields['jenis_bahaya'],
        'jenis_ketidaksesuaian': fields['jenis_ketidaksesuaian'],
        'tingkat_resiko': fields['tingkat_resiko'],
        'tindakan_perbaikan': fields['tindakan_perbaikan'],
        'pja': fields['pja'],
        'nik_pja': fields['nik_pja'],
        'departemen_pja': fields['departemen_pja'],
        'payload_json': jsonEncode(fields),
        'created_at': DateTime.now().toString(),
      };
      await _db.insert('hazard_trans', row);
      await OfflineSyncService.instance.refresh();
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      await showProfessionalSuccessSheet(
        context: context,
        title: 'Temuan Tersimpan di HP (Offline)!',
        subtitle:
            'Data tersimpan aman di perangkat dan akan dikirim otomatis saat terhubung ke internet.',
        referenceNumber: code,
        accentColor: const Color(0xFFD97706),
        icon: Icons.cloud_done_rounded,
        isOffline: true,
        statusBadgeText: 'TERSIMPAN DI PERANGKAT',
        receiptItems: [
          SuccessReceiptItem(
              label: 'Kategori Bahaya',
              value: fields['kategori_bahaya']?.toString() ?? '-',
              isHighlight: true),
          SuccessReceiptItem(
              label: 'Jenis Bahaya',
              value: fields['jenis_bahaya']?.toString() ?? '-'),
          SuccessReceiptItem(
              label: 'Tingkat Resiko',
              value: fields['tingkat_resiko']?.toString() ?? 'Sedang',
              highlightColor: const Color(0xFFEF4444)),
          SuccessReceiptItem(
              label: 'Area & Lokasi',
              value: '${fields['area']} - ${fields['lokasi']}'),
          SuccessReceiptItem(
              label: 'Penanggung Jawab (PJA)',
              value: fields['pja']?.toString() ?? '-'),
        ],
        primaryButtonText: 'Kembali ke Hub Hazard',
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      SnackBarMsg.danger(context, 'Gagal menyimpan offline: $e');
    }
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
        appBar: TopBar(
          title:
              widget.editItem != null ? 'Edit Temuan Hazard' : 'Temuan Hazard',
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
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
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFFEDD5)),
                      ),
                      child: const Icon(Icons.warning_amber_rounded,
                          color: Color(0xFFEA580C), size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Formulir Laporan Hazard',
                            style: TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 14,
                                fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Laporkan kondisi & tindakan berbahaya untuk keselamatan bersama.',
                            style: TextStyle(
                                color: Color(0xFF64748B), fontSize: 11),
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

              // SECTION 1: Waktu & Lokasi Temuan
              _buildSectionCard(
                stepNumber: '1',
                title: 'WAKTU & LOKASI KEJADIAN',
                subtitle: 'Titik koordinat satelit dan area kerja penemuan',
                icon: Icons.location_on_rounded,
                accentColor: const Color(0xFF0284C7),
                children: [
                  // Waktu & Tanggal
                  Row(
                    children: [
                      Expanded(
                        child: _buildDatePicker(
                          label: 'Tanggal Temuan',
                          date: _tanggal,
                          onTap: () async {
                            final now = DateTime.now();
                            final today =
                                DateTime(now.year, now.month, now.day);
                            final minDate =
                                today.subtract(const Duration(days: 2));
                            final initial = _tanggal.isBefore(minDate)
                                ? minDate
                                : (_tanggal.isAfter(today) ? today : _tanggal);

                            final picked = await showDatePicker(
                              context: context,
                              initialDate: initial,
                              firstDate: minDate,
                              lastDate: today,
                              helpText: 'PILIH TANGGAL (MAKS. 2 HARI TERAKHIR)',
                            );
                            if (picked != null)
                              setState(() => _tanggal = picked);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTimePicker(
                          label: 'Waktu Temuan',
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

                  // Area Utama
                  const Text('AREA UTAMA *',
                      style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)),
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
                                ? const Color(0xFFBAE6FD)
                                : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.place_rounded,
                              color: Color(0xFF0284C7), size: 20),
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
                                    strokeWidth: 2, color: Color(0xFF0284C7)))
                          else
                            const Icon(Icons.keyboard_arrow_down_rounded,
                                color: Color(0xFF64748B), size: 20),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Detail Lokasi / Benchmark
                  const Text('DETAIL LOKASI / BENCHMARK',
                      style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)),
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
                                    color: Color(0xFF0284C7), size: 20),
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
                                          strokeWidth: 2,
                                          color: Color(0xFF0284C7)))
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
                            color: const Color(0xFF0284C7),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0284C7)
                                    .withValues(alpha: 0.3),
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
                      const Text('LOKASI SPESIFIK (GPS) *',
                          style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5)),
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
                              : const Color(0xFF0284C7),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _lokasiCtrl,
                            style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
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
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          )
                        else if (_lokasiCtrl.text.isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF10B981),
                              size: 22,
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
                                color: Color(0xFF0284C7),
                                size: 22,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _lokasiCtrl.text.isNotEmpty
                            ? Icons.satellite_alt_rounded
                            : Icons.info_outline_rounded,
                        size: 13,
                        color: _lokasiCtrl.text.isNotEmpty
                            ? const Color(0xFF059669)
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          _lokasiCtrl.text.isNotEmpty
                              ? 'Titik koordinat GPS terkunci.'
                              : (_isDetectingGps
                                  ? 'Mencari sinyal satelit GPS perangkat Anda...'
                                  : 'Titik koordinat otomatis terisi via satelit GPS.'),
                          style: TextStyle(
                            color: _lokasiCtrl.text.isNotEmpty
                                ? const Color(0xFF059669)
                                : const Color(0xFF64748B),
                            fontSize: 10.5,
                            fontWeight: _lokasiCtrl.text.isNotEmpty
                                ? FontWeight.w600
                                : FontWeight.normal,
                            height: 1.3,
                          ),
                        ),
                      ),
                      if (!_isDetectingGps && _lokasiCtrl.text.isEmpty) ...[
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => _fetchCurrentGps(silent: false),
                          child: const Text(
                            'Deteksi GPS',
                            style: TextStyle(
                              color: Color(0xFF0284C7),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),

              // SECTION 2: Klasifikasi Bahaya & Tingkat Risiko
              _buildSectionCard(
                stepNumber: '2',
                title: 'KLASIFIKASI BAHAYA & TINGKAT RISIKO',
                subtitle: 'Kategori KTA/TTA, jenis bahaya, dan matriks risiko',
                icon: Icons.warning_rounded,
                accentColor: const Color(0xFFEA580C),
                children: [
                  // Kategori Bahaya (KTA vs TTA)
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('KATEGORI BAHAYA *',
                          style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5)),
                      Text('Pilih tipe temuan',
                          style: TextStyle(
                              color: Color(0xFF64748B), fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildKategoriSelector(),

                  const SizedBox(height: 16),

                  // Jenis Bahaya
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('JENIS BAHAYA *',
                          style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5)),
                      Text('Pilih jenis bahaya',
                          style: TextStyle(
                              color: Color(0xFF64748B), fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildJenisBahayaSelector(),

                  const SizedBox(height: 16),

                  // Jenis Ketidaksesuaian
                  const Text('JENIS KETIDAKSESUAIAN',
                      style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  _buildTextField(
                    controller: _ketidaksesuaianCtrl,
                    hint:
                        'MISAL: RAMBU LALU LINTAS TIDAK JELAS, TIDAK PAKAI APD',
                    icon: Icons.help_outline_rounded,
                  ),

                  const SizedBox(height: 16),

                  // Tingkat Risiko
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('TINGKAT RISIKO *',
                          style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5)),
                      Text('Matriks Keparahan & Peluang',
                          style: TextStyle(
                              color: Color(0xFF64748B), fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildTingkatRisikoSelector(),
                ],
              ),

              // SECTION 3: Uraian Temuan & Rencana Tindakan
              _buildSectionCard(
                stepNumber: '3',
                title: 'URAIAN TEMUAN & RENCANA TINDAKAN',
                subtitle: 'Detail kondisi berbahaya dan saran penanganan',
                icon: Icons.edit_note_rounded,
                accentColor: const Color(0xFF6366F1),
                children: [
                  // Detil Temuan Hazard
                  const Text('DETIL TEMUAN HAZARD *',
                      style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  _buildTextArea(
                    controller: _temuanCtrl,
                    hint: 'JELASKAN KONDISI BAHAYA SEDETAIL MUNGKIN...',
                    icon: Icons.article_outlined,
                    rows: 3,
                  ),

                  const SizedBox(height: 14),

                  // Tindakan Perbaikan Langsung
                  const Text('TINDAKAN PERBAIKAN LANGSUNG (BILA ADA)',
                      style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  _buildTextArea(
                    controller: _perbaikanCtrl,
                    hint: 'TINDAKAN KOREKSI INSTAN YANG SUDAH DILAKUKAN...',
                    icon: Icons.build_rounded,
                    rows: 2,
                  ),

                  const SizedBox(height: 14),

                  // Rencana Tindakan Lanjutan
                  const Text('RENCANA TINDAKAN LANJUTAN',
                      style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  _buildTextArea(
                    controller: _tindakanCtrl,
                    hint: 'REKOMENDASI RENCANA PERBAIKAN PERMANEN...',
                    icon: Icons.arrow_circle_right_rounded,
                    rows: 2,
                  ),
                ],
              ),

              // SECTION 4: Penanggung Jawab & Bukti Foto
              _buildSectionCard(
                stepNumber: '4',
                title: 'PENANGGUNG JAWAB & BUKTI FOTO',
                subtitle: 'Delegasi PJA dan lampiran dokumentasi lapangan',
                icon: Icons.camera_alt_rounded,
                accentColor: const Color(0xFF059669),
                children: [
                  // 1. Switch Status Penanganan (Selesai Langsung vs Butuh PJA)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _isSelfClosed
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _isSelfClosed
                              ? const Color(0xFFA7F3D0)
                              : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tindakan Sudah Selesai Langsung?',
                                style: TextStyle(
                                  color: _isSelfClosed
                                      ? const Color(0xFF065F46)
                                      : const Color(0xFF0F172A),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _isSelfClosed
                                    ? 'Status CLOSED: Bahaya telah diselesaikan langsung di tempat oleh Anda.'
                                    : 'Status OPEN: Memerlukan delegasi ke Pengawas / PJA untuk perbaikan.',
                                style: TextStyle(
                                  color: _isSelfClosed
                                      ? const Color(0xFF047857)
                                      : const Color(0xFF64748B),
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: _isSelfClosed,
                          activeThumbColor: const Color(0xFF059669),
                          onChanged: (v) {
                            setState(() {
                              _isSelfClosed = v;
                              if (v) {
                                _selectedPja =
                                    null; // Bersihkan PJA karena ditangani sendiri
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  // 2. Alokasi PJA (Hanya tampil jika Status OPEN / Belum Selesai)
                  if (!_isSelfClosed) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.person_pin_rounded,
                                      color: Color(0xFF0284C7), size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Penanggung Jawab Area (PJA) *',
                                    style: TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _lintasPerusahaan = !_lintasPerusahaan;
                                  });
                                  if (_pjaSearchCtrl.text.isNotEmpty) {
                                    _searchPjaOnline(_pjaSearchCtrl.text);
                                  }
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _lintasPerusahaan
                                        ? const Color(0xFFEFF6FF)
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: _lintasPerusahaan
                                          ? const Color(0xFF3B82F6)
                                          : const Color(0xFFCBD5E1),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _lintasPerusahaan
                                            ? Icons.corporate_fare_rounded
                                            : Icons.domain_rounded,
                                        size: 12,
                                        color: _lintasPerusahaan
                                            ? const Color(0xFF1D4ED8)
                                            : const Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _lintasPerusahaan
                                            ? 'Lintas PT'
                                            : 'Internal',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: _lintasPerusahaan
                                              ? const Color(0xFF1D4ED8)
                                              : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_selectedPja == null) ...[
                            _buildTextField(
                              controller: _pjaSearchCtrl,
                              hint: 'KETIK NIK ATAU NAMA PENGAWAS / PJA...',
                              icon: Icons.search_rounded,
                              onChanged: _searchPjaOnline,
                            ),
                            if (_isSearchingPja)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Center(
                                    child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFFEA580C)))),
                              ),
                            if (_pjaSearchCtrl.text.trim().isNotEmpty ||
                                _pjaSearchResults.isNotEmpty)
                              Container(
                                constraints:
                                    const BoxConstraints(maxHeight: 240),
                                margin: const EdgeInsets.only(top: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: const Color(0xFFCBD5E1)),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.05),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2)),
                                  ],
                                ),
                                child: ListView(
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
                                  children: [
                                    if (_pjaSearchCtrl.text
                                        .trim()
                                        .isNotEmpty) ...[
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            _selectedPja = PjaSearchResult(
                                              nik: 'MANUAL',
                                              nama: _pjaSearchCtrl.text
                                                  .trim()
                                                  .toUpperCase(),
                                              departemen: 'LAPANGAN',
                                              jabatan: 'PJA Offline',
                                              perusahaan: 'INTERNAL',
                                            );
                                            _pjaSearchResults.clear();
                                            _pjaSearchCtrl.clear();
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 10),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFEFF6FF),
                                            borderRadius: BorderRadius.vertical(
                                                top: Radius.circular(9)),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFF2563EB),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: const Icon(
                                                    Icons
                                                        .person_add_alt_1_rounded,
                                                    color: Colors.white,
                                                    size: 16),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Gunakan: "${_pjaSearchCtrl.text.trim().toUpperCase()}"',
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 12,
                                                          color: Color(
                                                              0xFF1D4ED8)),
                                                    ),
                                                    const Text(
                                                      'Gunakan nama ini sebagai PJA (Mode Offline / Bebas Ketik)',
                                                      style: TextStyle(
                                                          fontSize: 10,
                                                          color: Color(
                                                              0xFF64748B)),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const Icon(
                                                  Icons.check_circle_rounded,
                                                  size: 18,
                                                  color: Color(0xFF2563EB)),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const Divider(
                                          height: 1, color: Color(0xFFE2E8F0)),
                                    ],
                                    if (_pjaSearchResults.isNotEmpty)
                                      ListView.separated(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount: _pjaSearchResults.length,
                                        separatorBuilder: (_, __) =>
                                            const Divider(
                                                color: Color(0xFFF1F5F9),
                                                height: 1),
                                        itemBuilder: (ctx, idx) {
                                          final p = _pjaSearchResults[idx];
                                          return ListTile(
                                            dense: true,
                                            title: Text(p.nama,
                                                style: const TextStyle(
                                                    color: Color(0xFF0F172A),
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            subtitle: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                    '${p.nik} • ${p.departemen} • ${p.jabatan}',
                                                    style: const TextStyle(
                                                        color:
                                                            Color(0xFF64748B),
                                                        fontSize: 10)),
                                                const SizedBox(height: 2),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 1.5),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFFF1F5F9),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4),
                                                  ),
                                                  child: Text(
                                                    p.perusahaan,
                                                    style: const TextStyle(
                                                        color:
                                                            Color(0xFF0284C7),
                                                        fontSize: 9.5,
                                                        fontWeight:
                                                            FontWeight.w600),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            onTap: () {
                                              setState(() {
                                                _selectedPja = p;
                                                _pjaSearchResults.clear();
                                                _pjaSearchCtrl.clear();
                                              });
                                            },
                                          );
                                        },
                                      ),
                                    if (_pjaSearchResults.isEmpty &&
                                        _pjaSearchCtrl.text.trim().isNotEmpty &&
                                        !_isSearchingPja)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                            vertical: 10, horizontal: 12),
                                        child: Center(
                                          child: Text(
                                            'Tidak ada data yang cocok. Gunakan tombol di atas untuk menetapkan PJA secara manual.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 10.5,
                                                color: Color(0xFF94A3B8)),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: const Color(0xFF86EFAC)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: const Color(0xFF16A34A),
                                    child: Text(
                                      _selectedPja!.nama.isNotEmpty
                                          ? _selectedPja!.nama[0].toUpperCase()
                                          : 'P',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(_selectedPja!.nama,
                                            style: const TextStyle(
                                                color: Color(0xFF0F172A),
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold)),
                                        Text(
                                            '${_selectedPja!.nik} • ${_selectedPja!.departemen}',
                                            style: const TextStyle(
                                                color: Color(0xFF64748B),
                                                fontSize: 10)),
                                        Text(_selectedPja!.perusahaan,
                                            style: const TextStyle(
                                                color: Color(0xFF0284C7),
                                                fontSize: 10)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded,
                                        color: Color(0xFFDC2626), size: 18),
                                    onPressed: () =>
                                        setState(() => _selectedPja = null),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ] else ...[
                    // Tanda bahwa tindakan diselesaikan sendiri oleh pelapor
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_rounded,
                              color: Color(0xFF16A34A), size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Perbaikan Mandiri di Tempat',
                                  style: TextStyle(
                                      color: Color(0xFF065F46),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 1),
                                Text(
                                  'Bahaya telah diselesaikan langsung oleh Anda. Tidak memerlukan delegasi PJA.',
                                  style: TextStyle(
                                      color: Color(0xFF047857), fontSize: 10.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // 3. Upload Foto Temuan (Before)
                  const Text('Foto Bukti Temuan (Before) *',
                      style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  _buildPhotoPicker(
                    file: _fotoTemuan,
                    existingUrl: widget.editItem?.fotoTemuan,
                    label: 'Ambil / Pilih Foto Temuan (Before)',
                    badgeTitle: 'BUKTI TEMUAN (BEFORE)',
                    onTap: () => _pickImage(true),
                    onRemove: () => setState(() => _fotoTemuan = null),
                  ),

                  // 4. Upload Foto Perbaikan (After) jika selesai langsung
                  if (_isSelfClosed) ...[
                    const SizedBox(height: 16),
                    const Text('Foto Bukti Perbaikan (After) *',
                        style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    _buildPhotoPicker(
                      file: _fotoPerbaikan,
                      existingUrl: widget.editItem?.fotoPerbaikan,
                      label: 'Ambil / Pilih Foto Bukti Perbaikan (After)',
                      badgeTitle: 'BUKTI PERBAIKAN (AFTER)',
                      onTap: () => _pickImage(false),
                      onRemove: () => setState(() => _fotoPerbaikan = null),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 6),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA580C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 1,
                  ),
                  onPressed: _isSubmitting ? null : _submitHazard,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    _isSubmitting
                        ? 'MENYIMPAN LAPORAN...'
                        : 'KIRIM LAPORAN HAZARD',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        letterSpacing: 0.3),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormProgressBanner() {
    int totalSteps = 6;
    int completed = 0;
    final List<String> missing = [];

    // 1. Lokasi & Area
    if (_area.isNotEmpty && _lokasiCtrl.text.trim().isNotEmpty) {
      completed++;
    } else {
      missing.add('Lokasi/Area');
    }

    // 2. Kategori Bahaya
    if (_kategoriBahaya.isNotEmpty) {
      completed++;
    } else {
      missing.add('Kategori');
    }

    // 3. Jenis Bahaya
    if (_jenisBahaya.isNotEmpty) {
      completed++;
    } else {
      missing.add('Jenis');
    }

    // 4. Tingkat Risiko
    if (_tingkatResiko.isNotEmpty) {
      completed++;
    } else {
      missing.add('Risiko');
    }

    // 5. Uraian Temuan
    if (_temuanCtrl.text.trim().isNotEmpty) {
      completed++;
    } else {
      missing.add('Uraian Temuan');
    }

    // 6. PJA & Bukti Foto
    final bool fotoBeforeValid = _fotoTemuan != null ||
        (widget.editItem?.fotoTemuan != null &&
            widget.editItem!.fotoTemuan!.isNotEmpty);
    final bool pjaValid = _isSelfClosed || _selectedPja != null;
    final bool fotoAfterValid = !_isSelfClosed ||
        (_fotoPerbaikan != null ||
            (widget.editItem?.fotoPerbaikan != null &&
                widget.editItem!.fotoPerbaikan!.isNotEmpty));

    if (pjaValid && fotoBeforeValid && fotoAfterValid) {
      completed++;
    } else {
      if (!pjaValid) missing.add('PJA');
      if (!fotoBeforeValid) missing.add('Foto Before');
      if (!fotoAfterValid) missing.add('Foto After');
    }

    final double pct = completed / totalSteps;
    final Color barColor = pct >= 1.0
        ? const Color(0xFF059669)
        : (pct >= 0.5 ? const Color(0xFF0284C7) : const Color(0xFFEA580C));

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: barColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: barColor.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
                    pct >= 1.0
                        ? Icons.check_circle_rounded
                        : Icons.pending_actions_rounded,
                    size: 16,
                    color: barColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    pct >= 1.0
                        ? 'Semua Bagian Lengkap'
                        : 'Kelengkapan Formulir: ${(pct * 100).toInt()}%',
                    style: TextStyle(
                      color: barColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                '$completed dari $totalSteps bagian',
                style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
              minHeight: 6,
            ),
          ),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Belum lengkap: ${missing.join(", ")}',
              style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 10.5,
                  fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

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
                    border:
                        Border.all(color: accentColor.withValues(alpha: 0.3)),
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
                        style: const TextStyle(
                            color: Color(0xFF64748B), fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFFF1F5F9), height: 1, thickness: 1),
          // Section Content
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

  Widget _buildDatePicker(
      {required String label,
      required DateTime date,
      required VoidCallback onTap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const Text('Maks. H-2',
                style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500)),
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
                const Icon(Icons.calendar_month_rounded,
                    color: Color(0xFFEA580C), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    DateFormat('dd/MM/yyyy').format(date),
                    style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimePicker(
      {required String label,
      required TimeOfDay time,
      required VoidCallback onTap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 12,
                fontWeight: FontWeight.w600)),
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
                const Icon(Icons.access_time_filled_rounded,
                    color: Color(0xFFEA580C), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
        onChanged: onChanged,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 18),
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          fillColor: Colors.transparent,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildTextArea({
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    int rows = 3,
    int? maxLines,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 1, right: 10),
              child: Icon(
                icon,
                color: const Color(0xFF64748B),
                size: 18,
              ),
            ),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              minLines: rows,
              maxLines: maxLines ?? (rows + 6),
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 13,
                height: 1.4,
              ),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                fillColor: Colors.transparent,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                hintText: hint,
                hintStyle: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoPicker({
    File? file,
    String? existingUrl,
    required String label,
    String? badgeTitle,
    required VoidCallback onTap,
    required VoidCallback onRemove,
  }) {
    if (file != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              file,
              height: 140,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          // Watermark stamp overlay on photo preview
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.85),
                    Colors.black.withValues(alpha: 0.0),
                  ],
                ),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded,
                      size: 14, color: Color(0xFF10B981)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${badgeTitle ?? "BUKTI FOTO"} • ${DateFormat("yyyy-MM-dd HH:mm").format(DateTime.now())}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold),
                        ),
                        if (_lokasiCtrl.text.isNotEmpty || _area.isNotEmpty)
                          Text(
                            '${_area.isNotEmpty ? "$_area | " : ""}${_lokasiCtrl.text}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Color(0xFFCBD5E1), fontSize: 8.5),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: InkWell(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      );
    }

    if (existingUrl != null && existingUrl.isNotEmpty) {
      final fullUrl = existingUrl.startsWith('http')
          ? existingUrl
          : '${ApiService().baseUrl}$existingUrl';
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              fullUrl,
              height: 140,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox(),
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
              onPressed: onTap,
              icon: const Icon(Icons.camera_alt_rounded, size: 14),
              label: const Text('Ganti Foto', style: TextStyle(fontSize: 11)),
            ),
          ),
        ],
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 92,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFEA580C).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFFEA580C).withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.add_a_photo_rounded,
                  color: Color(0xFFEA580C), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Kamera langsung atau Galeri HP',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFF94A3B8), size: 20),
          ],
        ),
      ),
    );
  }
}

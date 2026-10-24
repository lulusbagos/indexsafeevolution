import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api.dart';
import '../../services/database.dart';
import '../../services/preference.dart';
import '../../widgets/top_bar.dart';
import 'fci_model.dart';

class FciFormPage extends StatefulWidget {
  final FciReportItem? editData;

  const FciFormPage({super.key, this.editData});

  @override
  State<FciFormPage> createState() => _FciFormPageState();
}

class _FciFormPageState extends State<FciFormPage> {
  final _api = ApiService();
  final _db = DatabaseService();
  final _picker = ImagePicker();

  final _formKey = GlobalKey<FormState>();

  // Lokasi & Waktu
  late DateTime _tanggal;
  late TimeOfDay _waktu;
  final _areaCtrl = TextEditingController();
  final _detilLokasiCtrl = TextEditingController();
  final _pitCtrl = TextEditingController();
  final _namaFrontCtrl = TextEditingController();
  final _lokasiCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  String _shift = 'Shift 1 (Siang)';

  // 8 Parameters (100, 70, 40)
  int _skorLantaiFront = 100;
  int _skorRuangManuver = 100;
  int _skorSafetyBerm = 100;
  int _skorKondisiDinding = 100;
  int _skorDrainaseSump = 100;
  int _skorKebersihanSpillage = 100;
  int _skorPosisiAlat = 100;
  int _skorRambuPenerangan = 100;

  // Catatan, Tindakan, Foto
  final _catatanCtrl = TextEditingController();
  final _tindakanCtrl = TextEditingController();
  final _picCtrl = TextEditingController();
  _FciEmployeeItem? _selectedPicEmployee;
  File? _fotoFile;
  String? _existingFotoUrl;

  bool _isSaving = false;
  bool _isLoadingGps = false;

  // Master Area & Benchmark
  List<String> _masterAreas = [];
  List<String> _masterBenchmarks = [];
  bool _isLoadingAreas = false;
  bool _isLoadingBenchmarks = false;
  VoidCallback? _onAreasLoadedModal;
  VoidCallback? _onBenchmarksLoadedModal;

  static const _tealColor = Color(0xFF0F766E);
  static const _tealAccent = Color(0xFF14B8A6);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _tanggal = DateTime(now.year, now.month, now.day);
    _waktu = TimeOfDay.now();

    if (widget.editData != null) {
      final d = widget.editData!;
      _tanggal = d.tanggal;
      final parts = d.waktu.split(':');
      if (parts.length >= 2) {
        _waktu = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? now.hour,
          minute: int.tryParse(parts[1]) ?? now.minute,
        );
      }
      _areaCtrl.text = d.area;
      _detilLokasiCtrl.text = d.detilLokasi ?? '';
      _pitCtrl.text = d.pit ?? '';
      _namaFrontCtrl.text = d.namaFront ?? '';
      _lokasiCtrl.text = d.lokasi;
      _latCtrl.text = d.latitude ?? '';
      _lngCtrl.text = d.longitude ?? '';
      _shift = d.shift ?? 'Shift 1 (Siang)';

      _skorLantaiFront = d.skorLantaiFront;
      _skorRuangManuver = d.skorRuangManuver;
      _skorSafetyBerm = d.skorSafetyBerm;
      _skorKondisiDinding = d.skorKondisiDinding;
      _skorDrainaseSump = d.skorDrainaseSump;
      _skorKebersihanSpillage = d.skorKebersihanSpillage;
      _skorPosisiAlat = d.skorPosisiAlat;
      _skorRambuPenerangan = d.skorRambuPenerangan;

      _catatanCtrl.text = d.catatan ?? '';
      _tindakanCtrl.text = d.tindakanPerbaikan ?? '';
      _picCtrl.text = d.pic ?? '';
      _existingFotoUrl = d.fotoUrl;
    }

    _loadAreas();
    if (_areaCtrl.text.isNotEmpty) {
      _loadBenchmarks(_areaCtrl.text);
    }
  }

  @override
  void dispose() {
    _areaCtrl.dispose();
    _detilLokasiCtrl.dispose();
    _pitCtrl.dispose();
    _namaFrontCtrl.dispose();
    _lokasiCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _catatanCtrl.dispose();
    _tindakanCtrl.dispose();
    _picCtrl.dispose();
    super.dispose();
  }

  // Live Score Calculation
  double get _totalScore {
    final s = (_skorLantaiFront * 0.15) +
        (_skorRuangManuver * 0.15) +
        (_skorSafetyBerm * 0.15) +
        (_skorKondisiDinding * 0.15) +
        (_skorDrainaseSump * 0.10) +
        (_skorKebersihanSpillage * 0.10) +
        (_skorPosisiAlat * 0.10) +
        (_skorRambuPenerangan * 0.10);
    return double.parse(s.toStringAsFixed(1));
  }

  String get _kategoriIndex {
    if (_totalScore >= 85) return 'Baik';
    if (_totalScore >= 70) return 'Sedang';
    return 'Kurang';
  }

  Color get _categoryColor {
    if (_totalScore >= 85) return const Color(0xFF10B981);
    if (_totalScore >= 70) return const Color(0xFFF59E0B);
    return const Color(0xFFF43F5E);
  }

  // Load Areas
  Future<void> _loadAreas() async {
    setState(() => _isLoadingAreas = true);
    try {
      final profile = PreferenceService.getProfile();
      final companyId = profile?.companyId;

      final sqldb = await _db.database;
      final localAreas = await sqldb.rawQuery(
        "SELECT DISTINCT area_utama FROM tbl_m_benchmark WHERE area_utama IS NOT NULL AND area_utama != '' ORDER BY area_utama",
      );

      if (localAreas.isNotEmpty && mounted) {
        setState(() {
          _masterAreas = localAreas.map((e) => e['area_utama'].toString().trim()).toList();
        });
        _onAreasLoadedModal?.call();
      }

      final serverAreas = await _api.getMasterAreas(perusahaanId: companyId);
      if (serverAreas.isNotEmpty && mounted) {
        setState(() {
          _masterAreas = serverAreas;
          _isLoadingAreas = false;
        });
        _onAreasLoadedModal?.call();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingAreas = false);
    }
  }

  // Load Benchmarks for Area
  Future<void> _loadBenchmarks(String area) async {
    final cleanArea = area.trim();
    if (cleanArea.isEmpty) return;
    setState(() => _isLoadingBenchmarks = true);
    try {
      final profile = PreferenceService.getProfile();
      final companyId = profile?.companyId;

      final sqldb = await _db.database;
      final localBM = await sqldb.rawQuery(
        "SELECT DISTINCT nama_benchmark FROM tbl_m_benchmark WHERE area_utama = ? AND nama_benchmark IS NOT NULL AND nama_benchmark != '' ORDER BY nama_benchmark",
        [cleanArea],
      );

      if (localBM.isNotEmpty && mounted) {
        setState(() {
          _masterBenchmarks = localBM.map((e) => e['nama_benchmark'].toString().trim()).toList();
        });
        _onBenchmarksLoadedModal?.call();
      }

      final serverBM = await _api.getBenchmarks(cleanArea, perusahaanId: companyId);
      if (serverBM.isNotEmpty && mounted) {
        setState(() {
          _masterBenchmarks = serverBM;
          _isLoadingBenchmarks = false;
        });
        _onBenchmarksLoadedModal?.call();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingBenchmarks = false);
    }
  }

  // GPS Fetch
  Future<void> _getGpsLocation() async {
    setState(() => _isLoadingGps = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack('Layanan GPS / Lokasi tidak aktif. Silakan aktifkan GPS.');
        setState(() => _isLoadingGps = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnack('Izin lokasi ditolak');
          setState(() => _isLoadingGps = false);
          return;
        }
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      setState(() {
        _latCtrl.text = pos.latitude.toStringAsFixed(6);
        _lngCtrl.text = pos.longitude.toStringAsFixed(6);
        if (_lokasiCtrl.text.isEmpty) {
          _lokasiCtrl.text = '${_areaCtrl.text} (${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})';
        }
        _isLoadingGps = false;
      });
      _showSnack('Koordinat GPS berhasil diperoleh!', isSuccess: true);
    } catch (e) {
      setState(() => _isLoadingGps = false);
      _showSnack('Gagal mengambil koordinat GPS: $e');
    }
  }

  // Photo Pickers
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 82,
      );
      if (picked != null) {
        setState(() {
          _fotoFile = File(picked.path);
        });
      }
    } catch (e) {
      _showSnack('Gagal memilih foto: $e');
    }
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // Area Picker BottomSheet
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
              height: MediaQuery.of(context).size.height * 0.82,
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
                    decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
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
                            Text('Pilih Area Utama', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                            Text('Pilih atau ketik untuk mencari area', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(modalCtx),
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        onChanged: (val) => setModalState(() => filter = val),
                        decoration: InputDecoration(
                          hintText: 'Cari area utama...',
                          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                          border: InputBorder.none,
                          suffixIcon: filter.isNotEmpty
                              ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setModalState(() => filter = ''))
                              : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (canAddCustom)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(modalCtx);
                          setState(() {
                            _areaCtrl.text = filter.trim();
                            _loadBenchmarks(filter.trim());
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDFA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _tealAccent),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.add_circle, color: _tealAccent),
                              const SizedBox(width: 10),
                              Expanded(child: Text('Gunakan "${filter.trim()}"', style: const TextStyle(fontWeight: FontWeight.bold, color: _tealColor))),
                              const Icon(Icons.arrow_forward_ios, size: 14, color: _tealColor),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (_, idx) {
                        final item = filtered[idx];
                        final isSelected = item == _areaCtrl.text;
                        return ListTile(
                          title: Text(item, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? _tealColor : const Color(0xFF1E293B))),
                          trailing: isSelected ? const Icon(Icons.check_circle, color: _tealColor) : null,
                          onTap: () {
                            Navigator.pop(modalCtx);
                            setState(() {
                              _areaCtrl.text = item;
                              _loadBenchmarks(item);
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

  // Benchmark Picker BottomSheet
  void _showBenchmarkPickerModal() {
    if (_areaCtrl.text.isEmpty) {
      _showSnack('Pilih Area Utama terlebih dahulu');
      return;
    }

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

            final filtered = _masterBenchmarks.where((b) => b.toLowerCase().contains(filter.toLowerCase())).toList();
            final hasExactMatch = _masterBenchmarks.any((b) => b.toLowerCase() == filter.trim().toLowerCase());
            final canAddCustom = filter.trim().isNotEmpty && !hasExactMatch;

            return Container(
              height: MediaQuery.of(context).size.height * 0.82,
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
                    decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Pilih Benchmark / Detail Lokasi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text('Area: ${_areaCtrl.text}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(modalCtx),
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        onChanged: (val) => setModalState(() => filter = val),
                        decoration: InputDecoration(
                          hintText: 'Cari atau ketik benchmark baru...',
                          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                          border: InputBorder.none,
                          suffixIcon: filter.isNotEmpty
                              ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setModalState(() => filter = ''))
                              : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (canAddCustom)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(modalCtx);
                          setState(() {
                            _detilLokasiCtrl.text = filter.trim();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDFA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _tealAccent),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.add_circle, color: _tealAccent),
                              const SizedBox(width: 10),
                              Expanded(child: Text('Gunakan "${filter.trim()}"', style: const TextStyle(fontWeight: FontWeight.bold, color: _tealColor))),
                              const Icon(Icons.arrow_forward_ios, size: 14, color: _tealColor),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (_, idx) {
                        final item = filtered[idx];
                        final isSelected = item == _detilLokasiCtrl.text;
                        return ListTile(
                          title: Text(item, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? _tealColor : const Color(0xFF1E293B))),
                          trailing: isSelected ? const Icon(Icons.check_circle, color: _tealColor) : null,
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

  // Employee / PIC Search
  Future<List<_FciEmployeeItem>> _searchEmployees(String query) async {
    final cleanQ = query.trim().replaceAll("'", "''");
    final list = <_FciEmployeeItem>[];

    // 1. Search local SQLite employees table
    try {
      final sqldb = await _db.database;
      final rows = await sqldb.rawQuery(
        cleanQ.isEmpty
            ? "SELECT no_nik, nama_lengkap, depart, posisi, departemen, jabatan, perusahaan FROM employees WHERE no_nik IS NOT NULL AND nama_lengkap IS NOT NULL AND nama_lengkap != '' LIMIT 35"
            : "SELECT no_nik, nama_lengkap, depart, posisi, departemen, jabatan, perusahaan FROM employees WHERE (no_nik LIKE '%$cleanQ%' OR nama_lengkap LIKE '%$cleanQ%' OR depart LIKE '%$cleanQ%') AND nama_lengkap IS NOT NULL LIMIT 40",
      );

      for (final r in rows) {
        list.add(_FciEmployeeItem(
          nik: r['no_nik']?.toString().trim() ?? '',
          nama: r['nama_lengkap']?.toString().trim() ?? '',
          departemen: (r['departemen'] ?? r['depart'])?.toString().trim() ?? '',
          jabatan: (r['jabatan'] ?? r['posisi'])?.toString().trim() ?? '',
          perusahaan: r['perusahaan']?.toString().trim() ?? '',
        ));
      }
    } catch (e) {
      debugPrint('[FciFormPage] Local employee query error: $e');
    }

    // 2. Fallback / Search via Server API if local is small
    if (list.length < 5 && cleanQ.isNotEmpty) {
      try {
        final res = await _api.searchPja(cleanQ, lintasPerusahaan: true);
        res.fold((_) {}, (serverData) {
          for (final item in serverData) {
            final nik = item['nik']?.toString().trim() ?? '';
            final nama = item['nama']?.toString().trim() ?? '';
            if (nik.isNotEmpty && nama.isNotEmpty && !list.any((x) => x.nik == nik)) {
              list.add(_FciEmployeeItem(
                nik: nik,
                nama: nama,
                departemen: (item['departemen'] ?? item['depart'])?.toString().trim() ?? '',
                jabatan: (item['jabatan'] ?? item['posisi'])?.toString().trim() ?? '',
                perusahaan: item['perusahaan']?.toString().trim() ?? '',
              ));
            }
          }
        });
      } catch (_) {}
    }

    return list;
  }

  void _showEmployeePickerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String filter = '';
        List<_FciEmployeeItem> results = [];
        bool isSearching = true;

        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            void performSearch(String q) async {
              setModalState(() => isSearching = true);
              final res = await _searchEmployees(q);
              if (modalCtx.mounted) {
                setModalState(() {
                  results = res;
                  isSearching = false;
                });
              }
            }

            if (results.isEmpty && isSearching && filter.isEmpty) {
              performSearch('');
            }

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
                    decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
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
                            Text('Pilih PIC Tindakan Perbaikan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text('Pilih pengawas / personil dari data karyawan', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(modalCtx),
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
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
                        onChanged: (val) {
                          filter = val;
                          performSearch(val);
                        },
                        decoration: InputDecoration(
                          hintText: 'Cari nama, NIK, atau departemen...',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          prefixIcon: const Icon(Icons.search_rounded, color: _tealColor),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          suffixIcon: filter.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () {
                                    setModalState(() => filter = '');
                                    performSearch('');
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: isSearching
                        ? const Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: _tealColor),
                            ),
                          )
                        : results.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.person_search_rounded, size: 48, color: Colors.blueGrey.shade200),
                                    const SizedBox(height: 10),
                                    const Text('Data karyawan tidak ditemukan', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                                    const SizedBox(height: 4),
                                    const Text('Coba gunakan kata kunci pencarian yang lain', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                itemCount: results.length,
                                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                itemBuilder: (_, idx) {
                                  final emp = results[idx];
                                  final isSelected = _picCtrl.text.contains(emp.nik) || (_selectedPicEmployee?.nik == emp.nik);

                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    leading: CircleAvatar(
                                      backgroundColor: isSelected ? _tealColor : const Color(0xFFF0FDFA),
                                      foregroundColor: isSelected ? Colors.white : _tealColor,
                                      child: Text(
                                        emp.nama.isNotEmpty ? emp.nama[0].toUpperCase() : 'P',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    title: Text(
                                      emp.nama,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                        color: isSelected ? _tealColor : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    subtitle: Text(
                                      'NIK: ${emp.nik}${emp.departemen.isNotEmpty ? " • ${emp.departemen}" : ""}${emp.jabatan.isNotEmpty ? " • ${emp.jabatan}" : ""}',
                                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                    ),
                                    trailing: isSelected ? const Icon(Icons.check_circle, color: _tealColor) : null,
                                    onTap: () {
                                      Navigator.pop(modalCtx);
                                      setState(() {
                                        _selectedPicEmployee = emp;
                                        _picCtrl.text = emp.displayName;
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

  // Auto Recommendation logic
  String _generateAutoRecommendation() {
    final deficits = <String>[];
    if (_skorLantaiFront < 100) deficits.add('Lantai front bergelombang/amblas perlu dirapikan dengan dozer');
    if (_skorRuangManuver < 100) deficits.add('Perluas ruang manuver & spotting dump truck');
    if (_skorSafetyBerm < 100) deficits.add('Tinggikan safety berm front minimal 3/4 diameter roda alat angkut');
    if (_skorKondisiDinding < 100) deficits.add('Scaling dinding highwall & bersihkan potensi batuan menggantung/overhang');
    if (_skorDrainaseSump < 100) deficits.add('Optimalkan pompa sump dan buat parit drainase bebas genangan');
    if (_skorKebersihanSpillage < 100) deficits.add('Bersihkan ceceran boulder batuan keras di loading floor');
    if (_skorPosisiAlat < 100) deficits.add('Sesuaikan bench height agar pas dengan jangkauan optimal alat gali');
    if (_skorRambuPenerangan < 100) deficits.add('Lengkapi rambu K3 dan aktifkan tower lamp untuk kerja malam');

    if (deficits.isEmpty) {
      return 'Pertahankan kondisi standar kerja di front loading.';
    }
    return deficits.join('; ') + '.';
  }

  void _applyAutoRecommendation() {
    final rec = _generateAutoRecommendation();
    setState(() {
      _tindakanCtrl.text = rec;
    });
    _showSnack('Rekomendasi otomatis diterapkan ke form perbaikan!', isSuccess: true);
  }

  // Share to WhatsApp
  Future<void> _shareToWhatsApp() async {
    final tglStr = DateFormat('dd MMM yyyy').format(_tanggal);
    final waktuStr = '${_waktu.hour.toString().padLeft(2, '0')}:${_waktu.minute.toString().padLeft(2, '0')}';

    final text = StringBuffer();
    text.writeln('📋 *LAPORAN PENILAIAN FRONT CONDITION INDEX (FCI)*');
    text.writeln('📅 Waktu: $tglStr $waktuStr | Shift: $_shift');
    text.writeln('📍 Area: ${_areaCtrl.text} | Front: ${_namaFrontCtrl.text} | Pit: ${_pitCtrl.text}');
    if (_detilLokasiCtrl.text.isNotEmpty) text.writeln('📌 Benchmark: ${_detilLokasiCtrl.text}');
    text.writeln('---------------------------------------');
    text.writeln('⭐ *SKOR FCI: $_totalScore% ($_kategoriIndex.toUpperCase())*');
    text.writeln('1. Lantai Front (15%): $_skorLantaiFront');
    text.writeln('2. Ruang Manuver (15%): $_skorRuangManuver');
    text.writeln('3. Safety Berm (15%): $_skorSafetyBerm');
    text.writeln('4. Kondisi Dinding (15%): $_skorKondisiDinding');
    text.writeln('5. Drainase Sump (10%): $_skorDrainaseSump');
    text.writeln('6. Kebersihan Spillage (10%): $_skorKebersihanSpillage');
    text.writeln('7. Posisi Alat Bench (10%): $_skorPosisiAlat');
    text.writeln('8. Rambu & Penerangan (10%): $_skorRambuPenerangan');
    text.writeln('---------------------------------------');
    if (_catatanCtrl.text.isNotEmpty) text.writeln('📝 *Catatan:* ${_catatanCtrl.text}');
    if (_tindakanCtrl.text.isNotEmpty) text.writeln('🛠️ *Tindakan Perbaikan:* ${_tindakanCtrl.text} (PIC: ${_picCtrl.text})');
    text.writeln('\n_Dilaporkan via SAP Mobile - Indexsafe Evolution_');

    final uri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(text.toString())}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await Clipboard.setData(ClipboardData(text: text.toString()));
        _showSnack('Teks berhasil disalin ke clipboard!', isSuccess: true);
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text.toString()));
      _showSnack('Teks berhasil disalin ke clipboard!', isSuccess: true);
    }
  }

  // Submit Report
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      _showSnack('Lengkapi field yang wajib diisi');
      return;
    }

    if (_areaCtrl.text.trim().isEmpty) {
      _showSnack('Area Utama wajib dipilih');
      return;
    }

    // Anti-Backdate Validation
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final reportDate = DateTime(_tanggal.year, _tanggal.month, _tanggal.day);

    if (widget.editData == null && reportDate.isBefore(today)) {
      _showSnack('Tanggal inspeksi tidak boleh backdate (kurang dari hari ini)');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final profile = PreferenceService.getProfile();
      final userNik = profile?.noNik ?? PreferenceService.getUser() ?? '';
      final userName = profile?.namaLengkap ?? '';
      final userDept = profile?.depart ?? '';
      final userCompany = profile?.company ?? '';
      final userCompanyId = profile?.companyId ?? 0;
      final waktuStr = '${_waktu.hour.toString().padLeft(2, '0')}:${_waktu.minute.toString().padLeft(2, '0')}';

      final map = <String, dynamic>{
        if (widget.editData != null) 'id': widget.editData!.id,
        'tanggal': DateFormat('yyyy-MM-dd').format(_tanggal),
        'waktu': waktuStr,
        'area': _areaCtrl.text.trim(),
        'detil_lokasi': _detilLokasiCtrl.text.trim(),
        'detilLokasi': _detilLokasiCtrl.text.trim(),
        'pit': _pitCtrl.text.trim(),
        'nama_front': _namaFrontCtrl.text.trim(),
        'namaFront': _namaFrontCtrl.text.trim(),
        'lokasi': _lokasiCtrl.text.trim().isNotEmpty ? _lokasiCtrl.text.trim() : _areaCtrl.text.trim(),
        'shift': _shift,
        'latitude': _latCtrl.text.trim(),
        'longitude': _lngCtrl.text.trim(),
        'skor_lantai_front': _skorLantaiFront,
        'skor_ruang_manuver': _skorRuangManuver,
        'skor_safety_berm': _skorSafetyBerm,
        'skor_kondisi_dinding': _skorKondisiDinding,
        'skor_drainase_sump': _skorDrainaseSump,
        'skor_kebersihan_spillage': _skorKebersihanSpillage,
        'skor_posisi_alat': _skorPosisiAlat,
        'skor_rambu_penerangan': _skorRambuPenerangan,
        'catatan': _catatanCtrl.text.trim(),
        'tindakan_perbaikan': _tindakanCtrl.text.trim(),
        'pic': _picCtrl.text.trim(),
        'nik': userNik,
        'nama': userName,
        'departemen': userDept,
        'perusahaan': userCompany,
        'perusahaan_id': userCompanyId,
      };

      if (_fotoFile != null) {
        map['foto'] = await MultipartFile.fromFile(_fotoFile!.path);
      }

      final formData = FormData.fromMap(map);
      final res = await _api.saveFciReport(formData);

      setState(() => _isSaving = false);

      res.fold(
        (err) => _showSnack(err['message']?.toString() ?? 'Gagal menyimpan laporan FCI'),
        (succ) async {
          try {
            await HapticFeedback.heavyImpact();
          } catch (_) {}

          if (mounted) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Color(0xFF10B981), size: 28),
                    SizedBox(width: 10),
                    Text('Berhasil Disimpan!'),
                  ],
                ),
                content: Text(
                  widget.editData != null
                      ? 'Laporan FCI berhasil diperbarui.'
                      : 'Laporan FCI baru berhasil dikirim dan tersimpan di sistem.',
                ),
                actions: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _tealColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pop(context, true);
                    },
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        },
      );
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnack('Terjadi kesalahan: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final minDate = widget.editData != null && widget.editData!.tanggal.isBefore(today)
        ? widget.editData!.tanggal
        : today;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: TopBar(title: widget.editData != null ? 'Edit Penilaian FCI' : 'Form Penilaian FCI'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
          children: [
            // Header Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_tealColor, Color(0xFF0D9488)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(color: Color(0x330F766E), blurRadius: 14, offset: Offset(0, 6)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.compass_calibration_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Front Condition Index (FCI)',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Inspeksi standar kelayakan front loading & digging area tambang.',
                          style: TextStyle(color: Color(0xFFCCFBF1), fontSize: 11.5, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // SECTION 1: LOKASI & WAKTU
            _buildSectionHeader('1. INFORMASI LOKASI & WAKTU', Icons.location_on_rounded),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tanggal & Waktu Row
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _tanggal.isBefore(minDate) ? minDate : _tanggal,
                                firstDate: minDate, // NO BACKDATE
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setState(() => _tanggal = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Tanggal (Tidak backdate)', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today_rounded, size: 16, color: _tealColor),
                                      const SizedBox(width: 8),
                                      Text(
                                        DateFormat('dd MMM yyyy').format(_tanggal),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ],
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
                                initialTime: _waktu,
                              );
                              if (picked != null) {
                                setState(() => _waktu = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Waktu', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.access_time_rounded, size: 16, color: _tealColor),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${_waktu.hour.toString().padLeft(2, '0')}:${_waktu.minute.toString().padLeft(2, '0')}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Area Utama Picker
                    InkWell(
                      onTap: _showAreaPickerModal,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.apartment_rounded, color: _tealColor, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Area Utama *', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  const SizedBox(height: 2),
                                  Text(
                                    _areaCtrl.text.isEmpty ? 'Pilih Area Utama...' : _areaCtrl.text,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                      color: _areaCtrl.text.isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Detail Lokasi / Benchmark Picker
                    InkWell(
                      onTap: _showBenchmarkPickerModal,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.pin_drop_rounded, color: _tealColor, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Detail Lokasi / Benchmark', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  const SizedBox(height: 2),
                                  Text(
                                    _detilLokasiCtrl.text.isEmpty ? 'Pilih / ketik benchmark...' : _detilLokasiCtrl.text,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                      color: _detilLokasiCtrl.text.isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Pit / Sektor & Nama Front
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _pitCtrl,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              labelText: 'Pit / Sektor *',
                              hintText: 'Misal: Pit 1',
                              prefixIcon: const Icon(Icons.layers_rounded, size: 18, color: _tealColor),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _namaFrontCtrl,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              labelText: 'Nama Front *',
                              hintText: 'Front OB EX-01',
                              prefixIcon: const Icon(Icons.terrain_rounded, size: 18, color: _tealColor),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Shift Selector
                    DropdownButtonFormField<String>(
                      value: _shift,
                      decoration: InputDecoration(
                        labelText: 'Shift Kerja',
                        prefixIcon: const Icon(Icons.wb_sunny_rounded, size: 18, color: _tealColor),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Shift 1 (Siang)', child: Text('Shift 1 (Siang)')),
                        DropdownMenuItem(value: 'Shift 2 (Malam)', child: Text('Shift 2 (Malam)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _shift = val);
                      },
                    ),

                    const SizedBox(height: 12),

                    // Lokasi Spesifik & GPS
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _lokasiCtrl,
                            decoration: InputDecoration(
                              labelText: 'Lokasi Spesifik / Deskripsi',
                              hintText: 'Misal: RL 50 Seam B',
                              prefixIcon: const Icon(Icons.my_location_rounded, size: 18, color: _tealColor),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _isLoadingGps ? null : _getGpsLocation,
                          icon: _isLoadingGps
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.gps_fixed_rounded, size: 20),
                          style: IconButton.styleFrom(
                            backgroundColor: _tealColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.all(13),
                          ),
                        ),
                      ],
                    ),

                    if (_latCtrl.text.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Koordinat GPS: ${_latCtrl.text}, ${_lngCtrl.text}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 22),

            // SECTION 2: 8 PARAMETERS
            _buildSectionHeader('2. PENILAIAN 8 PARAMETER FRONT', Icons.analytics_rounded),
            const SizedBox(height: 6),

            // Param 1
            _buildParamCard(
              index: 1,
              title: 'Lantai Front (Front Floor)',
              weight: '15%',
              guideline: 'Rata, padat, bebas amblas & genangan lumpur',
              icon: Icons.grid_view_rounded,
              currentVal: _skorLantaiFront,
              options: const [
                _ScoreOption(100, 'Standar (Rata & Padat)', Icons.check_circle_rounded),
                _ScoreOption(70, 'Bergelombang / Undulasi', Icons.warning_rounded),
                _ScoreOption(40, 'Amblas / Becek Parah', Icons.cancel_rounded),
              ],
              onSelect: (val) => setState(() => _skorLantaiFront = val),
            ),

            // Param 2
            _buildParamCard(
              index: 2,
              title: 'Ruang Manuver & Spotting',
              weight: '15%',
              guideline: 'Cukup double spotting & manuver aman dump truck',
              icon: Icons.open_with_rounded,
              currentVal: _skorRuangManuver,
              options: const [
                _ScoreOption(100, 'Luas & Double Spotting', Icons.check_circle_rounded),
                _ScoreOption(70, 'Pas-pasan (Single Spotting)', Icons.warning_rounded),
                _ScoreOption(40, 'Sempit / Bahaya Senggolan', Icons.cancel_rounded),
              ],
              onSelect: (val) => setState(() => _skorRuangManuver = val),
            ),

            // Param 3
            _buildParamCard(
              index: 3,
              title: 'Safety Berm / Tanggul Front',
              weight: '15%',
              guideline: 'Tinggi ≥ 3/4 diameter roda unit alat angkut',
              icon: Icons.shield_rounded,
              currentVal: _skorSafetyBerm,
              options: const [
                _ScoreOption(100, '≥ 3/4 Ban & Kokoh', Icons.check_circle_rounded),
                _ScoreOption(70, 'Kurang Tinggi (1/2 Ban)', Icons.warning_rounded),
                _ScoreOption(40, 'Tidak Ada Tanggul / Drop-off', Icons.cancel_rounded),
              ],
              onSelect: (val) => setState(() => _skorSafetyBerm = val),
            ),

            // Param 4
            _buildParamCard(
              index: 4,
              title: 'Kondisi Dinding / Highwall',
              weight: '15%',
              guideline: 'Bebas overhang, retakan & rawan longsor',
              icon: Icons.filter_hdr_rounded,
              currentVal: _skorKondisiDinding,
              options: const [
                _ScoreOption(100, 'Dinding Aman & Stabil', Icons.check_circle_rounded),
                _ScoreOption(70, 'Retak Halus / Menggantung', Icons.warning_rounded),
                _ScoreOption(40, 'Overhang / Rawan Longsor', Icons.cancel_rounded),
              ],
              onSelect: (val) => setState(() => _skorKondisiDinding = val),
            ),

            // Param 5
            _buildParamCard(
              index: 5,
              title: 'Drainase & Sump Front',
              weight: '10%',
              guideline: 'Air mengalir ke sump, bebas genangan air',
              icon: Icons.water_drop_rounded,
              currentVal: _skorDrainaseSump,
              options: const [
                _ScoreOption(100, 'Kering & Lancar', Icons.check_circle_rounded),
                _ScoreOption(70, 'Ada Genangan Air', Icons.warning_rounded),
                _ScoreOption(40, 'Terendam Air / Sump Penuh', Icons.cancel_rounded),
              ],
              onSelect: (val) => setState(() => _skorDrainaseSump = val),
            ),

            // Param 6
            _buildParamCard(
              index: 6,
              title: 'Kebersihan Ceceran Material',
              weight: '10%',
              guideline: 'Bebas ceceran batuan keras / boulder tajam',
              icon: Icons.cleaning_services_rounded,
              currentVal: _skorKebersihanSpillage,
              options: const [
                _ScoreOption(100, 'Bersih Rapi Bebas Boulder', Icons.check_circle_rounded),
                _ScoreOption(70, 'Ada Ceceran Batuan', Icons.warning_rounded),
                _ScoreOption(40, 'Boulder Berserakan di Lantai', Icons.cancel_rounded),
              ],
              onSelect: (val) => setState(() => _skorKebersihanSpillage = val),
            ),

            // Param 7
            _buildParamCard(
              index: 7,
              title: 'Posisi & Ketinggian Alat (Bench)',
              weight: '10%',
              guideline: 'Bench height pas dengan jangkauan alat gali',
              icon: Icons.construction_rounded,
              currentVal: _skorPosisiAlat,
              options: const [
                _ScoreOption(100, 'Optimal Jangkauan Gali', Icons.check_circle_rounded),
                _ScoreOption(70, 'Agak Tinggi / Sudut Terbatas', Icons.warning_rounded),
                _ScoreOption(40, 'Terlalu Tinggi / Undercut', Icons.cancel_rounded),
              ],
              onSelect: (val) => setState(() => _skorPosisiAlat = val),
            ),

            // Param 8
            _buildParamCard(
              index: 8,
              title: 'Rambu & Penerangan Front',
              weight: '10%',
              guideline: 'Rambu petunjuk & tower lamp aktif malam hari',
              icon: Icons.lightbulb_rounded,
              currentVal: _skorRambuPenerangan,
              options: const [
                _ScoreOption(100, 'Terang & Rambu Lengkap', Icons.check_circle_rounded),
                _ScoreOption(70, 'Kurang Terang / Kusam', Icons.warning_rounded),
                _ScoreOption(40, 'Gelap / Tanpa Rambu', Icons.cancel_rounded),
              ],
              onSelect: (val) => setState(() => _skorRambuPenerangan = val),
            ),

            const SizedBox(height: 14),

            // LIVE CONCLUSION CARD (Matching Web)
            _buildConclusionCard(),

            const SizedBox(height: 22),

            // SECTION 3: FOTO DOKUMENTASI & TINDAKAN
            _buildSectionHeader('3. FOTO DOKUMENTASI & TINDAKAN', Icons.camera_alt_rounded),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 3)),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Catatan Observasi
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.notes_rounded, size: 16, color: _tealColor),
                            SizedBox(width: 8),
                            Text(
                              'Catatan Observasi Kondisi Front',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: _catatanCtrl,
                          maxLines: 2,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                          decoration: const InputDecoration(
                            hintText: 'Tuliskan temuan atau catatan kondisi aktual di front...',
                            hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.only(top: 4, bottom: 2),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 2. Tindakan Perbaikan
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.handyman_rounded, size: 16, color: _tealColor),
                                SizedBox(width: 8),
                                Text(
                                  'Rekomendasi Tindakan Perbaikan',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                ),
                              ],
                            ),
                            InkWell(
                              onTap: _applyAutoRecommendation,
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _tealAccent.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.bolt_rounded, size: 13, color: _tealColor),
                                    SizedBox(width: 3),
                                    Text('Auto Rekomendasi', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: _tealColor)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: _tindakanCtrl,
                          maxLines: 2,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                          decoration: const InputDecoration(
                            hintText: 'Misal: Perlu dozer merapikan lantai & menaikkan tanggul crest...',
                            hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.only(top: 4, bottom: 2),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 3. PIC Tindakan Perbaikan (Pilih dari Data Karyawan)
                  const Text(
                    'PIC Tindakan Perbaikan (Data Karyawan)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 6),
                  _buildPicSelector(),

                  const SizedBox(height: 16),

                  // 4. Foto Dokumentasi Front (Ultra-Premium Card)
                  const Text(
                    'Foto Dokumentasi Kondisi Front',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 6),
                  _buildPremiumPhotoCard(),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _submit,
                icon: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, color: Colors.white),
                label: Text(
                  _isSaving
                      ? 'Menyimpan...'
                      : (widget.editData != null ? 'Perbarui Laporan FCI' : 'Simpan Laporan FCI'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _tealColor,
                  disabledBackgroundColor: const Color(0xFF94A3B8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _tealColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF475569),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParamCard({
    required int index,
    required String title,
    required String weight,
    required String guideline,
    required IconData icon,
    required int currentVal,
    required List<_ScoreOption> options,
    required ValueChanged<int> onSelect,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: currentVal < 100 ? _categoryColor.withOpacity(0.4) : const Color(0xFFE2E8F0)),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _tealAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: _tealColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$index. $title',
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: _tealAccent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('Bobot $weight', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _tealColor)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(guideline, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              children: options.map((opt) {
                final isSelected = opt.value == currentVal;
                final optColor = opt.value == 100
                    ? const Color(0xFF10B981)
                    : (opt.value == 70 ? const Color(0xFFF59E0B) : const Color(0xFFF43F5E));

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: InkWell(
                    onTap: () => onSelect(opt.value),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                      decoration: BoxDecoration(
                        color: isSelected ? optColor.withOpacity(0.12) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? optColor : const Color(0xFFE2E8F0),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            decoration: BoxDecoration(
                              color: isSelected ? optColor : const Color(0xFFCBD5E1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${opt.value}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              opt.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF475569),
                              ),
                            ),
                          ),
                          Icon(
                            opt.icon,
                            size: 18,
                            color: isSelected ? optColor : const Color(0xFF94A3B8),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConclusionCard() {
    final cntStandar = [_skorLantaiFront, _skorRuangManuver, _skorSafetyBerm, _skorKondisiDinding, _skorDrainaseSump, _skorKebersihanSpillage, _skorPosisiAlat, _skorRambuPenerangan].where((s) => s == 100).length;
    final cntPerhatian = [_skorLantaiFront, _skorRuangManuver, _skorSafetyBerm, _skorKondisiDinding, _skorDrainaseSump, _skorKebersihanSpillage, _skorPosisiAlat, _skorRambuPenerangan].where((s) => s == 70).length;
    final cntKritis = [_skorLantaiFront, _skorRuangManuver, _skorSafetyBerm, _skorKondisiDinding, _skorDrainaseSump, _skorKebersihanSpillage, _skorPosisiAlat, _skorRambuPenerangan].where((s) => s == 40).length;

    String feasibilityTitle;
    String feasibilityDesc;
    IconData feasibilityIcon;

    if (_totalScore >= 85) {
      feasibilityTitle = 'STATUS: FRONT LAYAK OPERASI PENUH (OPTIMAL)';
      feasibilityDesc = 'Seluruh parameter front memenuhi standar keselamatan loading & digging area tambang.';
      feasibilityIcon = Icons.shield_rounded;
    } else if (_totalScore >= 70) {
      feasibilityTitle = 'STATUS: FRONT LAYAK BERSYARAT (WAJIB PERBAIKAN)';
      feasibilityDesc = 'Operasi front dapat berlanjut dengan pengawasan dan perbaikan pada parameter defisit.';
      feasibilityIcon = Icons.warning_rounded;
    } else {
      feasibilityTitle = 'STATUS: KRITIS - STOP OPERASI / BAHAYA TINGGI';
      feasibilityDesc = 'Kondisi front tidak aman! Hentikan aktivitas loading sampai dilakukan perbaikan menyeluruh.';
      feasibilityIcon = Icons.dangerous_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _categoryColor.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(color: _categoryColor.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Kesimpulan
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _categoryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.military_tech_rounded, color: _categoryColor, size: 24),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('KESIMPULAN SKOR FCI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('Analisis kelayakan operasional otomatis', style: TextStyle(color: Color(0xFF64748B), fontSize: 10.5)),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$_totalScore%', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _categoryColor)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _categoryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(_kategoriIndex.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _categoryColor)),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Feasibility Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _categoryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _categoryColor.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(feasibilityIcon, color: _categoryColor, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(feasibilityTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: _categoryColor)),
                      const SizedBox(height: 2),
                      Text(feasibilityDesc, style: TextStyle(fontSize: 11, color: _categoryColor.withOpacity(0.9), height: 1.3)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 3 Breakdown Stats
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text('$cntStandar', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF10B981))),
                      const Text('Standar (100)', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text('$cntPerhatian', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFF59E0B))),
                      const Text('Perhatian (70)', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF43F5E).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text('$cntKritis', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFF43F5E))),
                      const Text('Kritis (40)', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Auto-generated Recommendation Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDFA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCCFBF1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.bolt_rounded, size: 16, color: _tealColor),
                        SizedBox(width: 6),
                        Text('Rekomendasi Otomatis:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: _tealColor)),
                      ],
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        visualDensity: VisualDensity.compact,
                        foregroundColor: _tealColor,
                      ),
                      onPressed: _applyAutoRecommendation,
                      icon: const Icon(Icons.arrow_downward_rounded, size: 14),
                      label: const Text('Terapkan', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                Text(_generateAutoRecommendation(), style: const TextStyle(fontSize: 11, color: Color(0xFF334155), height: 1.3)),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // WhatsApp Share Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _shareToWhatsApp,
              icon: const Icon(Icons.share_rounded, size: 18, color: Color(0xFF25D366)),
              label: const Text('Bagikan Ringkasan ke WhatsApp', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 12)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF25D366)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPicSelector() {
    if (_picCtrl.text.isNotEmpty) {
      final name = _selectedPicEmployee?.nama ?? _picCtrl.text;
      final sub = _selectedPicEmployee != null
          ? 'NIK: ${_selectedPicEmployee!.nik}${_selectedPicEmployee!.departemen.isNotEmpty ? " • ${_selectedPicEmployee!.departemen}" : ""}${_selectedPicEmployee!.jabatan.isNotEmpty ? " • ${_selectedPicEmployee!.jabatan}" : ""}'
          : 'PIC Terpilih';

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDFA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _tealAccent.withOpacity(0.6), width: 1.2),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: _tealColor,
              radius: 18,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'P',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF0D9488)),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Ganti PIC',
              icon: const Icon(Icons.swap_horiz_rounded, color: _tealColor),
              onPressed: _showEmployeePickerModal,
            ),
            IconButton(
              tooltip: 'Hapus PIC',
              icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 18),
              onPressed: () {
                setState(() {
                  _selectedPicEmployee = null;
                  _picCtrl.clear();
                });
              },
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: _showEmployeePickerModal,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _tealAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person_add_alt_1_rounded, color: _tealColor, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pilih PIC dari Data Karyawan',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Tentukan pengawas / personil penanggung jawab perbaikan',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumPhotoCard() {
    if (_fotoFile != null || (_existingFotoUrl != null && _existingFotoUrl!.isNotEmpty)) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              if (_fotoFile != null)
                Image.file(_fotoFile!, width: double.infinity, height: 220, fit: BoxFit.cover)
              else
                Image.network(_existingFotoUrl!, width: double.infinity, height: 220, fit: BoxFit.cover),
              // Top Overlay Bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black54, Colors.transparent],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981)),
                            SizedBox(width: 4),
                            Text('Foto Dokumentasi Front', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      CircleAvatar(
                        backgroundColor: Colors.black54,
                        radius: 16,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                          onPressed: () {
                            setState(() {
                              _fotoFile = null;
                              _existingFotoUrl = null;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Bottom Action Banner
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  color: Colors.black54,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Foto siap dilampirkan ke sistem',
                        style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w500),
                      ),
                      InkWell(
                        onTap: () => _pickImage(ImageSource.camera),
                        child: const Row(
                          children: [
                            Icon(Icons.cached_rounded, color: Color(0xFF5EEAD4), size: 14),
                            SizedBox(width: 4),
                            Text('Ganti Foto', style: TextStyle(color: Color(0xFF5EEAD4), fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _tealAccent.withOpacity(0.5), style: BorderStyle.solid, width: 1.5),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _tealAccent.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add_a_photo_rounded, color: _tealColor, size: 26),
          ),
          const SizedBox(height: 10),
          const Text(
            'Unggah Bukti Foto Dokumentasi Front',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Lampirkan foto kondisi aktual lantai, tanggul berm, atau dinding highwall (JPG/PNG maks 10MB)',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_rounded, size: 18),
                  label: const Text('Ambil Foto Kamera', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _tealColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded, size: 18, color: _tealColor),
                  label: const Text('Buka Galeri', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _tealColor)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _tealAccent, width: 1.2),
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreOption {
  final int value;
  final String label;
  final IconData icon;

  const _ScoreOption(this.value, this.label, this.icon);
}

class _FciEmployeeItem {
  final String nik;
  final String nama;
  final String departemen;
  final String jabatan;
  final String perusahaan;

  const _FciEmployeeItem({
    required this.nik,
    required this.nama,
    this.departemen = '',
    this.jabatan = '',
    this.perusahaan = '',
  });

  String get displayName => '$nama ($nik)';
}

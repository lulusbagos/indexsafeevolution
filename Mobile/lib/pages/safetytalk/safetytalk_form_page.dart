import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../services/api.dart';
import '../../services/database.dart';
import '../../services/offline_sync_service.dart';
import '../../services/preference.dart';
import '../../services/sync.dart';
import '../../utils/helpers.dart';
import '../../widgets/sap_form_widgets.dart';
import '../../widgets/top_bar.dart';

const _stRed = Color(0xFFE11D48);
const _stDark = Color(0xFF0F172A);

class SafetyTalkFormPage extends StatefulWidget {
  const SafetyTalkFormPage({this.existingId, super.key});

  final int? existingId;

  @override
  State<SafetyTalkFormPage> createState() => _SafetyTalkFormPageState();
}

class _SafetyTalkFormPageState extends State<SafetyTalkFormPage> {
  final _scrollCtrl = ScrollController();
  final _db = DatabaseService();
  final _api = ApiService();
  final _profile = PreferenceService.getProfile();

  final _locationDetail = TextEditingController();
  final _title = TextEditingController();
  final _remark = TextEditingController();

  DateTime? _date = DateTime.now();
  String? _time = DateFormat('HH:mm').format(DateTime.now());

  String? _area;
  String? _benchmark;

  List<String> _masterAreas = [];
  List<String> _benchmarksList = [];
  bool _isLoadingAreas = false;
  bool _isLoadingBenchmarks = false;

  String? _selfImage;
  String? _eventImage;
  String? _existingSelfImageUrl;
  String? _existingEventImageUrl;

  bool _isSaving = false;
  bool _isLoadingExisting = false;
  int? _localId;

  @override
  void initState() {
    super.initState();
    _loadAreasFromMaster();
    if (widget.existingId != null) {
      _loadExistingData();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fillGpsFromDevice(silent: true);
      });
    }
  }

  @override
  void dispose() {
    _locationDetail.dispose();
    _title.dispose();
    _remark.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _fillGpsFromDevice({bool silent = false}) {
    return fillGpsCoordinate(
      context,
      _locationDetail,
      () => setState(() {}),
      silent: silent,
    );
  }

  Future<void> _loadAreasFromMaster() async {
    setState(() => _isLoadingAreas = true);
    final areas = <String>{};

    try {
      final sqldb = await _db.database;
      final rows = await sqldb.rawQuery(
        "SELECT DISTINCT area_utama FROM tbl_m_benchmark WHERE area_utama IS NOT NULL AND TRIM(area_utama) != '' ORDER BY area_utama",
      );
      for (var r in rows) {
        final val = r['area_utama']?.toString().trim();
        if (val != null && val.isNotEmpty) areas.add(val);
      }
    } catch (_) {}

    // Fallback from locations table if empty
    if (areas.isEmpty) {
      try {
        final sqldb = await _db.database;
        final rows = await sqldb.rawQuery(
          "SELECT DISTINCT area FROM locations WHERE area IS NOT NULL AND TRIM(area) != '' ORDER BY area",
        );
        for (var r in rows) {
          final val = r['area']?.toString().trim();
          if (val != null && val.isNotEmpty) areas.add(val);
        }
      } catch (_) {}
    }

    // Also attempt remote if still empty
    if (areas.isEmpty) {
      final master = await _api.getSafetyTalkData();
      if (master != null && master['areas'] is List) {
        for (var item in (master['areas'] as List)) {
          final name = item['name']?.toString().trim();
          if (name != null && name.isNotEmpty) areas.add(name);
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _masterAreas = areas.toList()..sort();
      _isLoadingAreas = false;
    });
  }

  Future<void> _loadBenchmarksForArea(String area) async {
    if (area.trim().isEmpty) return;
    setState(() => _isLoadingBenchmarks = true);
    final list = <String>{};

    try {
      final sqldb = await _db.database;
      final rows = await sqldb.rawQuery(
        "SELECT DISTINCT nama_benchmark FROM tbl_m_benchmark WHERE LOWER(TRIM(area_utama)) = ? AND nama_benchmark IS NOT NULL AND TRIM(nama_benchmark) != '' ORDER BY nama_benchmark",
        [area.trim().toLowerCase()],
      );
      for (var r in rows) {
        final val = r['nama_benchmark']?.toString().trim();
        if (val != null && val.isNotEmpty) list.add(val);
      }
    } catch (_) {}

    if (list.isEmpty) {
      final remote = await _api.getSafetyTalkBenchmarks(area);
      for (var item in remote) {
        if (item.trim().isNotEmpty) list.add(item.trim());
      }
    }

    if (!mounted) return;
    setState(() {
      _benchmarksList = list.toList()..sort();
      _isLoadingBenchmarks = false;
    });
  }

  Future<void> _loadExistingData() async {
    setState(() => _isLoadingExisting = true);
    final id = widget.existingId!;

    // 1. Check local database first
    try {
      final sqldb = await _db.database;
      final rows = await sqldb.query(
        'safety_trans',
        where: 'id = ? OR sync_id = ?',
        whereArgs: [id, id],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final r = rows.first;
        _localId = r['id'] as int?;
        _title.text = (r['title'] ?? r['judul'] ?? '').toString();
        _remark.text = (r['remark'] ?? r['keterangan'] ?? '').toString();
        _area = r['area']?.toString();
        _benchmark = (r['lokasi'] ?? r['detil_lokasi'] ?? '').toString();
        _locationDetail.text = (r['location_detail'] ?? '').toString();

        final dateStr = (r['date'] ?? r['tanggal'])?.toString();
        if (dateStr != null && dateStr.isNotEmpty) {
          _date = DateTime.tryParse(dateStr) ?? DateTime.now();
        }
        _time = (r['time'] ?? r['waktu'])?.toString() ?? DateFormat('HH:mm').format(DateTime.now());

        final sImg = (r['self_image'] ?? r['foto_diri'] ?? r['image'])?.toString();
        if (sImg != null && sImg.isNotEmpty) {
          if (File(sImg).existsSync()) {
            _selfImage = sImg;
          } else if (sImg.startsWith('http')) {
            _existingSelfImageUrl = sImg;
          }
        }

        final eImg = (r['event_image'] ?? r['foto_kegiatan'] ?? r['repair_image'])?.toString();
        if (eImg != null && eImg.isNotEmpty) {
          if (File(eImg).existsSync()) {
            _eventImage = eImg;
          } else if (eImg.startsWith('http')) {
            _existingEventImageUrl = eImg;
          }
        }

        if (_area != null && _area!.isNotEmpty) {
          await _loadBenchmarksForArea(_area!);
        }

        if (mounted) setState(() => _isLoadingExisting = false);
        return;
      }
    } catch (_) {}

    // 2. Fallback to API if not in local database
    try {
      final remote = await _api.getSafetyTalk(id);
      if (remote != null) {
        _title.text = (remote['judul'] ?? '').toString();
        _remark.text = (remote['keterangan'] ?? '').toString();
        _area = remote['area']?.toString();
        _benchmark = (remote['detilLokasi'] ?? remote['lokasi'] ?? '').toString();
        _locationDetail.text = (remote['lokasi'] ?? '').toString();

        final dateStr = remote['tanggal']?.toString();
        if (dateStr != null && dateStr.isNotEmpty) {
          _date = DateTime.tryParse(dateStr) ?? DateTime.now();
        }
        final waktuStr = remote['waktu']?.toString();
        if (waktuStr != null && waktuStr.isNotEmpty) {
          _time = waktuStr.length >= 5 ? waktuStr.substring(0, 5) : waktuStr;
        }

        final fd = remote['fotoDiri']?.toString();
        if (fd != null && fd.isNotEmpty) _existingSelfImageUrl = fd;
        final fk = remote['fotoKegiatan']?.toString();
        if (fk != null && fk.isNotEmpty) _existingEventImageUrl = fk;

        if (_area != null && _area!.isNotEmpty) {
          await _loadBenchmarksForArea(_area!);
        }
      }
    } catch (_) {}

    if (mounted) setState(() => _isLoadingExisting = false);
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
            final filtered = _masterAreas
                .where((a) => a.toLowerCase().contains(filter.toLowerCase()))
                .toList();
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
                                color: _stDark,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Pilih atau ketik untuk mencari & menambah area',
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
                        onChanged: (val) => setModalState(() => filter = val),
                        style: const TextStyle(fontSize: 14, color: _stDark),
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
                        onTap: () {
                          final newArea = filter.trim().toUpperCase();
                          Navigator.pop(modalCtx);
                          setState(() {
                            if (!_masterAreas.contains(newArea)) {
                              _masterAreas.add(newArea);
                              _masterAreas.sort();
                            }
                            _area = newArea;
                            _benchmark = null;
                            _benchmarksList = [];
                          });
                          _loadBenchmarksForArea(newArea);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFECDD3)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: _stRed,
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
                                      style: TextStyle(color: _stRed, fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      '"${filter.trim().toUpperCase()}"',
                                      style: const TextStyle(
                                        color: _stDark,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, color: _stRed, size: 14),
                            ],
                          ),
                        ),
                      ),
                    ),

                  Expanded(
                    child: _isLoadingAreas && _masterAreas.isEmpty
                        ? const Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: _stRed),
                            ),
                          )
                        : filtered.isEmpty && !canAddCustom
                            ? const Center(
                                child: Text('Area tidak ditemukan', style: TextStyle(color: Color(0xFF94A3B8))),
                              )
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
                                      color: isSelected ? _stRed : const Color(0xFF94A3B8),
                                      size: 20,
                                    ),
                                    title: Text(
                                      item,
                                      style: TextStyle(
                                        color: isSelected ? _stRed : const Color(0xFF1E293B),
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    trailing: isSelected
                                        ? const Icon(Icons.check_circle_rounded, color: _stRed, size: 20)
                                        : null,
                                    onTap: () {
                                      Navigator.pop(modalCtx);
                                      setState(() {
                                        _area = item;
                                        _benchmark = null;
                                        _benchmarksList = [];
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
    if (_area == null || _area!.isEmpty) {
      _showWarning('Pilih Area Utama terlebih dahulu.');
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
            final filtered = _benchmarksList
                .where((b) => b.toLowerCase().contains(filter.toLowerCase()))
                .toList();
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pilih Detail Lokasi / Benchmark',
                              style: TextStyle(
                                color: _stDark,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Area: $_area',
                              style: const TextStyle(color: _stRed, fontSize: 12, fontWeight: FontWeight.w600),
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
                        style: const TextStyle(fontSize: 14, color: _stDark),
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
                        onTap: () {
                          final newBm = filter.trim().toUpperCase();
                          Navigator.pop(modalCtx);
                          setState(() {
                            if (!_benchmarksList.contains(newBm)) {
                              _benchmarksList.add(newBm);
                              _benchmarksList.sort();
                            }
                            _benchmark = newBm;
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFECDD3)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: _stRed,
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
                                      style: TextStyle(color: _stRed, fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      '"${filter.trim().toUpperCase()}"',
                                      style: const TextStyle(
                                        color: _stDark,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, color: _stRed, size: 14),
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
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: _stRed),
                            ),
                          )
                        : filtered.isEmpty && !canAddCustom
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 32),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.explore_off_rounded, size: 40, color: Color(0xFF94A3B8)),
                                      SizedBox(height: 10),
                                      Text(
                                        'Belum ada benchmark pada area ini',
                                        style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Ketik di kotak pencarian di atas untuk menambahkan benchmark baru.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
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
                                      Icons.near_me_rounded,
                                      color: isSelected ? _stRed : const Color(0xFF94A3B8),
                                      size: 20,
                                    ),
                                    title: Text(
                                      item,
                                      style: TextStyle(
                                        color: isSelected ? _stRed : const Color(0xFF1E293B),
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    trailing: isSelected
                                        ? const Icon(Icons.check_circle_rounded, color: _stRed, size: 20)
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
        );
      },
    );
  }

  void _showWarning(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _pickPhoto({required bool isSelf}) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
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
                leading: const Icon(Icons.camera_alt_rounded, color: _stRed),
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
      setState(() {
        if (isSelf) {
          _selfImage = file.path;
        } else {
          _eventImage = file.path;
        }
      });
    }
  }

  void _previewImage({
    required String? localPath,
    required String? remoteUrl,
    required String title,
  }) {
    if ((localPath == null || localPath.isEmpty) && (remoteUrl == null || remoteUrl.isEmpty)) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: localPath != null && localPath.isNotEmpty
                  ? Image.file(File(localPath), fit: BoxFit.contain)
                  : Image.network(
                      remoteUrl!.startsWith('http') ? remoteUrl : '${_api.dio.options.baseUrl}$remoteUrl',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.black87,
                        padding: const EdgeInsets.all(32),
                        child: const Center(
                          child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 48),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernPhotoField({
    required String stepIndex,
    required String label,
    required String badgeText,
    required String hintText,
    required IconData icon,
    required Color accentColor,
    required String? localPath,
    required String? remoteUrl,
    required VoidCallback onPick,
    required VoidCallback onRemove,
  }) {
    final hasLocal = localPath != null && localPath.isNotEmpty;
    final hasRemote = remoteUrl != null && remoteUrl.isNotEmpty;
    final hasImage = hasLocal || hasRemote;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      stepIndex,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: _stDark,
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
                color: hasImage ? const Color(0xFFECFDF5) : accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: hasImage ? const Color(0xFFA7F3D0) : accentColor.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasImage ? Icons.check_circle_rounded : icon,
                    size: 12,
                    color: hasImage ? const Color(0xFF059669) : accentColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    hasImage ? 'Terlampir' : badgeText,
                    style: TextStyle(
                      color: hasImage ? const Color(0xFF059669) : accentColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Photo Box
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
                // Image
                InkWell(
                  onTap: () => _previewImage(
                    localPath: localPath,
                    remoteUrl: remoteUrl,
                    title: label,
                  ),
                  child: hasLocal
                      ? Image.file(File(localPath), fit: BoxFit.cover)
                      : Image.network(
                          remoteUrl!.startsWith('http') ? remoteUrl : '${_api.dio.options.baseUrl}$remoteUrl',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 36),
                          ),
                        ),
                ),

                // Top Bar with Zoom & Delete
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
                            localPath: localPath,
                            remoteUrl: remoteUrl,
                            title: label,
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
                                Text('Lihat Penuh', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: onRemove,
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

                // Bottom Bar with Change Button
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: InkWell(
                    onTap: onPick,
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
            onTap: onPick,
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
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: accentColor.withValues(alpha: 0.2)),
                    ),
                    child: Icon(icon, color: accentColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hintText,
                          style: const TextStyle(
                            color: _stDark,
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Kamera langsung atau Galeri HP',
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
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: accentColor.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_a_photo_rounded, color: accentColor, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Ambil Foto',
                          style: TextStyle(
                            color: accentColor,
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
    // 1. Validasi Formulir
    if (_area == null || _area!.trim().isEmpty) {
      _showWarning('Pilih Area Utama terlebih dahulu.');
      return;
    }
    if (_benchmark == null || _benchmark!.trim().isEmpty) {
      _showWarning('Pilih Lokasi / Benchmark terlebih dahulu.');
      return;
    }
    if (_title.text.trim().isEmpty) {
      _showWarning('Judul atau topik pembahasan Safety Talk wajib diisi.');
      return;
    }
    if (_remark.text.trim().isEmpty) {
      _showWarning('Keterangan / notulen Safety Talk wajib diisi.');
      return;
    }
    final hasSelfImage = (_selfImage != null && _selfImage!.isNotEmpty) ||
        (_existingSelfImageUrl != null && _existingSelfImageUrl!.isNotEmpty);
    if (!hasSelfImage) {
      _showWarning('Foto Diri / Pemateri wajib diambil.');
      return;
    }
    final hasEventImage = (_eventImage != null && _eventImage!.isNotEmpty) ||
        (_existingEventImageUrl != null && _existingEventImageUrl!.isNotEmpty);
    if (!hasEventImage) {
      _showWarning('Foto Kegiatan Briefing wajib diambil.');
      return;
    }

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_date ?? DateTime.now());
      final timeStr = _time ?? DateFormat('HH:mm').format(DateTime.now());
      final titleStr = _title.text.trim();
      final remarkStr = _remark.text.trim();
      final locDetailStr = _locationDetail.text.trim();

      int targetLocalId = _localId ?? 0;

      if (_localId != null && _localId! > 0) {
        // Mode UPDATE record lokal
        final updateData = <String, dynamic>{
          'title': titleStr,
          'judul': titleStr,
          'remark': remarkStr,
          'keterangan': remarkStr,
          'area': _area,
          'lokasi': _benchmark,
          'detil_lokasi': locDetailStr,
          'location_detail': locDetailStr,
          'date': dateStr,
          'time': timeStr,
          if (_selfImage != null) 'self_image': _selfImage,
          if (_selfImage != null) 'foto_diri': _selfImage,
          if (_selfImage != null) 'image': _selfImage,
          if (_eventImage != null) 'event_image': _eventImage,
          if (_eventImage != null) 'foto_kegiatan': _eventImage,
          if (_eventImage != null) 'repair_image': _eventImage,
          'updated_at': DateTime.now().toIso8601String(),
          'sync_id': null, // trigger resync
        };
        await _db.update('safety_trans', updateData, _localId!);
        targetLocalId = _localId!;
      } else {
        // Mode INSERT baru
        final insertData = <String, dynamic>{
          'title': titleStr,
          'judul': titleStr,
          'remark': remarkStr,
          'keterangan': remarkStr,
          'area': _area,
          'lokasi': _benchmark,
          'detil_lokasi': locDetailStr,
          'location_detail': locDetailStr,
          'date': dateStr,
          'time': timeStr,
          'self_image': _selfImage,
          'foto_diri': _selfImage,
          'event_image': _eventImage,
          'foto_kegiatan': _eventImage,
          'image': _selfImage,
          'repair_image': _eventImage,
          'status': 0,
          'company_id': _profile?.companyId,
          'employee_id': _profile?.id,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };
        targetLocalId = await _db.insert('safety_trans', insertData);
      }

      // Sync ke backend / server
      bool synced = false;
      try {
        synced = await syncTran(_db, _api, 'safety', targetLocalId);
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
                      ? 'Safety Talk berhasil disimpan & disinkronkan ke server.'
                      : 'Safety Talk tersimpan di perangkat (Offline). Akan dikirim saat terhubung internet.',
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
          content: Text('Gagal menyimpan Safety Talk: $e'),
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
      appBar: TopBar(title: isEdit ? 'Edit Safety Talk' : 'Buat Safety Talk'),
      body: _isLoadingExisting
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: _stRed),
                  SizedBox(height: 14),
                  Text('Memuat data Safety Talk...', style: TextStyle(color: Color(0xFF64748B))),
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
                    subtitle: 'Tanggal, jam dan titik lokasi safety talk dilakukan',
                    icon: Icons.place_rounded,
                    accentColor: _stRed,
                    children: [
                      // Tanggal & Jam
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
                                    const Icon(Icons.calendar_today_rounded, size: 18, color: _stRed),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Tanggal', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                          Text(
                                            DateFormat('dd MMM yyyy').format(_date ?? DateTime.now()),
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _stDark),
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
                                    const Icon(Icons.access_time_rounded, size: 18, color: _stRed),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Jam', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                          Text(
                                            _time ?? DateFormat('HH:mm').format(DateTime.now()),
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _stDark),
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
                          color: _stDark,
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
                        onTap: _showAreaPickerModal,
                      ),
                      const SizedBox(height: 14),

                      // Detail Lokasi / Benchmark
                      const Text(
                        'LOKASI / BENCHMARK *',
                        style: TextStyle(
                          color: _stDark,
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
                        onTap: _showBenchmarkPickerModal,
                      ),
                      const SizedBox(height: 14),

                      // Detail Lokasi / GPS
                      const Text(
                        'DETAIL LOKASI / GPS KOORDINAT',
                        style: TextStyle(
                          color: _stDark,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _locationDetail,
                        decoration: InputDecoration(
                          hintText: 'Misal: Ruang Briefing Workshop / GPS otomatis',
                          hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.gps_fixed_rounded, color: _stRed, size: 20),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.my_location_rounded, color: _stRed, size: 20),
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
                            borderSide: const BorderSide(color: _stRed, width: 1.6),
                          ),
                        ),
                        style: const TextStyle(fontSize: 13, color: _stDark),
                      ),
                    ],
                  ),

                  // SECTION 2: Materi & Keterangan
                  SapSectionCard(
                    stepNumber: '2',
                    title: 'MATERI & KETERANGAN',
                    subtitle: 'Topik pembahasan keselamatan dan ringkasan arahan',
                    icon: Icons.campaign_rounded,
                    accentColor: _stRed,
                    children: [
                      const Text(
                        'JUDUL / TOPIK SAFETY TALK *',
                        style: TextStyle(
                          color: _stDark,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _title,
                        decoration: InputDecoration(
                          hintText: 'Contoh: Prosedur Penggunaan APD & Waspada Blind Spot',
                          hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.title_rounded, color: _stRed, size: 20),
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
                            borderSide: const BorderSide(color: _stRed, width: 1.6),
                          ),
                        ),
                        style: const TextStyle(fontSize: 13, color: _stDark, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 14),

                      const Text(
                        'KETERANGAN / NOTULEN / DAFTAR HADIR *',
                        style: TextStyle(
                          color: _stDark,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _remark,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Tuliskan ringkasan materi briefing, jumlah peserta, notulen penting...',
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
                            borderSide: const BorderSide(color: _stRed, width: 1.6),
                          ),
                        ),
                        style: const TextStyle(fontSize: 13, color: _stDark),
                      ),
                    ],
                  ),

                  // SECTION 3: Dokumentasi Foto Kegiatan
                  SapSectionCard(
                    stepNumber: '3',
                    title: 'DOKUMENTASI FOTO KEGIATAN',
                    subtitle: 'Wajib 2 foto: Foto pemateri & foto seluruh peserta briefing',
                    icon: Icons.camera_alt_rounded,
                    accentColor: _stRed,
                    children: [
                      _buildModernPhotoField(
                        stepIndex: 'A',
                        label: 'FOTO DIRI / PEMATERI *',
                        badgeText: 'Selfie Pemateri',
                        hintText: 'Ambil Foto Pemateri',
                        icon: Icons.person_pin_circle_rounded,
                        accentColor: _stRed,
                        localPath: _selfImage,
                        remoteUrl: _existingSelfImageUrl,
                        onPick: () => _pickPhoto(isSelf: true),
                        onRemove: () => setState(() {
                          _selfImage = null;
                          _existingSelfImageUrl = null;
                        }),
                      ),
                      const SizedBox(height: 14),
                      _buildModernPhotoField(
                        stepIndex: 'B',
                        label: 'FOTO KEGIATAN / PESERTA BRIEFING *',
                        badgeText: 'Peserta & Tim',
                        hintText: 'Ambil Foto Seluruh Peserta',
                        icon: Icons.groups_rounded,
                        accentColor: const Color(0xFF0284C7),
                        localPath: _eventImage,
                        remoteUrl: _existingEventImageUrl,
                        onPick: () => _pickPhoto(isSelf: false),
                        onRemove: () => setState(() {
                          _eventImage = null;
                          _existingEventImageUrl = null;
                        }),
                      ),
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
                                'Pastikan foto pemateri dan seluruh peserta briefing terlihat jelas serta berada di area kerja.',
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
              backgroundColor: _stRed,
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
                  : (isEdit ? 'Perbarui Safety Talk' : 'Simpan Safety Talk'),
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
  });

  final IconData icon;
  final String? value;
  final String hint;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasVal = value != null && value!.isNotEmpty;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon, color: enabled ? _stRed : const Color(0xFF94A3B8), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasVal ? value! : hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: hasVal ? FontWeight.w600 : FontWeight.normal,
                  color: hasVal ? _stDark : const Color(0xFF94A3B8),
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF94A3B8), size: 20),
          ],
        ),
      ),
    );
  }
}

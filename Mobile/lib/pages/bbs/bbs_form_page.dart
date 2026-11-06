import '../../utils/app_date_time_picker.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/preference.dart';
import '../../services/api.dart';
import '../../services/database.dart';
import '../../services/offline_sync_service.dart';
import '../../widgets/sap_form_widgets.dart';
import '../../widgets/snackbar_msg.dart';
import '../../widgets/top_bar.dart';
import '../../widgets/professional_success_sheet.dart';
import 'bbs_model.dart';
import 'bbs_page.dart';

const _kPrimary = Color(0xFF0284C7);
const _kSuccess = Color(0xFF10B981);
const _kWarning = Color(0xFFF59E0B);
const _kDanger = Color(0xFFEF4444);
const _kBgColor = Color(0xFFF8FAFC);

class BbsFormPage extends StatefulWidget {
  const BbsFormPage({super.key});

  @override
  State<BbsFormPage> createState() => _BbsFormPageState();
}

class _BbsFormPageState extends State<BbsFormPage> {
  final _scrollCtrl = ScrollController();
  final _profile = PreferenceService.getProfile();
  final _api = ApiService();
  final _db = DatabaseService();

  // Controllers
  final _coordinate = TextEditingController();
  final _department = TextEditingController();
  final _observedNik = TextEditingController();
  final _observedPerson = TextEditingController();
  final _observedPosition = TextEditingController();
  final _workerSearchCtrl = TextEditingController();
  final _otherBehavior = TextEditingController();
  final _potentialConsequence = TextEditingController();
  final _coachingNotes = TextEditingController();
  final _commitment = TextEditingController();
  final _otherAction = TextEditingController();

  // Form states
  int? _companyId;
  String? _companyName;
  String _observationType = 'Observasi Rutin';
  DateTime _observedAt = DateTime.now();
  String _area = '';
  String _benchmark = '';
  String? _workerPhoto;
  String? _workerPerusahaan;

  // Master data
  List<Map<String, dynamic>> _mbsCompanies = [];
  List<String> _masterAreas = [];
  List<String> _benchmarksList = [];
  List<String> _departmentOptions = [];
  List<Map<String, dynamic>> _mbsCategories = [];
  List<Map<String, dynamic>> _mbsTopics = [];
  List<Map<String, dynamic>> _mbsBehaviorItems = [];
  String? _category;
  int? _categoryId;
  int? _topicId;
  String? _topicName;

  // Worker search
  List<Map<String, dynamic>> _workerResults = [];
  bool _workerSearching = false;
  Timer? _workerDebounce;

  // Selections
  final Set<String> _behaviors = {};
  final Map<String, String> _behaviorStatuses = {};
  String _classification = 'Perilaku Aman';
  String _roadCondition = 'Normal / Kering';
  String _trafficCondition = 'Sedang';
  final Set<String> _triggerFactors = {};
  String _riskLevel = 'Rendah';
  final Set<String> _immediateActions = {};
  String _workerResponse = 'Positif';
  DateTime? _dueDate;
  final List<String> _evidencePaths = [];

  // Loading flags
  bool _isLoadingAreas = false;
  bool _isLoadingBenchmarks = false;
  bool _masterLoading = false;
  bool _departmentsLoading = false;
  bool _saving = false;

  VoidCallback? _onAreasLoadedModal;
  VoidCallback? _onBenchmarksLoadedModal;

  @override
  void initState() {
    super.initState();
    _companyId = _profile?.companyId ?? 1;
    _companyName = _profile?.company ?? 'PT INDEXIM COALINDO';

    // 1. Inisialisasi cepat dari cache lokal (0ms delay)
    _loadLocalCachedData();

    // 2. Refresh background jika ada koneksi
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_coordinate.text.isEmpty) {
        fillGpsCoordinate(
          context,
          _coordinate,
          () => setState(() {}),
          silent: true,
        );
      }
      _loadAreasFromMaster();
      _loadMbsCompanies();
      _loadDepartmentsForCompany(_companyId!);
      _loadMbsCategories();
    });
  }

  @override
  void dispose() {
    _workerDebounce?.cancel();
    _scrollCtrl.dispose();
    _coordinate.dispose();
    _department.dispose();
    _observedNik.dispose();
    _observedPerson.dispose();
    _observedPosition.dispose();
    _workerSearchCtrl.dispose();
    _otherBehavior.dispose();
    _potentialConsequence.dispose();
    _coachingNotes.dispose();
    _commitment.dispose();
    _otherAction.dispose();
    super.dispose();
  }

  // ==================== STANDARD BBS CATALOG & DEFAULTS ====================

  static const List<Map<String, dynamic>> _defaultCategories = [
    {'id': 1, 'name': 'Interaksi Alat & Manusia'},
    {'id': 2, 'name': 'Posisi & Postur Kerja (Ergonomi)'},
    {'id': 3, 'name': 'Kepatuhan Prosedur & APD'},
    {'id': 4, 'name': 'Housekeeping & Lingkungan Kerja'},
    {'id': 5, 'name': 'Pengoperasian Peralatan & Perkakas'},
  ];

  static final Map<String, List<Map<String, dynamic>>> _defaultBehaviorsByCategory = {
    'Interaksi Alat & Manusia': [
      {'id': 1, 'behaviorText': 'Operator menjaga jarak aman dengan pekerja sekitar saat bermanuver'},
      {'id': 2, 'behaviorText': 'Operator membunyikan klakson sebelum bergerak/bermanuver'},
      {'id': 3, 'behaviorText': 'Pekerja tidak berada di area titik buta (blindspot) alat berat'},
      {'id': 4, 'behaviorText': 'Pekerja menjaga kontak mata positif dengan operator sebelum mendekat'},
      {'id': 5, 'behaviorText': 'Pejalan kaki menggunakan jalur pejalan kaki resmi (walkway / safety zone)'},
      {'id': 6, 'behaviorText': 'Alat berat diparkir di tempat aman dengan rem parkir aktif & attachment turun'},
    ],
    'Posisi & Postur Kerja (Ergonomi)': [
      {'id': 7, 'behaviorText': 'Mengangkat beban dengan punggung tegak dan bertumpu pada lutut'},
      {'id': 8, 'behaviorText': 'Menghindari memutar pinggang secara tiba-tiba saat membawa beban'},
      {'id': 9, 'behaviorText': 'Menjaga posisi tubuh seimbang dan stabil selama bekerja'},
      {'id': 10, 'behaviorText': 'Menggunakan alat bantu angkat untuk beban di atas 20 kg'},
      {'id': 11, 'behaviorText': 'Mengatur ketinggian area kerja agar tidak membungkuk berlebihan'},
    ],
    'Kepatuhan Prosedur & APD': [
      {'id': 12, 'behaviorText': 'Memakai APD lengkap sesuai standar (Helm, Rompi Reflektor, Safety Shoes, Kacamata)'},
      {'id': 13, 'behaviorText': 'Menerapkan 3 titik tumpu (three-point contact) saat naik/turun unit/tangga'},
      {'id': 14, 'behaviorText': 'Mematuhi rambu-rambu K3 dan batas kecepatan operasional'},
      {'id': 15, 'behaviorText': 'Memastikan izin kerja aman (JSA / permit) telah disetujui sebelum bekerja'},
      {'id': 16, 'behaviorText': 'Memasang barikade / safety cone di sekitar area berbahaya'},
    ],
    'Housekeeping & Lingkungan Kerja': [
      {'id': 17, 'behaviorText': 'Area kerja bersih, rapi, dan bebas dari ceceran oli/pelumas/air'},
      {'id': 18, 'behaviorText': 'Peralatan kerja disimpan teratur di tool rack setelah digunakan'},
      {'id': 19, 'behaviorText': 'Penanganan dan pemilahan sampah sesuai tempatnya (Organik, Anorganik, B3)'},
      {'id': 20, 'behaviorText': 'Akses jalan darurat, eyewash, dan tabung APAR bebas dari halangan'},
    ],
    'Pengoperasian Peralatan & Perkakas': [
      {'id': 21, 'behaviorText': 'Melakukan pemeriksaan pra-operasional (P2H / Pre-use check) sebelum digunakan'},
      {'id': 22, 'behaviorText': 'Memastikan seluruh pelindung mesin (guarding) terpasang dengan baik'},
      {'id': 23, 'behaviorText': 'Menerapkan Lockout-Tagout (LOTO) sebelum inspeksi/perbaikan mesin'},
      {'id': 24, 'behaviorText': 'Menggunakan perkakas yang layak (tidak retak, rusak, atau modifikasi liar)'},
    ],
  };

  // ==================== FAST LOCAL CACHE LOADER ====================

  Future<void> _loadLocalCachedData() async {
    try {
      final sqldb = await _db.database;

      // 1. Load Areas lokal
      final localAreas = await sqldb.rawQuery(
        "SELECT DISTINCT area_utama FROM tbl_m_benchmark WHERE area_utama IS NOT NULL AND area_utama != '' AND area_utama NOT LIKE '%CAMP EKSPLORASI%' ORDER BY area_utama",
      );
      if (localAreas.isNotEmpty && mounted) {
        setState(() {
          _masterAreas = localAreas
              .map((e) => e['area_utama'].toString().trim())
              .where((s) => s.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
        });
      }

      // 2. Load Companies lokal
      final compRows = await sqldb.rawQuery(
        "SELECT id, name FROM enum_masters WHERE deleted_at IS NULL AND type = 'company' ORDER BY name",
      );
      if (compRows.isNotEmpty && mounted) {
        setState(() {
          _mbsCompanies =
              compRows.map((r) => {'id': r['id'], 'name': r['name']}).toList();
        });
      }

      // 3. Load Cached Categories dari SharedPreferences
      final sp = await SharedPreferences.getInstance();
      final cacheKey =
          'bbs_cached_categories_${_observationType == 'Special Case' ? 'special' : 'rutin'}';
      final cachedJson = sp.getString(cacheKey);
      List<Map<String, dynamic>> cats = [];
      if (cachedJson != null && cachedJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(cachedJson);
          if (decoded is List && decoded.isNotEmpty) {
            cats = decoded.cast<Map<String, dynamic>>();
          }
        } catch (_) {}
      }
      if (cats.isEmpty) {
        cats = _defaultCategories;
      }

      if (mounted) {
        final firstCat = cats.first;
        final cId = firstCat['id'] as int? ?? 1;
        final cName = firstCat['name']?.toString() ?? 'Interaksi Alat & Manusia';
        setState(() {
          _mbsCategories = cats;
          _categoryId = cId;
          _category = cName;
        });
        _loadBehaviorsForCategory(cId, cName);
      }
    } catch (e) {
      debugPrint('[BbsForm] Fast cache load: $e');
    }
  }

  // ==================== MASTER AREAS & BENCHMARKS (LIKE HAZARD) ====================

  Future<void> _loadAreasFromMaster({VoidCallback? onDone}) async {
    if (mounted) setState(() => _isLoadingAreas = true);
    final companyId = _companyId ?? _profile?.companyId ?? 1;

    try {
      final sqldb = await _db.database;

      // Inisialisasi tabel SQLite tbl_m_benchmark lokal
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

      // Baca dari SQLite lokal
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

      // Refresh dari server API jika online
      final serverAreas = await _api.getMasterAreas(perusahaanId: companyId);
      if (serverAreas.isNotEmpty && mounted) {
        setState(() {
          _masterAreas = serverAreas
              .where((s) => !s.toUpperCase().contains('CAMP EKSPLORASI'))
              .toList();
        });
        onDone?.call();
        _onAreasLoadedModal?.call();

        // Simpan ke SQLite untuk offline
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
      debugPrint('[BbsForm] Load areas: $e');
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
    final companyId = _companyId ?? _profile?.companyId ?? 1;

    try {
      final sqldb = await _db.database;

      // 1. Baca cache SQLite lokal
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

      // 2. Ambil dari server API
      final serverBenchmarks =
          await _api.getBenchmarks(cleanArea, perusahaanId: companyId);
      if (serverBenchmarks.isNotEmpty && mounted) {
        setState(() {
          _benchmarksList = serverBenchmarks;
        });
        onDone?.call();
        _onBenchmarksLoadedModal?.call();

        // Simpan ke SQLite
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
      debugPrint('[BbsForm] Load benchmarks: $e');
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
                              'Pilih area standar yang terdaftar di sistem',
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
                                        strokeWidth: 2.5, color: _kPrimary)),
                                SizedBox(height: 14),
                                Text('Memuat daftar area...',
                                    style: TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 13)),
                              ],
                            ),
                          )
                        : filtered.isEmpty
                            ? const Center(
                                child: Text('Area standar tidak ditemukan',
                                    style: TextStyle(color: Color(0xFF94A3B8))))
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
                                          ? _kPrimary
                                          : const Color(0xFF94A3B8),
                                      size: 20,
                                    ),
                                    title: Text(
                                      item,
                                      style: TextStyle(
                                        color: isSelected
                                            ? _kPrimary
                                            : const Color(0xFF1E293B),
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    trailing: isSelected
                                        ? const Icon(Icons.check_circle_rounded,
                                            color: _kPrimary, size: 20)
                                        : null,
                                    onTap: () {
                                      Navigator.pop(modalCtx);
                                      setState(() {
                                        _area = item;
                                        _benchmark = '';
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
    if (_area.isEmpty) {
      SnackBarMsg.warning(context, 'Pilih Area Utama terlebih dahulu.');
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
                                    color: _kPrimary,
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
                                  color: _kPrimary, size: 14),
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
                                        strokeWidth: 2.5, color: _kPrimary)),
                                SizedBox(height: 14),
                                Text('Memuat data acuan...',
                                    style: TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 13)),
                              ],
                            ),
                          )
                        : filtered.isEmpty && !canAddCustom
                            ? const Center(
                                child: Text('Belum ada benchmark terdaftar',
                                    style: TextStyle(color: Color(0xFF94A3B8))))
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 8),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const Divider(
                                    height: 1, color: Color(0xFFF1F5F9)),
                                itemBuilder: (context, index) {
                                  final item = filtered[index];
                                  final isSelected = item == _benchmark;
                                  return ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    leading: Icon(
                                      Icons.location_on_rounded,
                                      color: isSelected
                                          ? _kPrimary
                                          : const Color(0xFF94A3B8),
                                      size: 20,
                                    ),
                                    title: Text(
                                      item,
                                      style: TextStyle(
                                        color: isSelected
                                            ? _kPrimary
                                            : const Color(0xFF1E293B),
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    trailing: isSelected
                                        ? const Icon(Icons.check_circle_rounded,
                                            color: _kPrimary, size: 20)
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

  Future<void> _addNewBenchmark(String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;
    if (_area.isEmpty) {
      SnackBarMsg.warning(context, 'Pilih Area Utama terlebih dahulu.');
      return;
    }

    final userNik = _profile?.noNik ?? 'USER';
    final userName = _profile?.namaLengkap ?? 'User Mobile';
    final companyId = _companyId ?? _profile?.companyId ?? 1;

    setState(() {
      if (!_benchmarksList.contains(cleanName)) {
        _benchmarksList.add(cleanName);
        _benchmarksList.sort();
      }
      _benchmark = cleanName;
    });

    try {
      final sqldb = await _db.database;
      await sqldb.rawInsert(
        '''INSERT INTO tbl_m_benchmark (perusahaan_id, area_utama, nama_benchmark, created_by_nik, created_by_name, created_at)
           VALUES (?, ?, ?, ?, ?, ?)''',
        [
          companyId,
          _area,
          cleanName,
          userNik,
          userName,
          DateTime.now().toIso8601String()
        ],
      );
    } catch (_) {}

    try {
      final res = await _api.createBenchmark(
        areaUtama: _area,
        namaBenchmark: cleanName,
        perusahaanId: companyId,
        createdByNik: userNik,
        createdByName: userName,
      );
      if (mounted) {
        if (res != null) {
          SnackBarMsg.success(
              context, 'Benchmark "$cleanName" berhasil disimpan!');
        } else {
          SnackBarMsg.info(
              context, 'Benchmark "$cleanName" tersimpan di HP (Mode Offline)');
        }
      }
    } catch (_) {
      if (mounted) {
        SnackBarMsg.info(context, 'Benchmark "$cleanName" tersimpan lokal');
      }
    }
  }

  // ==================== COMPANY & DEPARTMENT SYNC ====================

  Future<void> _loadMbsCompanies() async {
    var companies = await _api.getBbsCompanies();
    if (companies.isEmpty) {
      try {
        final rows = await DatabaseService().rawQuery(
          "SELECT id, name FROM enum_masters WHERE deleted_at IS NULL AND type = 'company' ORDER BY name",
        );
        if (rows.isNotEmpty) {
          companies =
              rows.map((r) => {'id': r['id'], 'name': r['name']}).toList();
        } else {
          companies = [
            {'id': 1, 'name': 'PT INDEXIM COALINDO'}
          ];
        }
      } catch (_) {
        companies = [
          {'id': 1, 'name': 'PT INDEXIM COALINDO'}
        ];
      }
    }
    if (mounted) {
      setState(() {
        _mbsCompanies = companies;
        if (_companyId != null) {
          final comp = companies
              .where(
                (c) =>
                    int.tryParse((c['Id'] ?? c['id']).toString()) == _companyId,
              )
              .firstOrNull;
          if (comp != null) {
            _companyName =
                (comp['Nama'] ?? comp['nama'] ?? comp['name']).toString();
          }
        }
      });
    }
  }

  Future<void> _loadDepartmentsForCompany(int companyId) async {
    setState(() => _departmentsLoading = true);
    final Set<String> depts = {};

    // 1. Baca langsung dari SQLite employees lokal (sangat cepat & 100% offline)
    try {
      final sqldb = await _db.database;
      final localRows = await sqldb.rawQuery(
        '''SELECT DISTINCT departemen FROM employees 
           WHERE (company_id = ? OR (? = 1 AND (company_id IS NULL OR company_id = 1)))
             AND departemen IS NOT NULL AND departemen != ''
           ORDER BY departemen''',
        [companyId, companyId],
      );
      for (final r in localRows) {
        final d = r['departemen']?.toString().trim() ?? '';
        if (d.isNotEmpty) depts.add(d);
      }
      if (depts.isNotEmpty && mounted) {
        setState(() {
          _departmentOptions = depts.toList()..sort();
        });
      }
    } catch (_) {}

    // 2. Query dari backend API / Web MBS
    try {
      final apiDepts = await _api.getDepartmentsByCompany(companyId);
      if (apiDepts.isNotEmpty) {
        depts.addAll(apiDepts);
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _departmentOptions = depts.toList()..sort();
        _departmentsLoading = false;
      });
    }
  }

  void _showDepartmentPickerModal() {
    if (_companyId == null) {
      SnackBarMsg.warning(
          context, 'Pilih Perusahaan / Kontraktor terlebih dahulu.');
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
            final filtered = _departmentOptions
                .where((d) => d.toLowerCase().contains(filter.toLowerCase()))
                .toList();
            final hasExactMatch = _departmentOptions
                .any((d) => d.toLowerCase() == filter.trim().toLowerCase());
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
                                'Pilih Unit / Departemen',
                                style: TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Perusahaan: ${_companyName ?? "Semua"}',
                                style: const TextStyle(
                                    color: _kPrimary,
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
                          hintText: 'Ketik untuk mencari departemen...',
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
                        onTap: () {
                          Navigator.pop(modalCtx);
                          setState(() => _department.text = filter.trim());
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
                                  color: _kPrimary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.check,
                                    color: Colors.white, size: 16),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Gunakan Nama Departemen Baru:',
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
                                  color: _kPrimary, size: 14),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: _departmentsLoading && _departmentOptions.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5, color: _kPrimary)),
                                SizedBox(height: 14),
                                Text('Memuat departemen perusahaan...',
                                    style: TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 13)),
                              ],
                            ),
                          )
                        : filtered.isEmpty && !canAddCustom
                            ? const Center(
                                child: Text('Departemen tidak ditemukan',
                                    style: TextStyle(color: Color(0xFF94A3B8))))
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 8),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const Divider(
                                    height: 1, color: Color(0xFFF1F5F9)),
                                itemBuilder: (context, index) {
                                  final item = filtered[index];
                                  final isSelected = item == _department.text;
                                  return ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    leading: Icon(
                                      Icons.apartment_rounded,
                                      color: isSelected
                                          ? _kPrimary
                                          : const Color(0xFF94A3B8),
                                      size: 20,
                                    ),
                                    title: Text(
                                      item,
                                      style: TextStyle(
                                        color: isSelected
                                            ? _kPrimary
                                            : const Color(0xFF1E293B),
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    trailing: isSelected
                                        ? const Icon(Icons.check_circle_rounded,
                                            color: _kPrimary, size: 20)
                                        : null,
                                    onTap: () {
                                      Navigator.pop(modalCtx);
                                      setState(() => _department.text = item);
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

  // ==================== BBS CATEGORIES & TOPICS ====================

  Future<void> _loadBehaviorsForCategory(int catId, String catName) async {
    // 1. Initial fallback immediately from default catalog so UI never shows empty
    List<Map<String, dynamic>> fallback = [];
    for (final entry in _defaultBehaviorsByCategory.entries) {
      if (catName.toLowerCase().contains(entry.key.toLowerCase()) ||
          entry.key.toLowerCase().contains(catName.toLowerCase())) {
        fallback = entry.value;
        break;
      }
    }
    if (fallback.isEmpty) {
      fallback = _defaultBehaviorsByCategory.values.first;
    }

    if (mounted) {
      setState(() {
        _mbsBehaviorItems = fallback;
      });
    }

    // 2. Fetch live from server API if online
    try {
      final serverBehaviors = await _api.getBbsBehaviors(catId);
      if (serverBehaviors.isNotEmpty && mounted) {
        setState(() {
          _mbsBehaviorItems = serverBehaviors;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadMbsCategories() async {
    setState(() => _masterLoading = true);
    final type = _observationType == 'Special Case' ? 'SpecialCase' : 'Rutin';

    try {
      final categories = await _api.getBbsCategories(type);
      if (!mounted) return;

      final activeCats =
          categories.isNotEmpty ? categories : _defaultCategories;
      final sp = await SharedPreferences.getInstance();
      final cacheKey =
          'bbs_cached_categories_${_observationType == 'Special Case' ? 'special' : 'rutin'}';
      await sp.setString(cacheKey, jsonEncode(activeCats));

      Map<String, dynamic>? defaultCat;
      if (_categoryId != null) {
        defaultCat =
            activeCats.where((c) => c['id'] == _categoryId).firstOrNull;
      }
      defaultCat ??= activeCats.first;

      _categoryId = defaultCat['id'] as int?;
      _category = defaultCat['name']?.toString();
      _mbsCategories = activeCats;

      List<Map<String, dynamic>> topics = [];
      if (_categoryId != null && _observationType == 'Special Case') {
        topics = await _api.getBbsTopics(_categoryId!);
      }
      setState(() {
        _mbsTopics = topics;
      });

      if (_categoryId != null && _category != null) {
        await _loadBehaviorsForCategory(_categoryId!, _category!);
      }
    } catch (_) {
      if (_mbsBehaviorItems.isEmpty &&
          _categoryId != null &&
          _category != null) {
        await _loadBehaviorsForCategory(_categoryId!, _category!);
      }
    } finally {
      if (mounted) setState(() => _masterLoading = false);
    }
  }

  Future<void> _onCategoryChanged(Map<String, dynamic> cat) async {
    final catId = cat['id'] as int?;
    final catName = cat['name']?.toString();
    setState(() {
      _categoryId = catId;
      _category = catName;
      _topicId = null;
      _topicName = null;
      _behaviors.clear();
      _behaviorStatuses.clear();
      _mbsTopics = [];
    });
    if (catId == null || catName == null) return;
    await _loadBehaviorsForCategory(catId, catName);
    if (_observationType == 'Special Case') {
      try {
        final topics = await _api.getBbsTopics(catId);
        if (mounted) setState(() => _mbsTopics = topics);
      } catch (_) {}
    }
  }

  Future<void> _selectTopic(int? id, String? name) async {
    setState(() {
      _topicId = id;
      _topicName = name;
      _behaviors.clear();
      _behaviorStatuses.clear();
      _masterLoading = id != null;
    });
    if (id == null || _categoryId == null) return;
    try {
      final behaviors = await _api.getBbsBehaviors(_categoryId!, topicId: id);
      if (behaviors.isNotEmpty && mounted) {
        setState(() {
          _mbsBehaviorItems = behaviors;
          _masterLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _masterLoading = false);
    }
  }

  // ==================== WORKER / PJA SEARCH (ONLINE & OFFLINE) ====================

  void _onWorkerSearchChanged(String value) {
    _workerDebounce?.cancel();
    _workerDebounce = Timer(const Duration(milliseconds: 250), () {
      _searchWorker(value);
    });
  }

  Future<void> _searchWorker(String value) async {
    final cleanQ = value.trim();
    if (cleanQ.isEmpty) {
      if (mounted) {
        setState(() {
          _workerResults = [];
          _workerSearching = false;
        });
      }
      return;
    }

    setState(() => _workerSearching = true);

    try {
      final safeQ = cleanQ.replaceAll("'", "''");
      final List<Map<String, dynamic>> results = [];
      final Set<String> seenNiks = {};

      // 1. Current user profile match / shortcut
      final profile = _profile;
      if (profile != null) {
        final myNik = (profile.noNik ?? '').trim();
        final myNama = (profile.namaLengkap ?? '').trim();
        final myJab = (profile.posisi ?? profile.jabatan ?? 'Foreman/Officer').toString().trim();
        final myDept = (profile.depart ?? 'SYSTEM INTEGRATIONS').toString().trim();
        final myComp = (profile.company ?? 'PT INDEXIM COALINDO').toString().trim();

        final matchMyProfile = myNik.toLowerCase().contains(cleanQ.toLowerCase()) ||
            myNama.toLowerCase().contains(cleanQ.toLowerCase());

        if (matchMyProfile && myNik.isNotEmpty && seenNiks.add(myNik.toLowerCase())) {
          results.add({
            'nik': myNik,
            'nama': myNama,
            'jabatan': myJab,
            'departemen': myDept,
            'perusahaan': myComp,
            'perusahaanId': profile.companyId ?? 1,
            'foto': profile.foto,
          });
        }
      }

      // 2. Query local SQLite employees table (synced offline)
      try {
        final db = await _db.database;
        final localEmps = await db.rawQuery(
          "SELECT * FROM employees WHERE (nama_lengkap LIKE '%$safeQ%' OR no_nik LIKE '%$safeQ%') AND deleted_at IS NULL LIMIT 25",
        );
        for (var r in localEmps) {
          final nik = (r['no_nik'] ?? r['nik'] ?? '').toString().trim();
          final nama = (r['nama_lengkap'] ?? r['nama'] ?? '').toString().trim();
          final foto = (r['emp_foto'] ?? r['foto'])?.toString().trim();
          if (nik.isNotEmpty && nama.isNotEmpty && seenNiks.add(nik.toLowerCase())) {
            results.add({
              'nik': nik,
              'nama': nama,
              'jabatan': (r['emp_jab'] ?? r['jabatan'] ?? r['posisi'])?.toString().trim() ?? 'Karyawan',
              'departemen': (r['emp_dept'] ?? r['departemen'] ?? r['depart'])?.toString().trim() ?? 'GENERAL',
              'perusahaan': (r['emp_comp'] ?? r['perusahaan'] ?? 'PT INDEXIM COALINDO').toString().trim(),
              'perusahaanId': (r['company_id'] as num?)?.toInt() ?? 1,
              'foto': foto,
            });
          }
        }
      } catch (e) {
        debugPrint('[BbsForm] Local employees query error: $e');
      }

      // 3. Fallback to tbl_karyawan if available in SQLite
      try {
        final db = await _db.database;
        final localKaryawan = await db.rawQuery(
          "SELECT * FROM tbl_karyawan WHERE (nama LIKE '%$safeQ%' OR nik LIKE '%$safeQ%') LIMIT 25",
        );
        for (var r in localKaryawan) {
          final nik = (r['nik'] ?? '').toString().trim();
          final nama = (r['nama'] ?? '').toString().trim();
          final foto = (r['path_foto'] ?? r['foto'])?.toString().trim();
          if (nik.isNotEmpty && nama.isNotEmpty && seenNiks.add(nik.toLowerCase())) {
            results.add({
              'nik': nik,
              'nama': nama,
              'jabatan': (r['jabatan'] ?? 'Staff').toString().trim(),
              'departemen': (r['departemen'] ?? 'OPERASIONAL').toString().trim(),
              'perusahaan': (r['perusahaan'] ?? 'PT INDEXIM COALINDO').toString().trim(),
              'perusahaanId': (r['perusahaan_id'] as num?)?.toInt() ?? 1,
              'foto': foto,
            });
          }
        }
      } catch (_) {}

      // 4. Query Server Backend API /bbs/workers if connected
      if (results.length < 10) {
        try {
          final serverWorkers = await _api.searchBbsWorkers(cleanQ, companyId: _companyId);
          for (final w in serverWorkers) {
            final nik = w['nik']?.toString().trim() ?? '';
            final nama = w['nama']?.toString().trim() ?? '';
            if (nik.isNotEmpty && nama.isNotEmpty && seenNiks.add(nik.toLowerCase())) {
              results.add({
                'nik': nik,
                'nama': nama,
                'jabatan': w['jabatan']?.toString().trim() ?? 'Karyawan',
                'departemen': w['departemen']?.toString().trim() ?? 'GENERAL',
                'perusahaan': w['perusahaan']?.toString().trim() ?? (_companyName ?? 'PT INDEXIM COALINDO'),
                'perusahaanId': w['perusahaanId'] ?? _companyId ?? 1,
                'foto': w['foto']?.toString().trim(),
              });
            }
          }
        } catch (_) {}
      }

      if (mounted && _workerSearchCtrl.text.trim() == cleanQ) {
        setState(() {
          _workerResults = results;
          _workerSearching = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _workerSearching = false);
    }
  }

  void _selectSelfAsWorker() {
    final profile = _profile;
    if (profile == null) return;
    final myNik = (profile.noNik ?? '').trim();
    final myNama = (profile.namaLengkap ?? '').trim();
    if (myNik.isEmpty && myNama.isEmpty) return;

    _selectWorker({
      'nik': myNik,
      'nama': myNama,
      'jabatan': (profile.posisi ?? profile.jabatan ?? 'Foreman/Officer').toString().trim(),
      'departemen': (profile.depart ?? 'SYSTEM INTEGRATIONS').toString().trim(),
      'perusahaan': (profile.company ?? 'PT INDEXIM COALINDO').toString().trim(),
      'perusahaanId': profile.companyId ?? 1,
      'foto': profile.foto,
    });
  }

  void _selectWorker(Map<String, dynamic> worker) {
    setState(() {
      _observedNik.text = worker['nik']?.toString().trim() ?? '';
      _observedPerson.text = worker['nama']?.toString().trim() ?? '';
      _observedPosition.text = worker['jabatan']?.toString().trim() ?? '';
      final dept = worker['departemen']?.toString().trim() ?? '';
      if (dept.isNotEmpty) {
        _department.text = dept;
      }
      _workerPhoto = worker['foto']?.toString().trim();
      _workerPerusahaan = worker['perusahaan']?.toString().trim();

      final pId =
          worker['perusahaanId'] ?? worker['companyId'] ?? worker['company_id'];
      if (pId != null) {
        final parsedId = int.tryParse(pId.toString());
        if (parsedId != null && parsedId > 0 && parsedId != _companyId) {
          _companyId = parsedId;
          _companyName = _workerPerusahaan;
          _loadDepartmentsForCompany(parsedId);
        }
      }
      _workerResults = [];
      _workerSearchCtrl.clear();
    });
  }

  void _clearSelectedWorker() {
    setState(() {
      _observedNik.clear();
      _observedPerson.clear();
      _observedPosition.clear();
      _workerPhoto = null;
      _workerPerusahaan = null;
      _workerResults = [];
      _workerSearchCtrl.clear();
    });
  }

  // ==================== SUBMIT & VALIDATION ====================

  bool _validateForm() {
    if (_companyId == null) {
      SnackBarMsg.warning(
          context, 'Pilih Perusahaan / Kontraktor pekerja terlebih dahulu.');
      return false;
    }
    if (_area.isEmpty) {
      SnackBarMsg.warning(context, 'Pilih Area Utama observasi.');
      return false;
    }
    if (_observedPerson.text.trim().isEmpty) {
      SnackBarMsg.warning(
          context, 'Pilih pekerja yang diamati dari pencarian karyawan.');
      return false;
    }
    if (_department.text.trim().isEmpty) {
      SnackBarMsg.warning(context, 'Isi atau pilih Unit / Departemen pekerja.');
      return false;
    }
    if (_categoryId == null) {
      SnackBarMsg.warning(context, 'Pilih Kategori BBS.');
      return false;
    }
    if (_behaviors.isEmpty && _otherBehavior.text.trim().isEmpty) {
      SnackBarMsg.warning(
          context, 'Pilih minimal satu butir perilaku yang diamati.');
      return false;
    }
    if (_potentialConsequence.text.trim().isEmpty) {
      SnackBarMsg.warning(
          context, 'Lengkapi deskripsi risiko / konsekuensi potensial.');
      return false;
    }
    if (_immediateActions.isEmpty && _otherAction.text.trim().isEmpty) {
      SnackBarMsg.warning(
          context, 'Pilih minimal satu tindakan langsung yang diambil.');
      return false;
    }
    if (_coachingNotes.text.trim().isEmpty) {
      SnackBarMsg.warning(
          context, 'Lengkapi catatan dialog coaching dengan pekerja.');
      return false;
    }
    if (_commitment.text.trim().isEmpty) {
      SnackBarMsg.warning(
          context, 'Lengkapi komitmen / tindakan perbaikan pekerja.');
      return false;
    }
    return true;
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_validateForm()) return;

    setState(() => _saving = true);
    final behaviors = [..._behaviors];
    if (_otherBehavior.text.trim().isNotEmpty) {
      behaviors.add(_otherBehavior.text.trim());
    }
    final actions = [..._immediateActions];
    if (_otherAction.text.trim().isNotEmpty) {
      actions.add(_otherAction.text.trim());
    }
    final requiresFollowUp = _classification == 'Perilaku Berisiko' ||
        _riskLevel == 'Tinggi' ||
        _riskLevel == 'Sangat Tinggi';

    final behaviorEntries = behaviors.map((text) {
      final master = _mbsBehaviorItems
          .where((item) => item['behaviorText']?.toString() == text);
      return jsonEncode({
        'id': master.isEmpty ? 0 : master.first['id'],
        'text': text,
        'status': _behaviorStatuses[text] ?? 'Aman',
      });
    }).toList();

    final selectedCompany = _mbsCompanies.where(
      (c) => int.tryParse((c['Id'] ?? c['id']).toString()) == _companyId,
    );
    final companyName = selectedCompany.isEmpty
        ? (_workerPerusahaan ?? _companyName ?? _profile?.company ?? '')
        : (selectedCompany.first['Nama'] ??
                selectedCompany.first['nama'] ??
                selectedCompany.first['name'] ??
                '')
            .toString();

    final form = <String, dynamic>{
      'Id': '0',
      'ObservationType':
          _observationType == 'Special Case' ? 'SpecialCase' : 'Rutin',
      'Tanggal': DateFormat('yyyy-MM-dd').format(_observedAt),
      'waktuStr': DateFormat('HH:mm').format(_observedAt),
      'Area': _area,
      'DetilLokasi': _benchmark,
      'Site': _coordinate.text.trim(),
      'ObservedNik': _observedNik.text.trim(),
      'ObservedNama': _observedPerson.text.trim(),
      'ObservedJabatan': _observedPosition.text.trim(),
      'ObservedDept': _department.text.trim(),
      'ObservedPerusahaanId': _companyId?.toString() ?? '',
      'ObservedPerusahaan': companyName,
      'CategoryId': _categoryId.toString(),
      'CategoryName': _category ?? '',
      if (_topicId != null) 'TopicId': _topicId.toString(),
      if (_topicName != null) 'TopicName': _topicName!,
      'Klasifikasi': _classification == 'Perilaku Aman' ? 'Aman' : 'Berisiko',
      'TingkatRisiko': _riskLevel,
      'KondisiJalan': _roadCondition,
      'KondisiKerja': _trafficCondition,
      'Deskripsi': _potentialConsequence.text.trim(),
      'ResponsPekerja': _workerResponse,
      'CatatanCoaching':
          '${_coachingNotes.text.trim()}\n${_commitment.text.trim()}'.trim(),
      for (var i = 0; i < behaviorEntries.length; i++)
        'selectedBehaviors[$i]': behaviorEntries[i],
      'triggers': _triggerFactors.toList(),
      'actions': actions,
    };

    final localId =
        'BBS-${DateFormat('yyyyMMdd-HHmmss').format(DateTime.now())}';
    final online = OfflineSyncService.instance.state.value.isOnline;
    final synced = online &&
        await _api.submitBbs(
          form,
          photoPath: _evidencePaths.isEmpty ? null : _evidencePaths.first,
        );

    final observation = BbsObservation(
      id: localId,
      observerName: _profile?.namaLengkap ?? '-',
      observerNik: _profile?.noNik ?? '-',
      observationType: _observationType,
      companyId: _companyId,
      location: [_area, _benchmark, _coordinate.text.trim()]
          .where((part) => part.isNotEmpty)
          .join(' • '),
      department: _department.text.trim(),
      observedPerson: _observedPerson.text.trim(),
      observedPosition: _observedPosition.text.trim(),
      observedAt: _observedAt,
      category: _category ?? 'BBS',
      behaviors: behaviors,
      classification: _classification,
      roadCondition: _roadCondition,
      weatherCondition: 'Cerah',
      trafficCondition: _trafficCondition,
      triggerFactors: [..._triggerFactors],
      riskLevel: _riskLevel,
      potentialConsequence: _potentialConsequence.text.trim(),
      immediateActions: actions,
      workerResponse: _workerResponse,
      coachingNotes: _coachingNotes.text.trim(),
      commitment: _commitment.text.trim(),
      dueDate: _dueDate,
      evidencePaths: [..._evidencePaths],
      status: requiresFollowUp ? 'Open' : 'Closed',
      followUpNotes: '',
      syncStatus: synced ? 'Synced' : 'Pending',
    );

    await BbsStorage.save(observation);
    if (!synced) {
      await OfflineSyncService.instance.enqueue(
        feature: 'bbs',
        localId: localId,
        payload: {
          'form': form,
          if (_evidencePaths.isNotEmpty) 'photoPath': _evidencePaths.first,
        },
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);
    await showProfessionalSuccessSheet(
      context: context,
      title: 'Observasi BBS Berhasil Disimpan!',
      subtitle: synced
          ? 'Data observasi perilaku K3 telah tersimpan dengan aman.'
          : 'Data tersimpan di penyimpanan lokal HP & otomatis disinkronkan saat online.',
      referenceNumber:
          'BBS-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
      accentColor: const Color(0xFF2563EB),
      icon: Icons.visibility_rounded,
      isOffline: !synced,
      statusBadgeText: synced ? 'BERHASIL TERSIMPAN' : 'TERSIMPAN DI PERANGKAT',
      receiptItems: [
        SuccessReceiptItem(
            label: 'Pekerja Diamati',
            value:
                '${_observedPerson.text.trim()} (${_observedNik.text.trim()})',
            isHighlight: true),
        SuccessReceiptItem(
            label: 'Perusahaan / Dept',
            value: '${_companyName ?? "-"} - ${_observedPosition.text.trim()}'),
        SuccessReceiptItem(
            label: 'Lokasi Observasi', value: '$_area - $_benchmark'),
        SuccessReceiptItem(
            label: 'Komitmen Perbaikan',
            value: _commitment.text.trim().isEmpty
                ? 'Pekerja berkomitmen taat K3'
                : _commitment.text.trim()),
      ],
      primaryButtonText: 'Buka Detail Observasi',
    );
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => BbsDetailPage(observation)),
      );
    }
  }

  // ==================== PHOTO PICKER ====================

  Future<void> _pickEvidence() async {
    if (_evidencePaths.isNotEmpty) {
      SnackBarMsg.warning(
          context, 'BBS hanya menerima 1 foto bukti observasi.');
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Wrap(
            children: [
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE0F2FE),
                  child: Icon(Icons.camera_alt_rounded, color: _kPrimary),
                ),
                title: const Text('Ambil Foto Kamera',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFF1F5F9),
                  child: Icon(Icons.photo_library_rounded,
                      color: Color(0xFF475569)),
                ),
                title: const Text('Pilih dari Galeri',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (image != null && mounted) {
      setState(() => _evidencePaths.add(image.path));
    }
  }

  // ==================== UI BUILD ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgColor,
      appBar: const TopBar(title: 'Form Observasi BBS', back: 2),
      body: SingleChildScrollView(
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card
            const SapHeaderCard(
              title: 'Formulir Observasi BBS',
              subtitle:
                  'Amati perilaku kerja lapangan, beri apresiasi perilaku aman, dan lakukan dialog coaching.',
              icon: Icons.person_pin_circle_rounded,
              accentColor: _kPrimary,
              badgeBgColor: Color(0xFFF0F9FF),
              badgeBorderColor: Color(0xFFBAE6FD),
            ),

            // SECTION 1: INFORMASI OBSERVASI
            SapSectionCard(
              stepNumber: '1',
              title: 'INFORMASI OBSERVASI',
              subtitle: 'Tanggal, jam, tipe observasi, area dan koordinat GPS',
              icon: Icons.calendar_month_rounded,
              accentColor: _kPrimary,
              children: [
                // Date & Time
                Row(
                  children: [
                    Expanded(
                      child: SapDatePickerTile(
                        label: 'Tanggal Observasi',
                        date: _observedAt,
                        onTap: () async {
                          final picked = await AppDateTimePicker.showDatePickerDialog(
                            context: context,
                            initialDate: _observedAt,
                            restrict3DaysBack: true,
                          );
                          if (picked != null) {
                            setState(() {
                              _observedAt = DateTime(
                                picked.year,
                                picked.month,
                                picked.day,
                                _observedAt.hour,
                                _observedAt.minute,
                              );
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SapTimePickerTile(
                        label: 'Waktu Observasi',
                        timeText: DateFormat('HH:mm').format(_observedAt),
                        onTap: () async {
                          final picked = await AppDateTimePicker.showTimePickerDialog(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(_observedAt),
                          );
                          if (picked != null) {
                            setState(() {
                              _observedAt = DateTime(
                                _observedAt.year,
                                _observedAt.month,
                                _observedAt.day,
                                picked.hour,
                                picked.minute,
                              );
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Tipe Observasi
                const Text('TIPE OBSERVASI *',
                    style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _ChoicePill(
                        label: 'Observasi Rutin',
                        icon: Icons.visibility_rounded,
                        isSelected: _observationType == 'Observasi Rutin',
                        onTap: () {
                          setState(() => _observationType = 'Observasi Rutin');
                          _loadMbsCategories();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ChoicePill(
                        label: 'Special Case',
                        icon: Icons.crisis_alert_rounded,
                        isSelected: _observationType == 'Special Case',
                        onTap: () {
                          setState(() => _observationType = 'Special Case');
                          _loadMbsCategories();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Area Utama (Like Hazard)
                const Text('AREA UTAMA *',
                    style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5)),
                const SizedBox(height: 6),
                _PickerTile(
                  icon: Icons.map_rounded,
                  value: _area.isEmpty ? null : _area,
                  hint: _isLoadingAreas && _masterAreas.isEmpty
                      ? 'Memuat daftar area...'
                      : 'Pilih Area Utama (seperti di Hazard)',
                  enabled: true,
                  onTap: _showAreaPickerModal,
                ),
                const SizedBox(height: 14),

                // Detail Lokasi / Benchmark (Like Hazard)
                const Text('DETAIL LOKASI / BENCHMARK *',
                    style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5)),
                const SizedBox(height: 6),
                _PickerTile(
                  icon: Icons.place_rounded,
                  value: _benchmark.isEmpty ? null : _benchmark,
                  hint: _area.isEmpty
                      ? 'Pilih Area Utama terlebih dahulu'
                      : (_isLoadingBenchmarks && _benchmarksList.isEmpty
                          ? 'Memuat benchmark...'
                          : 'Pilih Detail Lokasi / Benchmark'),
                  enabled: _area.isNotEmpty,
                  onTap: _showBenchmarkPickerModal,
                ),
                const SizedBox(height: 14),

                // GPS
                const Text('TITIK KOORDINAT GPS (AKTUAL)',
                    style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5)),
                const SizedBox(height: 6),
                TextField(
                  controller: _coordinate,
                  readOnly: true,
                  decoration: gpsInputDecoration(
                    context: context,
                    onPressed: () => fillGpsCoordinate(
                      context,
                      _coordinate,
                      () => setState(() {}),
                    ),
                    iconColor: _kPrimary,
                  ).copyWith(
                    hintText: 'Ketuk ikon GPS untuk mengambil posisi terkini',
                    hintStyle:
                        const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // SECTION 2: PEKERJA YANG DIOBSERVASI / PJA
            SapSectionCard(
              stepNumber: '2',
              title: 'PEKERJA YANG DIOBSERVASI (PJA)',
              subtitle:
                  'Perusahaan, departemen, dan pengawas / pekerja lapangan',
              icon: Icons.person_search_rounded,
              accentColor: _kPrimary,
              children: [
                // Perusahaan / Kontraktor
                const Text('PERUSAHAAN / KONTRAKTOR *',
                    style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5)),
                const SizedBox(height: 6),
                _PickerTile(
                  icon: Icons.business_rounded,
                  value: _companyName ??
                      _mbsCompanies
                          .where((c) =>
                              int.tryParse((c['Id'] ?? c['id']).toString()) ==
                              _companyId)
                          .map((c) =>
                              (c['Nama'] ?? c['nama'] ?? c['name']).toString())
                          .firstOrNull,
                  hint: _mbsCompanies.isEmpty
                      ? 'Memuat perusahaan...'
                      : 'Pilih Perusahaan / Kontraktor',
                  enabled: _mbsCompanies.isNotEmpty,
                  onTap: () async {
                    final names = _mbsCompanies
                        .map((c) =>
                            (c['Nama'] ?? c['nama'] ?? c['name']).toString())
                        .toList();
                    final picked = await _showSearchSheet(
                        'Pilih Perusahaan / Kontraktor', names);
                    if (picked == null || !mounted) return;
                    final comp = _mbsCompanies.firstWhere((c) =>
                        (c['Nama'] ?? c['nama'] ?? c['name']).toString() ==
                        picked);
                    final newCid =
                        int.tryParse((comp['Id'] ?? comp['id']).toString());
                    setState(() {
                      _companyId = newCid;
                      _companyName = picked;
                      _department.clear();
                      _clearSelectedWorker();
                    });
                    if (newCid != null) {
                      _loadDepartmentsForCompany(newCid);
                    }
                  },
                ),
                const SizedBox(height: 14),

                // Unit / Departemen (Synchronized to Company)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('UNIT / DEPARTEMEN *',
                        style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5)),
                    if (_departmentsLoading)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _kPrimary),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                _PickerTile(
                  icon: Icons.apartment_rounded,
                  value: _department.text.isEmpty ? null : _department.text,
                  hint: _companyId == null
                      ? 'Pilih perusahaan terlebih dahulu'
                      : (_departmentsLoading && _departmentOptions.isEmpty
                          ? 'Memuat departemen...'
                          : 'Pilih Departemen sesuai ${_companyName ?? "Perusahaan"}'),
                  enabled: _companyId != null,
                  onTap: _showDepartmentPickerModal,
                ),
                const SizedBox(height: 14),

                // Selected Worker Card (Persis seperti Web BBS)
                if (_observedPerson.text.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: const Color(0xFF86EFAC), width: 1.2),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SapEmployeeAvatar(
                          photo: _workerPhoto,
                          name: _observedPerson.text,
                          nik: _observedNik.text,
                          radius: 24,
                          fallbackBg: _kSuccess,
                          fallbackFg: Colors.white,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _observedPerson.text,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                [
                                  if (_observedNik.text.isNotEmpty)
                                    'NIK: ${_observedNik.text}',
                                  if (_observedPosition.text.isNotEmpty)
                                    _observedPosition.text,
                                  if (_department.text.isNotEmpty)
                                    _department.text,
                                  if (_workerPerusahaan != null &&
                                      _workerPerusahaan!.isNotEmpty)
                                    _workerPerusahaan!,
                                ].join(' • '),
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xFF475569)),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _clearSelectedWorker,
                          icon: const Icon(Icons.close_rounded,
                              color: _kDanger, size: 20),
                          tooltip: 'Ganti Pekerja',
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFFEE2E2),
                            padding: const EdgeInsets.all(6),
                            minimumSize: const Size(32, 32),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  // Badges: Wajib Terdaftar & Pilih Saya Sendiri
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_user_rounded,
                                size: 14, color: _kPrimary),
                            SizedBox(width: 6),
                            Text(
                              'Wajib Karyawan Terdaftar',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (_profile != null)
                        InkWell(
                          onTap: _selectSelfAsWorker,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F9FF),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: const Color(0xFFBAE6FD)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person_add_alt_1_rounded,
                                    size: 14, color: _kPrimary),
                                SizedBox(width: 5),
                                Text(
                                  'Pilih Saya Sendiri',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _kPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Search Worker Input (Fast & Debounced)
                  const Text('CARI PEKERJA (SEMUA KARYAWAN AKTIF) *',
                      style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _workerSearchCtrl,
                    onChanged: _onWorkerSearchChanged,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: 'Cari nama atau NIK pengawas / pekerja terdaftar...',
                      hintStyle: const TextStyle(
                          color: Color(0xFF94A3B8), fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: _kPrimary, size: 20),
                      suffixIcon: _workerSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: _kPrimary)),
                            )
                          : (_workerSearchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _workerSearchCtrl.clear();
                                    setState(() => _workerResults = []);
                                  },
                                )
                              : null),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: _kPrimary, width: 1.5)),
                    ),
                  ),

                  // Worker Search Results Card
                  if (_workerResults.isNotEmpty &&
                      _workerSearchCtrl.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 260),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _workerResults.length,
                          separatorBuilder: (_, __) => const Divider(
                              height: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (context, index) {
                            final w = _workerResults[index];
                            final name = w['nama']?.toString().trim() ?? '-';
                            final nik = w['nik']?.toString().trim() ?? '-';
                            final role = w['jabatan']?.toString().trim() ?? '';
                            final dept =
                                w['departemen']?.toString().trim() ?? '';
                            final comp =
                                w['perusahaan']?.toString().trim() ?? '';
                            final photo = w['foto']?.toString().trim();

                            return ListTile(
                              leading: SapEmployeeAvatar(
                                photo: photo,
                                name: name,
                                nik: nik,
                                radius: 20,
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                    color: Color(0xFF0F172A)),
                              ),
                              subtitle: Text(
                                [
                                  'NIK: $nik',
                                  if (role.isNotEmpty) role,
                                  if (dept.isNotEmpty) dept,
                                  if (comp.isNotEmpty) comp,
                                ].join(' • '),
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xFF64748B)),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 13,
                                  color: Color(0xFF94A3B8)),
                              onTap: () => _selectWorker(w),
                            );
                          },
                        ),
                      ),
                    ),
                  ],

                  // Empty Search State
                  if (_workerResults.isEmpty &&
                      _workerSearchCtrl.text.trim().isNotEmpty &&
                      !_workerSearching) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Karyawan / PJA tidak ditemukan. Wajib memilih karyawan yang terdaftar di sistem.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFFDC2626),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_profile != null) ...[
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _selectSelfAsWorker,
                              icon: const Icon(Icons.person_pin_rounded,
                                  size: 16, color: _kPrimary),
                              label: Text(
                                'Gunakan Saya: ${_profile?.namaLengkap ?? ''} (${_profile?.noNik ?? ''})',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: _kPrimary,
                                    fontWeight: FontWeight.bold),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                    color: Color(0xFFBAE6FD)),
                                backgroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],

                // Role/Position
                const SizedBox(height: 14),
                const Text('JABATAN / PERAN (OPSIONAL)',
                    style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5)),
                const SizedBox(height: 6),
                TextField(
                  controller: _observedPosition,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'Contoh: Operator Hauler / Mekanik / Supervisor',
                    hintStyle:
                        const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    prefixIcon: const Icon(Icons.badge_outlined,
                        color: _kPrimary, size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // SECTION 3: KATEGORI & BUTIR PERILAKU
            SapSectionCard(
              stepNumber: '3',
              title: 'KATEGORI & BUTIR PERILAKU',
              subtitle:
                  'Pilih topik BBS dan amati butir perilaku secara spesifik',
              icon: Icons.checklist_rounded,
              accentColor: _kPrimary,
              children: [
                // Kategori
                const Text('KATEGORI BBS *',
                    style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5)),
                const SizedBox(height: 6),
                _PickerTile(
                  icon: Icons.category_rounded,
                  value: _category,
                  hint: _mbsCategories.isEmpty
                      ? 'Memuat kategori BBS...'
                      : 'Pilih Kategori BBS',
                  enabled: _mbsCategories.isNotEmpty,
                  onTap: () async {
                    final names = _mbsCategories
                        .map((c) => c['name']?.toString() ?? '')
                        .where((s) => s.isNotEmpty)
                        .toList();
                    final picked =
                        await _showSearchSheet('Pilih Kategori BBS', names);
                    if (picked == null || !mounted) return;
                    final cat = _mbsCategories
                        .firstWhere((c) => c['name']?.toString() == picked);
                    _onCategoryChanged(cat);
                  },
                ),

                // Special Case Topic
                if (_observationType == 'Special Case' &&
                    _mbsTopics.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text('SUB-TOPIK SPECIAL CASE *',
                      style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  _PickerTile(
                    icon: Icons.bolt_rounded,
                    value: _topicName,
                    hint: 'Pilih Sub-Topik Special Case',
                    enabled: true,
                    onTap: () async {
                      final names = _mbsTopics
                          .map((t) => t['name']?.toString() ?? '')
                          .where((s) => s.isNotEmpty)
                          .toList();
                      final picked =
                          await _showSearchSheet('Pilih Sub-Topik', names);
                      if (picked == null || !mounted) return;
                      final topic = _mbsTopics
                          .firstWhere((t) => t['name']?.toString() == picked);
                      _selectTopic(topic['id'] as int?, picked);
                    },
                  ),
                ],

                // Behaviors List
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('BUTIR PERILAKU YANG DIAMATI *',
                        style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5)),
                    if (_masterLoading)
                      const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _kPrimary)),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Centang perilaku yang diamati, lalu tentukan Aman atau Berisiko:',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                ),
                const SizedBox(height: 10),

                if (_mbsBehaviorItems.isEmpty && !_masterLoading)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Center(
                      child: TextButton.icon(
                        onPressed: () => _loadBehaviorsForCategory(
                            _categoryId ?? 1,
                            _category ?? 'Interaksi Alat & Manusia'),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Muat Butir Perilaku Standar',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),

                ..._mbsBehaviorItems.map((item) {
                  final text = item['behaviorText']?.toString() ??
                      item['text']?.toString() ??
                      '';
                  final isChecked = _behaviors.contains(text);
                  final status = _behaviorStatuses[text] ?? 'Aman';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isChecked
                          ? (status == 'Aman'
                              ? const Color(0xFFECFDF5)
                              : const Color(0xFFFEF2F2))
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isChecked
                            ? (status == 'Aman'
                                ? const Color(0xFF6EE7B7)
                                : const Color(0xFFFCA5A5))
                            : const Color(0xFFE2E8F0),
                        width: isChecked ? 1.4 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        CheckboxListTile(
                          value: isChecked,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _behaviors.add(text);
                                _behaviorStatuses[text] = 'Aman';
                              } else {
                                _behaviors.remove(text);
                                _behaviorStatuses.remove(text);
                              }
                              _updateClassificationFromBehaviors();
                            });
                          },
                          title: Text(
                            text,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight:
                                  isChecked ? FontWeight.w700 : FontWeight.w500,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          activeColor: status == 'Aman' ? _kSuccess : _kDanger,
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        if (isChecked)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                            child: Row(
                              children: [
                                const Text('Status Pengamatan:',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w600)),
                                const Spacer(),
                                _StatusToggleChip(
                                  label: 'Aman',
                                  color: _kSuccess,
                                  icon: Icons.check_circle_rounded,
                                  isActive: status == 'Aman',
                                  onTap: () {
                                    setState(() {
                                      _behaviorStatuses[text] = 'Aman';
                                      _updateClassificationFromBehaviors();
                                    });
                                  },
                                ),
                                const SizedBox(width: 8),
                                _StatusToggleChip(
                                  label: 'Berisiko',
                                  color: _kDanger,
                                  icon: Icons.warning_rounded,
                                  isActive: status == 'Berisiko',
                                  onTap: () {
                                    setState(() {
                                      _behaviorStatuses[text] = 'Berisiko';
                                      _updateClassificationFromBehaviors();
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                }),

                // Other behavior
                const SizedBox(height: 10),
                const Text('PERILAKU LAINNYA (OPSIONAL)',
                    style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5)),
                const SizedBox(height: 6),
                TextField(
                  controller: _otherBehavior,
                  minLines: 2,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText:
                        'Tuliskan jika ada perilaku spesifik lain yang diamati di lapangan...',
                    hintStyle: const TextStyle(
                        color: Color(0xFF94A3B8), fontSize: 12.5),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(bottom: 24),
                      child: Icon(Icons.edit_note_rounded,
                          color: _kPrimary, size: 20),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _kPrimary, width: 1.5)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // SECTION 4: KLASIFIKASI & EVALUASI RISIKO
            SapSectionCard(
              stepNumber: '4',
              title: 'KLASIFIKASI & EVALUASI RISIKO',
              subtitle:
                  'Penilaian perilaku keseluruhan, tingkat risiko & kondisi kerja',
              icon: Icons.security_rounded,
              accentColor: _kPrimary,
              children: [
                // Classification
                const Text('KLASIFIKASI PERILAKU *',
                    style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _ChoicePill(
                        label: 'Perilaku Aman',
                        icon: Icons.thumb_up_alt_rounded,
                        isSelected: _classification == 'Perilaku Aman',
                        activeColor: const Color(0xFF10B981),
                        onTap: () =>
                            setState(() => _classification = 'Perilaku Aman'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ChoicePill(
                        label: 'Perilaku Berisiko',
                        icon: Icons.thumb_down_alt_rounded,
                        isSelected: _classification == 'Perilaku Berisiko',
                        activeColor: const Color(0xFFEF4444),
                        onTap: () => setState(
                            () => _classification = 'Perilaku Berisiko'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Risk Level
                const Text('TINGKAT RISIKO / POTENSI DAMPAK *',
                    style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _RiskPill(
                      label: 'Rendah',
                      color: const Color(0xFF16A34A),
                      isSelected: _riskLevel == 'Rendah',
                      onTap: () => setState(() => _riskLevel = 'Rendah'),
                    ),
                    _RiskPill(
                      label: 'Sedang',
                      color: const Color(0xFFD97706),
                      isSelected: _riskLevel == 'Sedang',
                      onTap: () => setState(() => _riskLevel = 'Sedang'),
                    ),
                    _RiskPill(
                      label: 'Tinggi',
                      color: const Color(0xFFEA580C),
                      isSelected: _riskLevel == 'Tinggi',
                      onTap: () => setState(() => _riskLevel = 'Tinggi'),
                    ),
                    _RiskPill(
                      label: 'Sangat Tinggi',
                      color: const Color(0xFFDC2626),
                      isSelected: _riskLevel == 'Sangat Tinggi',
                      onTap: () => setState(() => _riskLevel = 'Sangat Tinggi'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Road & Traffic Condition
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('KONDISI JALAN / AREA',
                              style: TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          _PickerTile(
                            icon: Icons.terrain_rounded,
                            value: _roadCondition,
                            hint: 'Pilih Kondisi',
                            enabled: true,
                            onTap: () async {
                              final picked = await _showSearchSheet(
                                  'Kondisi Jalan / Area', const [
                                'Normal / Kering',
                                'Basah / Licin',
                                'Berdebu / Kabut',
                                'Bergelombang / Rusak',
                              ]);
                              if (picked != null) {
                                setState(() => _roadCondition = picked);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('KEPADATAN TRAFFIC',
                              style: TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          _PickerTile(
                            icon: Icons.traffic_rounded,
                            value: _trafficCondition,
                            hint: 'Pilih Traffic',
                            enabled: true,
                            onTap: () async {
                              final picked = await _showSearchSheet(
                                  'Kepadatan Traffic', const [
                                'Lancar',
                                'Sedang',
                                'Padat / Ramai',
                              ]);
                              if (picked != null) {
                                setState(() => _trafficCondition = picked);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Trigger Factors Card
                Container(
                  padding: const EdgeInsets.all(14),
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
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.bolt_rounded,
                                    size: 16, color: Color(0xFFD97706)),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'FAKTOR PEMICU / PENYEBAB',
                                style: TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                          if (_triggerFactors.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(99),
                                border:
                                    Border.all(color: const Color(0xFFBAE6FD)),
                              ),
                              child: Text(
                                '${_triggerFactors.length} Dipilih',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0369A1),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Pilih faktor atau kondisi yang mempengaruhi perilaku pekerja (bisa lebih dari satu):',
                        style:
                            TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 12),
                      Column(
                        children: [
                          for (int i = 0;
                              i < _kTriggerFactorItems.length;
                              i += 2)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _TriggerCard(
                                      item: _kTriggerFactorItems[i],
                                      isSelected: _triggerFactors.contains(
                                          _kTriggerFactorItems[i].title),
                                      onTap: () {
                                        setState(() {
                                          if (_triggerFactors.contains(
                                              _kTriggerFactorItems[i].title)) {
                                            _triggerFactors.remove(
                                                _kTriggerFactorItems[i].title);
                                          } else {
                                            _triggerFactors.add(
                                                _kTriggerFactorItems[i].title);
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: (i + 1 < _kTriggerFactorItems.length)
                                        ? _TriggerCard(
                                            item: _kTriggerFactorItems[i + 1],
                                            isSelected:
                                                _triggerFactors.contains(
                                                    _kTriggerFactorItems[i + 1]
                                                        .title),
                                            onTap: () {
                                              setState(() {
                                                if (_triggerFactors.contains(
                                                    _kTriggerFactorItems[i + 1]
                                                        .title)) {
                                                  _triggerFactors.remove(
                                                      _kTriggerFactorItems[
                                                              i + 1]
                                                          .title);
                                                } else {
                                                  _triggerFactors.add(
                                                      _kTriggerFactorItems[
                                                              i + 1]
                                                          .title);
                                                }
                                              });
                                            },
                                          )
                                        : const SizedBox(),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // SECTION 5: DESKRIPSI & TINDAKAN COACHING
            SapSectionCard(
              stepNumber: '5',
              title: 'DESKRIPSI & TINDAKAN COACHING',
              subtitle:
                  'Catatan pengamatan, respon pekerja, dan dialog coaching',
              icon: Icons.record_voice_over_rounded,
              accentColor: _kPrimary,
              children: [
                // Potential Consequence
                const Text('DESKRIPSI PENGAMATAN / POTENSI DAMPAK *',
                    style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5)),
                const SizedBox(height: 6),
                TextField(
                  controller: _potentialConsequence,
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText:
                        'Jelaskan apa yang sedang dilakukan pekerja dan potensi dampak bahayanya...',
                    hintStyle: const TextStyle(
                        color: Color(0xFF94A3B8), fontSize: 12.5),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                ),
                const SizedBox(height: 14),

                // Tindakan Langsung Card
                Container(
                  padding: const EdgeInsets.all(14),
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
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.flash_on_rounded,
                                    size: 16, color: Color(0xFF16A34A)),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'TINDAKAN LANGSUNG YANG DIAMBIL *',
                                style: TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                          if (_immediateActions.isNotEmpty ||
                              _otherAction.text.trim().isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(99),
                                border:
                                    Border.all(color: const Color(0xFF86EFAC)),
                              ),
                              child: Text(
                                '${_immediateActions.length + (_otherAction.text.trim().isNotEmpty ? 1 : 0)} Tindakan',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Pilih aksi korektif / coaching yang langsung Anda lakukan di lokasi:',
                        style:
                            TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 12),
                      ..._kImmediateActionItems.map((action) {
                        final isSelected =
                            _immediateActions.contains(action.title);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _ActionCardTile(
                            item: action,
                            isSelected: isSelected,
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _immediateActions.remove(action.title);
                                } else {
                                  _immediateActions.add(action.title);
                                }
                              });
                            },
                          ),
                        );
                      }),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.edit_note_rounded,
                                    size: 18, color: Colors.blueGrey.shade600),
                                const SizedBox(width: 6),
                                const Text(
                                  'Tindakan Langsung Lainnya (Opsional)',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _otherAction,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText:
                                    'Tuliskan tindakan lapangan spesifik lainnya jika ada...',
                                hintStyle: const TextStyle(
                                    color: Color(0xFF94A3B8), fontSize: 12),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFE2E8F0)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFE2E8F0)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: _kPrimary, width: 1.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Respons Pekerja
                const Text('RESPONS PEKERJA *',
                    style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _ChoicePill(
                        label: 'Positif',
                        icon: Icons.sentiment_satisfied_alt_rounded,
                        isSelected: _workerResponse == 'Positif',
                        activeColor: _kSuccess,
                        onTap: () =>
                            setState(() => _workerResponse = 'Positif'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ChoicePill(
                        label: 'Netral',
                        icon: Icons.sentiment_neutral_rounded,
                        isSelected: _workerResponse == 'Netral',
                        activeColor: _kWarning,
                        onTap: () => setState(() => _workerResponse = 'Netral'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ChoicePill(
                        label: 'Resisten',
                        icon: Icons.sentiment_dissatisfied_rounded,
                        isSelected: _workerResponse == 'Resisten',
                        activeColor: _kDanger,
                        onTap: () =>
                            setState(() => _workerResponse = 'Resisten'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Catatan Coaching
                const Text('CATATAN COACHING & DIALOG *',
                    style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5)),
                const SizedBox(height: 6),
                TextField(
                  controller: _coachingNotes,
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText:
                        'Tuliskan dialog perbaikan, pemahaman pekerja, dan pesan keselamatan...',
                    hintStyle: const TextStyle(
                        color: Color(0xFF94A3B8), fontSize: 12.5),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                ),
                const SizedBox(height: 14),

                // Komitmen Pekerja
                const Text('KOMITMEN PEKERJA *',
                    style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5)),
                const SizedBox(height: 6),
                TextField(
                  controller: _commitment,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText:
                        'Tuliskan kesepakatan atau komitmen dari pekerja...',
                    hintStyle: const TextStyle(
                        color: Color(0xFF94A3B8), fontSize: 12.5),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                ),
                const SizedBox(height: 14),

                // Due Date
                const Text('TARGET FOLLOW UP (OPSIONAL)',
                    style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5)),
                const SizedBox(height: 6),
                _PickerTile(
                  icon: Icons.event_available_rounded,
                  value: _dueDate == null
                      ? null
                      : DateFormat('dd MMMM yyyy').format(_dueDate!),
                  hint: 'Pilih tanggal target perbaikan / evaluasi',
                  enabled: true,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dueDate ??
                          DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => _dueDate = picked);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // SECTION 6: LAMPIRAN FOTO DOKUMENTASI
            SapSectionCard(
              stepNumber: '6',
              title: 'LAMPIRAN FOTO DOKUMENTASI',
              subtitle: 'Foto bukti pengamatan perilaku atau kondisi di lokasi',
              icon: Icons.camera_alt_rounded,
              accentColor: _kPrimary,
              children: [
                if (_evidencePaths.isNotEmpty)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(
                          File(_evidencePaths.first),
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: CircleAvatar(
                          backgroundColor: Colors.black.withValues(alpha: 0.65),
                          radius: 18,
                          child: IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: Colors.white, size: 18),
                            onPressed: () =>
                                setState(() => _evidencePaths.clear()),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  InkWell(
                    onTap: _pickEvidence,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      height: 130,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: const Color(0xFFBAE6FD),
                            width: 1.5,
                            style: BorderStyle.solid),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              backgroundColor: Color(0xFFE0F2FE),
                              radius: 22,
                              child: Icon(Icons.add_a_photo_rounded,
                                  color: _kPrimary, size: 22),
                            ),
                            SizedBox(height: 8),
                            Text('Ketuk untuk Ambil Foto Bukti Observasi',
                                style: TextStyle(
                                    color: _kPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold)),
                            SizedBox(height: 2),
                            Text('Kamera atau Galeri (1 Foto)',
                                style: TextStyle(
                                    color: Color(0xFF64748B), fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 28),

            // SUBMIT BUTTON
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: _kPrimary,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 20),
              label: Text(
                _saving ? 'Mengirim Observasi BBS...' : 'Kirim Observasi BBS',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateClassificationFromBehaviors() {
    if (_behaviorStatuses.values.any((s) => s == 'Berisiko')) {
      _classification = 'Perilaku Berisiko';
    } else if (_behaviorStatuses.isNotEmpty) {
      _classification = 'Perilaku Aman';
    }
  }

  Future<String?> _showSearchSheet(String title, List<String> options) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String filter = '';
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final filtered = options
                .where((e) => e.toLowerCase().contains(filter.toLowerCase()))
                .toList();
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
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
                        Text(
                          title,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      autofocus: false,
                      onChanged: (v) => setModalState(() => filter = v),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: _kPrimary, size: 20),
                        hintText: 'Cari dalam daftar...',
                        hintStyle: const TextStyle(
                            fontSize: 13, color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 11),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (context, i) => ListTile(
                        dense: true,
                        title: Text(filtered[i],
                            style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A))),
                        trailing: const Icon(Icons.chevron_right_rounded,
                            size: 18, color: Color(0xFF94A3B8)),
                        onTap: () => Navigator.pop(modalCtx, filtered[i]),
                      ),
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
}

// ==================== HELPER WIDGETS ====================

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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon, color: _kPrimary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasVal ? value! : hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: hasVal ? FontWeight.w600 : FontWeight.normal,
                  color: hasVal
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF94A3B8),
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF64748B), size: 20),
          ],
        ),
      ),
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.activeColor = _kPrimary,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.12)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFFE2E8F0),
            width: isSelected ? 1.8 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color: isSelected ? activeColor : const Color(0xFF64748B)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? activeColor : const Color(0xFF334155),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RiskPill extends StatelessWidget {
  const _RiskPill({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color, width: isSelected ? 1.5 : 1),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}

class _StatusToggleChip extends StatelessWidget {
  const _StatusToggleChip({
    required this.label,
    required this.color,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final Color color;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? color : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: isActive ? Colors.white : color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== TRIGGER & ACTION HELPER WIDGETS ====================

class _TriggerItem {
  final String title;
  final String desc;
  final IconData icon;
  final Color color;
  const _TriggerItem({
    required this.title,
    required this.desc,
    required this.icon,
    required this.color,
  });
}

const _kTriggerFactorItems = [
  _TriggerItem(
    title: 'Terburu-buru / Target',
    desc: 'Mengejar waktu & deadline',
    icon: Icons.speed_rounded,
    color: Color(0xFFF59E0B),
  ),
  _TriggerItem(
    title: 'Kebiasaan',
    desc: 'Pola kebiasaan berulang',
    icon: Icons.replay_rounded,
    color: Color(0xFF3B82F6),
  ),
  _TriggerItem(
    title: 'Kurang kesadaran',
    desc: 'Belum sadar potensi risiko',
    icon: Icons.visibility_off_outlined,
    color: Color(0xFFEF4444),
  ),
  _TriggerItem(
    title: 'Pengawasan kurang',
    desc: 'Minim supervisi lapangan',
    icon: Icons.supervisor_account_outlined,
    color: Color(0xFF8B5CF6),
  ),
  _TriggerItem(
    title: 'Kelelahan (Fatigue)',
    desc: 'Kondisi fisik lelah / kantuk',
    icon: Icons.battery_alert_rounded,
    color: Color(0xFFF97316),
  ),
  _TriggerItem(
    title: 'Kondisi area',
    desc: 'Lokasi sempit, curam, dll',
    icon: Icons.terrain_rounded,
    color: Color(0xFF14B8A6),
  ),
  _TriggerItem(
    title: 'Cuaca / Visibilitas',
    desc: 'Hujan, kabut, debu tebal',
    icon: Icons.wb_cloudy_outlined,
    color: Color(0xFF0EA5E9),
  ),
  _TriggerItem(
    title: 'Instruksi kurang jelas',
    desc: 'SOP / arahan belum jelas',
    icon: Icons.assignment_late_outlined,
    color: Color(0xFF64748B),
  ),
];

class _TriggerCard extends StatelessWidget {
  const _TriggerCard({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final _TriggerItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? _kPrimary : const Color(0xFFE2E8F0),
              width: isSelected ? 1.6 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: _kPrimary.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected
                      ? _kPrimary.withValues(alpha: 0.15)
                      : item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  item.icon,
                  size: 17,
                  color: isSelected ? _kPrimary : item.color,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF334155),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.desc,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: isSelected
                            ? const Color(0xFF0284C7)
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 16,
                color: isSelected ? _kPrimary : const Color(0xFFCBD5E1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImmediateActionItem {
  final String title;
  final String desc;
  final IconData icon;
  final Color color;
  const _ImmediateActionItem({
    required this.title,
    required this.desc,
    required this.icon,
    required this.color,
  });
}

const _kImmediateActionItems = [
  _ImmediateActionItem(
    title: 'Memberikan apresiasi atas perilaku aman',
    desc: 'Pemberian apresiasi positif langsung di tempat',
    icon: Icons.thumb_up_alt_rounded,
    color: Color(0xFF10B981),
  ),
  _ImmediateActionItem(
    title: 'Melakukan diskusi / coaching di lokasi',
    desc: 'Dialog dua arah membahas cara kerja yang benar',
    icon: Icons.forum_rounded,
    color: Color(0xFF0284C7),
  ),
  _ImmediateActionItem(
    title: 'Memberikan teguran persuasif',
    desc: 'Mengingatkan konsekuensi bahaya secara tegas & santun',
    icon: Icons.warning_amber_rounded,
    color: Color(0xFFF59E0B),
  ),
  _ImmediateActionItem(
    title: 'Menghentikan aktivitas sementara (Stop Work)',
    desc: 'Aktivitas dihentikan hingga kondisi/tindakan aman',
    icon: Icons.pan_tool_rounded,
    color: Color(0xFFEF4444),
  ),
  _ImmediateActionItem(
    title: 'Melaporkan ke pengawas / supervisor',
    desc: 'Eskalasi ke penanggung jawab area atau atasan',
    icon: Icons.record_voice_over_rounded,
    color: Color(0xFF6366F1),
  ),
  _ImmediateActionItem(
    title: 'Perbaikan APD / Perlengkapan',
    desc: 'Penggantian atau penyesuaian APD/alat kerja langsung',
    icon: Icons.construction_rounded,
    color: Color(0xFF0D9488),
  ),
];

class _ActionCardTile extends StatelessWidget {
  const _ActionCardTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final _ImmediateActionItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF16A34A)
                  : const Color(0xFFE2E8F0),
              width: isSelected ? 1.6 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFDCFCE7)
                      : item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  item.icon,
                  size: 20,
                  color: isSelected ? const Color(0xFF15803D) : item.color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF1E293B),
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.desc,
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected
                            ? const Color(0xFF15803D)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 22,
                color: isSelected
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFCBD5E1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

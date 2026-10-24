import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../services/preference.dart';
import '../../services/api.dart';
import '../../services/database.dart';
import '../../services/offline_sync_service.dart';
import '../../widgets/sap_form_widgets.dart';
import '../../widgets/top_bar.dart';
import 'bbs_model.dart';
import 'bbs_page.dart';

const _blue = Color(0xFF075985);
const _green = Color(0xFF059669);
const _background = Color(0xFFF4F7FB);

Future<String?> _showMasterSearch(
  BuildContext context,
  String title,
  List<String> options,
) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _MasterSearchSheet(title: title, options: options),
  );
}

class _MasterPickerField extends StatelessWidget {
  const _MasterPickerField({
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
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: hint,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: BoxDecoration(
              color: enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Icon(icon, color: _blue, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    value ?? hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: value == null ? FontWeight.normal : FontWeight.w600,
                      color: value == null ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 20),
              ],
            ),
          ),
        ),
      );
}

class _MasterSearchSheet extends StatefulWidget {
  const _MasterSearchSheet({required this.title, required this.options});
  final String title;
  final List<String> options;
  @override State<_MasterSearchSheet> createState() => _MasterSearchSheetState();
}
class _MasterSearchSheetState extends State<_MasterSearchSheet> {
  String query = '';
  @override Widget build(BuildContext context) {
    final shown = widget.options.where((e) => e.toLowerCase().contains(query.toLowerCase())).toList();
    return SafeArea(child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(height: MediaQuery.sizeOf(context).height * .72, child: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: Row(children: [Expanded(child: Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))])),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: TextField(autofocus: true, onChanged: (v) => setState(() => query = v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Cari di daftar...'))),
        const SizedBox(height: 8),
        Expanded(child: ListView.builder(itemCount: shown.length, itemBuilder: (context, i) => ListTile(leading: const Icon(Icons.location_on_outlined, color: _blue), title: Text(shown[i]), onTap: () => Navigator.pop(context, shown[i])))),
      ])),
    ));
  }
}

class BbsFormPage extends StatefulWidget {
  const BbsFormPage({super.key});

  @override
  State<BbsFormPage> createState() => _BbsFormPageState();
}

class _BbsFormPageState extends State<BbsFormPage> {
  static const _stepTitles = [
    'Informasi Observasi',
    'Perilaku yang Diamati',
    'Klasifikasi & Konteks',
    'Risiko, Tindakan & Coaching',
    'Review & Simpan',
  ];

  final _profile = PreferenceService.getProfile();
  final _api = ApiService();
  final _coordinate = TextEditingController();
  final _department = TextEditingController();
  final _observedNik = TextEditingController();
  final _observedPerson = TextEditingController();
  final _observedPosition = TextEditingController();
  final _otherBehavior = TextEditingController();
  final _potentialConsequence = TextEditingController();
  final _coachingNotes = TextEditingController();
  final _commitment = TextEditingController();
  final _otherAction = TextEditingController();

  int _step = 0;
  int? _companyId;
  String _observationType = 'Observasi Rutin';
  DateTime _observedAt = DateTime.now();
  String? _category;
  int? _categoryId;
  int? _topicId;
  String? _topicName;
  List<Map<String, dynamic>> _mbsCategories = [];
  List<Map<String, dynamic>> _mbsTopics = [];
  List<Map<String, dynamic>> _mbsBehaviorItems = [];
  List<Map<String, dynamic>> _mbsCompanies = [];
  List<Map<String, dynamic>> _workerResults = [];
  List<String> _mbsAreas = [];
  List<String> _mbsBenchmarks = [];
  String? _area;
  String? _benchmark;
  bool _benchmarkLoading = false;
  bool _benchmarkLoadFailed = false;
  bool _masterLoading = false;
  bool _workerSearching = false;
  final Set<String> _behaviors = {};
  // MBS stores the assessment on every selected behaviour, not only on the
  // observation as a whole.  Keep that choice locally by behaviour text.
  final Map<String, String> _behaviorStatuses = {};
  String _classification = 'Perilaku Aman';
  String _roadCondition = 'Normal / Kering';
  final String _weatherCondition = 'Cerah';
  String _trafficCondition = 'Sedang';
  final Set<String> _triggerFactors = {};
  String _riskLevel = 'Rendah';
  final Set<String> _immediateActions = {};
  String _workerResponse = 'Positif';
  DateTime? _dueDate;
  final List<String> _evidencePaths = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _companyId = _profile?.companyId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fillGpsCoordinate(
        context,
        _coordinate,
        () => setState(() {}),
        silent: true,
      );
      _loadMbsCategories();
      _loadMbsCompanies();
      _loadMbsAreas();
    });
  }

  Future<void> _loadMbsCompanies() async {
    var companies = await _api.getBbsCompanies();
    if (companies.isEmpty) {
      try {
        final rows = await DatabaseService().rawQuery(
          "SELECT id, name FROM enum_masters WHERE deleted_at IS NULL AND type = 'company' ORDER BY name",
        );
        if (rows.isNotEmpty) {
          companies = rows.map((r) => {'id': r['id'], 'name': r['name']}).toList();
        } else {
          companies = [{'id': 1, 'name': 'PT INDEXIM COALINDO'}];
        }
      } catch (_) {
        companies = [{'id': 1, 'name': 'PT INDEXIM COALINDO'}];
      }
    }
    if (mounted) setState(() => _mbsCompanies = companies);
  }

  Future<void> _loadMbsAreas() async {
    var areas = await _api.getBbsAreas();
    if (areas.isEmpty) {
      try {
        final sqldb = await DatabaseService().database;
        final rows = await sqldb.rawQuery(
          "SELECT DISTINCT area_utama FROM tbl_m_benchmark WHERE area_utama IS NOT NULL AND area_utama != '' ORDER BY area_utama",
        );
        if (rows.isNotEmpty) {
          areas = rows.map((r) => r['area_utama'].toString()).toList();
        } else {
          final locs = await sqldb.rawQuery(
            "SELECT DISTINCT area FROM locations WHERE area IS NOT NULL AND area != '' ORDER BY area",
          );
          if (locs.isNotEmpty) {
            areas = locs.map((r) => r['area'].toString()).toList();
          }
        }
      } catch (_) {}
    }
    if (mounted) setState(() => _mbsAreas = areas);
  }

  Future<void> _selectArea(String? value) async {
    setState(() {
      _area = value;
      _benchmark = null;
      _mbsBenchmarks = [];
      _benchmarkLoading = value != null;
      _benchmarkLoadFailed = false;
    });
    if (value == null) return;
    var benchmarks = await _api.getBbsBenchmarks(value);
    if (benchmarks == null || benchmarks.isEmpty) {
      try {
        final sqldb = await DatabaseService().database;
        final rows = await sqldb.rawQuery(
          "SELECT DISTINCT nama_benchmark FROM tbl_m_benchmark WHERE area_utama = ? AND nama_benchmark IS NOT NULL AND nama_benchmark != '' ORDER BY nama_benchmark",
          [value],
        );
        if (rows.isNotEmpty) {
          benchmarks = rows.map((r) => r['nama_benchmark'].toString()).toList();
        }
      } catch (_) {}
    }
    if (!mounted || _area != value) return;
    setState(() {
      _benchmarkLoading = false;
      _benchmarkLoadFailed = false;
      _mbsBenchmarks = benchmarks ?? [];
    });
  }

  Future<void> _addBenchmark() async {
    final area = _area;
    if (area == null || area.isEmpty) {
      _message('Pilih Area Utama terlebih dahulu.');
      return;
    }
    final controller = TextEditingController();
    var saving = false;
    String? error;
    final created = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tambah Detail Lokasi'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Nama Benchmark',
              helperText: 'Area Utama: $area',
              errorText: error,
              prefixIcon: const Icon(Icons.add_location_alt_outlined),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (controller.text.trim().isEmpty) {
                        setDialogState(() => error = 'Nama benchmark wajib diisi.');
                        return;
                      }
                      setDialogState(() => saving = true);
                      final name = await _api.createBbsBenchmark(
                        areaUtama: area,
                        namaBenchmark: controller.text,
                      );
                      if (!dialogContext.mounted) return;
                      if (name == null) {
                        setDialogState(() {
                          saving = false;
                          error = 'Benchmark gagal disimpan ke MBS. Coba lagi.';
                        });
                        return;
                      }
                      Navigator.pop(dialogContext, name);
                    },
              child: saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    // Route dialog dan keyboard masih menyelesaikan animasi ketika future
    // showDialog selesai. Jangan dispose TextEditingController atau mengganti
    // subtree pada saat itu; keduanya dapat memutus dependensi TextField aktif.
    await WidgetsBinding.instance.endOfFrame;
    controller.dispose();
    if (created == null || !mounted || _area != area) return;
    if (!mounted || _area != area) return;
    final benchmarks = await _api.getBbsBenchmarks(area);
    if (!mounted || _area != area) return;
    setState(() {
      _benchmarkLoading = false;
      _benchmarkLoadFailed = benchmarks == null;
      _mbsBenchmarks = benchmarks ?? [];
      _benchmark = created;
    });
    _message('Benchmark ditambahkan ke master MBS.');
  }

  static final List<Map<String, dynamic>> _defaultBbsCategories = [
    {
      'id': 1,
      'name': 'Mengemudi & Hauling',
      'categoryType': 'Both',
      'behaviorCount': 7,
      'behaviors': [
        {'id': 1, 'name': 'Menggunakan HP saat mengemudi'},
        {'id': 2, 'name': 'Melebihi batas kecepatan rambu jalan tambang'},
        {'id': 3, 'name': 'Tailgating / tidak menjaga jarak aman'},
        {'id': 4, 'name': 'Menyalip di persimpangan / tikungan blind spot'},
        {'id': 5, 'name': 'Fokus penuh pada jalan dan spion'},
        {'id': 6, 'name': 'Mengemudi sesuai batas kecepatan yang ditentukan'},
        {'id': 7, 'name': 'Menggunakan sabuk pengaman (seatbelt) secara benar'},
      ],
    },
    {
      'id': 2,
      'name': 'Interaksi Alat & Manusia',
      'categoryType': 'Both',
      'behaviorCount': 5,
      'behaviors': [
        {'id': 8, 'name': 'Berada di area blind spot alat berat tanpa konfirmasi'},
        {'id': 9, 'name': 'Berjalan di jalur aktif alat berat'},
        {'id': 10, 'name': 'Memastikan kontak radio dua arah sebelum mendekati alat'},
        {'id': 11, 'name': 'Menjaga jarak aman minimal dari unit aktif'},
        {'id': 12, 'name': 'Operator memberi sinyal klakson sebelum bermanuver'},
      ],
    },
    {
      'id': 3,
      'name': 'Area Loading & Dumping',
      'categoryType': 'Both',
      'behaviorCount': 4,
      'behaviors': [
        {'id': 13, 'name': 'Manuver mundur tanpa arahan spotter saat kondisi kritis'},
        {'id': 14, 'name': 'Dumping terlalu dekat dengan tepi crest tanpa tanggul'},
        {'id': 15, 'name': 'Memeriksa kestabilan lantai front sebelum loading'},
        {'id': 16, 'name': 'Tanggul pengaman (safety berm) sesuai standar tinggi roda'},
      ],
    },
    {
      'id': 4,
      'name': 'Perawatan & Maintenance',
      'categoryType': 'Both',
      'behaviorCount': 4,
      'behaviors': [
        {'id': 17, 'name': 'Bekerja tanpa isolasi energi / Lock Out Tag Out (LOTO)'},
        {'id': 18, 'name': 'Bekerja di bawah attachment hidrolik tanpa lock mekanis'},
        {'id': 19, 'name': 'Memasang ganjal ban pada unit yang sedang diservis'},
        {'id': 20, 'name': 'Menggunakan perkakas kerja yang standar dan layak pakai'},
      ],
    },
    {
      'id': 5,
      'name': 'Pekerjaan Berisiko Khusus',
      'categoryType': 'SpecialCase',
      'behaviorCount': 4,
      'behaviors': [
        {'id': 21, 'name': 'Bekerja di ketinggian tanpa full body harness terikat'},
        {'id': 22, 'name': 'Memasuki ruang terbatas tanpa izin gas test & standby man'},
        {'id': 23, 'name': 'Aktivitas lifting & rigging tanpa rigger bersertifikat'},
        {'id': 24, 'name': 'Menggunakan APD khusus sesuai izin kerja berisiko tinggi'},
      ],
    },
    {
      'id': 6,
      'name': 'Faktor Manusia',
      'categoryType': 'Both',
      'behaviorCount': 4,
      'behaviors': [
        {'id': 25, 'name': 'Bekerja dalam kondisi mengantuk / fatigue berat'},
        {'id': 26, 'name': 'Rushing / terburu-buru sehingga mengabaikan SOP'},
        {'id': 27, 'name': 'Fokus dan bugar siap bekerja (Fit to Work)'},
        {'id': 28, 'name': 'Saling mengingatkan keselamatan antar rekan kerja'},
      ],
    },
    {
      'id': 7,
      'name': 'Kepatuhan Prosedur',
      'categoryType': 'Both',
      'behaviorCount': 3,
      'behaviors': [
        {'id': 29, 'name': 'Melakukan P2H unit secara lengkap dan teliti'},
        {'id': 30, 'name': 'Mengoperasikan unit tanpa SIMPER/KIMPER aktif'},
        {'id': 31, 'name': 'Mematuhi rambu-rambu keselamatan jalan tambang'},
      ],
    },
    {
      'id': 8,
      'name': 'Kepemimpinan & Intervensi',
      'categoryType': 'Both',
      'behaviorCount': 3,
      'behaviors': [
        {'id': 32, 'name': 'Melakukan intervensi / Stop Work Authority saat bahaya'},
        {'id': 33, 'name': 'Memberikan apresiasi atas perilaku aman pekerja'},
        {'id': 34, 'name': 'Memberikan briefing keselamatan sebelum pekerjaan dimulai'},
      ],
    },
    {
      'id': 9,
      'name': 'Penggunaan APD',
      'categoryType': 'Rutin',
      'behaviorCount': 4,
      'behaviors': [
        {'id': 35, 'name': 'Helm keselamatan terpasang lengkap dengan tali dagu'},
        {'id': 36, 'name': 'Kacamata keselamatan digunakan saat area berdebu/bunga api'},
        {'id': 37, 'name': 'Sepatu safety standar digunakan dengan baik'},
        {'id': 38, 'name': 'Rompi reflektif terlihat jelas dan bersih'},
      ],
    },
    {
      'id': 10,
      'name': 'Housekeeping & Lingkungan',
      'categoryType': 'Rutin',
      'behaviorCount': 3,
      'behaviors': [
        {'id': 39, 'name': 'Limbah B3 dibuang pada tempat sampah khusus B3'},
        {'id': 40, 'name': 'Area kerja bersih dari ceceran oli/solar/grease'},
        {'id': 41, 'name': 'Penataan peralatan rapi setelah selesai pekerjaan'},
      ],
    },
  ];

  Future<void> _loadMbsCategories() async {
    setState(() => _masterLoading = true);
    final type = _observationType == 'Special Case' ? 'SpecialCase' : 'Rutin';
    var categories = await _api.getBbsCategories(type);
    if (categories.isEmpty) {
      categories = _defaultBbsCategories.where((c) {
        final cType = c['categoryType']?.toString() ?? 'Both';
        return cType == 'Both' || cType == type;
      }).toList();
    }
    if (!mounted) return;
    setState(() { _mbsCategories = categories; _masterLoading = false; });
  }

  Future<void> _selectCategory(String name, {int? id}) async {
    setState(() {
      _category = name;
      _categoryId = id;
      _topicId = null;
      _topicName = null;
      _mbsTopics = [];
      _behaviors.clear();
      _behaviorStatuses.clear();
      _mbsBehaviorItems = [];
      _masterLoading = id != null;
    });
    if (id == null) return;
    final results = await Future.wait([
      _api.getBbsTopics(id),
      _api.getBbsBehaviors(id),
    ]);
    if (!mounted) return;
    var behaviorItems = results[1];
    if (behaviorItems.isEmpty) {
      final defaultCat = _defaultBbsCategories.where((c) => c['id'] == id || c['name'] == name).firstOrNull;
      if (defaultCat != null) {
        final list = (defaultCat['behaviors'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        behaviorItems = list;
      }
    }
    setState(() {
      _mbsTopics = results[0];
      _mbsBehaviorItems = behaviorItems;
      _masterLoading = false;
    });
  }

  Future<void> _selectTopic(int? id, String? name) async {
    setState(() {
      _topicId = id;
      _topicName = name;
      _behaviors.clear();
      _behaviorStatuses.clear();
      _mbsBehaviorItems = [];
      _masterLoading = id != null;
    });
    if (id == null || _categoryId == null) return;
    final behaviors = await _api.getBbsBehaviors(_categoryId!, topicId: id);
    if (mounted) {
      setState(() {
        _mbsBehaviorItems = behaviors;
        _masterLoading = false;
      });
    }
  }

  Future<void> _searchWorker(String value) async {
    if (value.trim().length < 2) {
      if (mounted) setState(() => _workerResults = []);
      return;
    }
    setState(() => _workerSearching = true);
    var results = await _api.searchBbsWorkers(value, companyId: _companyId);
    if (results.isEmpty) {
      try {
        final q = '%${value.trim()}%';
        final rows = await DatabaseService().rawQuery(
          '''
          SELECT id, nik, nama_lengkap as nama, posisi as jabatan, departemen, perusahaan
          FROM employees
          WHERE (nama_lengkap LIKE ? OR nik LIKE ? OR no_nik LIKE ?)
          LIMIT 20
          ''',
          [q, q, q],
        );
        results = rows.map((r) => Map<String, dynamic>.from(r)).toList();
      } catch (_) {}
    }
    if (!mounted || _observedPerson.text.trim() != value.trim()) return;
    setState(() {
      _workerResults = results;
      _workerSearching = false;
    });
  }

  void _selectWorker(Map<String, dynamic> worker) {
    setState(() {
      _observedNik.text = worker['nik']?.toString() ?? '';
      _observedPerson.text = worker['nama']?.toString() ?? '';
      _observedPosition.text = worker['jabatan']?.toString() ?? '';
      _department.text = worker['departemen']?.toString() ?? '';
      _workerResults = [];
    });
  }

  @override
  void dispose() {
    _coordinate.dispose();
    _department.dispose();
    _observedNik.dispose();
    _observedPerson.dispose();
    _observedPosition.dispose();
    _otherBehavior.dispose();
    _potentialConsequence.dispose();
    _coachingNotes.dispose();
    _commitment.dispose();
    _otherAction.dispose();
    super.dispose();
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  bool _validateStep() {
    if (_step == 0 &&
        (_companyId == null ||
            _area == null ||
            _observedNik.text.trim().isEmpty ||
            _department.text.trim().isEmpty ||
            _observedPerson.text.trim().isEmpty)) {
      _message(
          'Pilih perusahaan, area utama, lalu pekerja dari hasil pencarian MBS.');
      return false;
    }
    if (_step == 1 && (_category == null || _behaviors.isEmpty)) {
      _message('Pilih kategori dan minimal satu perilaku yang diamati.');
      return false;
    }
    if (_step == 3 &&
        (_potentialConsequence.text.trim().isEmpty ||
            _immediateActions.isEmpty ||
            _coachingNotes.text.trim().isEmpty ||
            _commitment.text.trim().isEmpty)) {
      _message('Lengkapi risiko, tindakan, catatan coaching, dan komitmen.');
      return false;
    }
    return true;
  }

  Future<void> _next() async {
    if (!_validateStep()) return;
    if (_step < _stepTitles.length - 1) {
      setState(() => _step++);
      return;
    }
    await _save();
  }

  Future<void> _save() async {
    if (_saving) return;
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
    if (_categoryId == null) {
      setState(() => _saving = false);
      _message('Kategori BBS harus dipilih dari master MBS.');
      return;
    }
    final behaviorEntries = behaviors.map((text) {
      final master = _mbsBehaviorItems.where((item) => item['behaviorText']?.toString() == text);
      return jsonEncode({'id': master.isEmpty ? 0 : master.first['id'], 'text': text, 'status': _behaviorStatuses[text] ?? 'Aman'});
    }).toList();
    final selectedCompany = _mbsCompanies.where(
      (company) => int.tryParse((company['Id'] ?? company['id']).toString()) == _companyId,
    );
    final companyName = selectedCompany.isEmpty
        ? (_profile?.company ?? '')
        : (selectedCompany.first['Nama'] ?? selectedCompany.first['nama'] ?? '').toString();
    final form = <String, dynamic>{
      'Id': '0', 'ObservationType': _observationType == 'Special Case' ? 'SpecialCase' : 'Rutin',
      'Tanggal': DateFormat('yyyy-MM-dd').format(_observedAt), 'waktuStr': DateFormat('HH:mm').format(_observedAt),
      'Area': _area!, 'DetilLokasi': _benchmark ?? '', 'Site': _coordinate.text.trim(),
      'ObservedNik': _observedNik.text.trim(), 'ObservedNama': _observedPerson.text.trim(), 'ObservedJabatan': _observedPosition.text.trim(), 'ObservedDept': _department.text.trim(),
      'ObservedPerusahaanId': _companyId?.toString() ?? '', 'ObservedPerusahaan': companyName,
      'CategoryId': _categoryId.toString(), 'CategoryName': _category!, if (_topicId != null) 'TopicId': _topicId.toString(), if (_topicName != null) 'TopicName': _topicName!, 'Klasifikasi': _classification == 'Perilaku Aman' ? 'Aman' : 'Berisiko',
      'TingkatRisiko': _riskLevel, 'KondisiJalan': _roadCondition, 'KondisiKerja': _trafficCondition,
      'Deskripsi': _potentialConsequence.text.trim(), 'ResponsPekerja': _workerResponse, 'CatatanCoaching': '${_coachingNotes.text.trim()}\n${_commitment.text.trim()}'.trim(),
      for (var i = 0; i < behaviorEntries.length; i++) 'selectedBehaviors[$i]': behaviorEntries[i],
      'triggers': _triggerFactors.toList(),
      'actions': actions,
    };
    final localId = 'BBS-${DateFormat('yyyyMMdd-HHmmss').format(DateTime.now())}';
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
          .whereType<String>()
          .where((part) => part.isNotEmpty)
          .join(' • '),
      department: _department.text.trim(),
      observedPerson: _observedPerson.text.trim(),
      observedPosition: _observedPosition.text.trim(),
      observedAt: _observedAt,
      category: _category!,
      behaviors: behaviors,
      classification: _classification,
      roadCondition: _roadCondition,
      weatherCondition: _weatherCondition,
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
    if (!synced) {
      _message(
        online
            ? 'Laporan disimpan di perangkat dan akan dicoba sinkron kembali otomatis.'
            : 'Mode offline: laporan disimpan dan akan tersinkron otomatis saat internet kembali.',
      );
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => BbsDetailPage(observation)),
    );
  }

  Future<void> _pickObservedAt() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _observedAt,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_observedAt),
    );
    if (time == null) return;
    setState(() {
      _observedAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _pickDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) setState(() => _dueDate = date);
  }

  Future<void> _pickEvidence() async {
    if (_evidencePaths.isNotEmpty) {
      _message('BBS MBS hanya menerima satu foto untuk setiap observasi.');
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Ambil Foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Pilih dari Galeri'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picker = ImagePicker();
    if (source == ImageSource.camera) {
      final image = await picker.pickImage(
        source: source,
        imageQuality: 78,
        maxWidth: 1600,
      );
      if (image != null) setState(() => _evidencePaths.add(image.path));
      return;
    }
    final images = await picker.pickMultiImage(
      imageQuality: 78,
      maxWidth: 1600,
    );
    if (images.isEmpty) return;
    setState(() => _evidencePaths.add(images.first.path));
    if (images.length > 1 && mounted) {
      _message('Hanya satu foto pertama yang digunakan untuk laporan BBS.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: const TopBar(title: 'Buat Observasi BBS', back: 2),
      body: Column(
        children: [
          _ProgressHeader(step: _step, titles: _stepTitles),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: SingleChildScrollView(
                key: ValueKey(_step),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                child: _buildStep(),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: FilledButton.icon(
            onPressed: _saving ? null : _next,
            style: FilledButton.styleFrom(
              backgroundColor: _blue,
              minimumSize: const Size.fromHeight(50),
            ),
            icon: Icon(
              _step == _stepTitles.length - 1
                  ? Icons.save_rounded
                  : Icons.arrow_forward_rounded,
            ),
            label: Text(
              _saving
                  ? 'Menyimpan...'
                  : _step == _stepTitles.length - 1
                      ? 'Simpan Observasi'
                      : 'Lanjut',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    return switch (_step) {
      0 => _informationStep(),
      1 => _behaviorStep(),
      2 => _classificationStep(),
      3 => _actionStep(),
      _ => _reviewStep(),
    };
  }

  Widget _informationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLead(
          icon: Icons.assignment_outlined,
          title: 'Jenis & Lokasi Observasi',
          subtitle: 'Catat konteks observasi secara lengkap dan objektif.',
        ),
        const _FieldLabel('Jenis Observasi'),
        Row(
          children: [
            Expanded(
              child: _SelectCard(
                title: 'Observasi Rutin',
                subtitle: 'Aktivitas sehari-hari',
                icon: Icons.visibility_outlined,
                selected: _observationType == 'Observasi Rutin',
                onTap: () { setState(() => _observationType = 'Observasi Rutin'); _loadMbsCategories(); },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SelectCard(
                title: 'Special Case',
                subtitle: 'Risiko tinggi/spesifik',
                icon: Icons.crisis_alert_rounded,
                selected: _observationType == 'Special Case',
                onTap: () { setState(() => _observationType = 'Special Case'); _loadMbsCategories(); },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _FieldLabel('Perusahaan / Kontraktor Pekerja'),
        _MasterPickerField(
          icon: Icons.apartment_rounded,
          value: _mbsCompanies
              .where((c) => int.tryParse((c['Id'] ?? c['id']).toString()) == _companyId)
              .map((c) => (c['Nama'] ?? c['nama']).toString())
              .cast<String?>()
              .firstOrNull,
          hint: _mbsCompanies.isEmpty ? 'Memuat daftar perusahaan MBS...' : 'Pilih perusahaan / kontraktor',
          enabled: _mbsCompanies.isNotEmpty,
          onTap: () async {
            final names = _mbsCompanies.map((c) => (c['Nama'] ?? c['nama']).toString()).toList();
            final picked = await _showMasterSearch(context, 'Pilih Perusahaan / Kontraktor', names);
            if (picked == null || !mounted) return;
            final company = _mbsCompanies.firstWhere((c) => (c['Nama'] ?? c['nama']).toString() == picked);
            setState(() {
              _companyId = int.tryParse((company['Id'] ?? company['id']).toString());
              _observedNik.clear(); _observedPerson.clear(); _observedPosition.clear(); _department.clear(); _workerResults = [];
            });
          },
        ),
        const SizedBox(height: 14),
        const _FieldLabel('Area Utama'),
        Autocomplete<String>(
          // Autocomplete menyimpan TextEditingController internal. Key harus
          // ikut nilai terpilih agar teks hasil dari panel pencarian tampil
          // kembali setelah bottom sheet ditutup.
          key: ValueKey('bbs-area-$_area'),
          initialValue: TextEditingValue(text: _area ?? ''),
          displayStringForOption: (value) => value,
          optionsBuilder: (value) {
            final keyword = value.text.trim().toLowerCase();
            return _mbsAreas.where(
              (item) => keyword.isEmpty || item.toLowerCase().contains(keyword),
            );
          },
          onSelected: _selectArea,
          fieldViewBuilder: (context, controller, focusNode, submit) => TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: _mbsAreas.isNotEmpty,
            readOnly: true,
            onTap: () async {
              final picked = await _showMasterSearch(context, 'Pilih Area Utama', _mbsAreas);
              if (picked != null && mounted) _selectArea(picked);
            },
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.map_rounded),
              hintText: _mbsAreas.isEmpty
                  ? 'Memuat Area Utama dari MBS...'
                  : 'Pilih Area Utama',
              suffixIcon: IconButton(
                tooltip: 'Tampilkan Area Utama MBS',
                onPressed: _mbsAreas.isEmpty ? null : () async {
                  final picked = await _showMasterSearch(context, 'Pilih Area Utama', _mbsAreas);
                  if (picked != null && mounted) _selectArea(picked);
                },
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
              ),
            ),
          ),
          optionsViewBuilder: (context, onSelected, options) => Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240, minWidth: 280),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options.elementAt(index);
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.location_on_outlined, color: _blue),
                      title: Text(option),
                      onTap: () => onSelected(option),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const _FieldLabel('Detail Lokasi / Benchmark'),
        Row(
          children: [
            Expanded(
              child: _area == null
                  ? const TextField(
                      enabled: false,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.explore_rounded),
                        hintText: 'Pilih Area Utama terlebih dahulu',
                      ),
                    )
                  : _benchmarkLoading
                      ? const TextField(
                          enabled: false,
                          decoration: InputDecoration(
                            prefixIcon: Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                            hintText: 'Memuat benchmark dari MBS...',
                          ),
                        )
                      : Autocomplete<String>(
                      key: ValueKey('bbs-benchmark-$_area-$_benchmark'),
                      initialValue: TextEditingValue(text: _benchmark ?? ''),
                      displayStringForOption: (value) => value,
                      optionsBuilder: (value) {
                        final keyword = value.text.trim().toLowerCase();
                        return _mbsBenchmarks.where(
                          (item) => keyword.isEmpty || item.toLowerCase().contains(keyword),
                        );
                      },
                      onSelected: (value) => setState(() => _benchmark = value),
                      fieldViewBuilder: (context, controller, focusNode, submit) => TextField(
                        controller: controller,
                        focusNode: focusNode,
                        readOnly: true,
                        onTap: () async {
                          final picked = await _showMasterSearch(context, 'Pilih Detail Lokasi / Benchmark', _mbsBenchmarks);
                          if (picked != null && mounted) setState(() => _benchmark = picked);
                        },
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.explore_rounded),
                          hintText: _benchmarkLoadFailed
                              ? 'Benchmark MBS belum dapat dimuat'
                              : _mbsBenchmarks.isEmpty
                              ? 'Belum ada benchmark — tekan +'
                              : 'Pilih benchmark MBS',
                          suffixIcon: IconButton(
                            tooltip: 'Tampilkan benchmark MBS',
                            onPressed: _benchmarkLoadFailed
                                ? () => _selectArea(_area)
                                : () async {
                                    final picked = await _showMasterSearch(context, 'Pilih Detail Lokasi / Benchmark', _mbsBenchmarks);
                                    if (picked != null && mounted) setState(() => _benchmark = picked);
                                  },
                            icon: Icon(_benchmarkLoadFailed
                                ? Icons.refresh_rounded
                                : Icons.arrow_drop_down_rounded),
                          ),
                        ),
                      ),
                      optionsViewBuilder: (context, onSelected, options) => Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 6,
                          borderRadius: BorderRadius.circular(12),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 240, minWidth: 280),
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final option = options.elementAt(index);
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.location_on_outlined, color: _blue),
                                  title: Text(option),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: _area == null ? 'Pilih Area Utama terlebih dahulu' : 'Tambah benchmark baru',
              child: SizedBox(
                width: 50,
                height: 50,
                child: FilledButton(
                  onPressed: _area == null || _benchmarkLoading ? null : _addBenchmark,
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: _blue,
                  ),
                  child: const Icon(Icons.add_location_alt_rounded, semanticLabel: 'Tambah benchmark'),
                ),
              ),
            ),
          ],
        ),
        if (_area != null && _benchmarkLoadFailed)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Benchmark dari MBS belum dapat dimuat. Tekan ikon muat ulang untuk mencoba lagi.',
              style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
            ),
          )
        else if (_area != null && !_benchmarkLoading && _mbsBenchmarks.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Belum ada detail lokasi untuk area ini di master MBS. Tekan + untuk menambahkannya.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
        const SizedBox(height: 14),
        const _FieldLabel('Koordinat GPS'),
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
            iconColor: _blue,
          ).copyWith(hintText: 'Diambil otomatis dari perangkat'),
        ),
        const SizedBox(height: 14),
        const _FieldLabel('Unit / Departemen'),
        TextField(
          controller: _department,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Contoh: Produksi - Hauling',
            prefixIcon: Icon(Icons.apartment_rounded),
          ),
        ),
        const SizedBox(height: 14),
        const _FieldLabel('Pekerja yang Diamati'),
        TextField(
          controller: _observedPerson,
          textCapitalization: TextCapitalization.words,
          onChanged: _searchWorker,
          decoration: InputDecoration(
            hintText: _companyId == null
                ? 'Pilih perusahaan terlebih dahulu'
                : 'Ketik minimal 2 huruf nama atau NIK',
            prefixIcon: const Icon(Icons.person_search_rounded),
            suffixIcon: _workerSearching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : null,
          ),
        ),
        if (_workerResults.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxHeight: 210),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _workerResults.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final worker = _workerResults[index];
                final name = worker['nama']?.toString() ?? '-';
                final nik = worker['nik']?.toString() ?? '-';
                final role = worker['jabatan']?.toString() ?? '';
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.badge_outlined, color: _blue),
                  title: Text(name),
                  subtitle: Text([nik, role].where((text) => text.isNotEmpty).join(' • ')),
                  onTap: () => _selectWorker(worker),
                );
              },
            ),
          ),
        ],
        if (_observedNik.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Terpilih dari MBS: NIK ${_observedNik.text}', style: const TextStyle(color: _green, fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: 14),
        const _FieldLabel('Jabatan / Peran (opsional)'),
        TextField(
          controller: _observedPosition,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Contoh: Driver DT, Mekanik',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
        ),
        const SizedBox(height: 14),
        const _FieldLabel('Tanggal & Waktu'),
        _ReadOnlyField(
          icon: Icons.calendar_month_rounded,
          value: DateFormat('dd MMMM yyyy, HH:mm').format(_observedAt),
          onTap: _pickObservedAt,
        ),
      ],
    );
  }

  Widget _behaviorStep() {
    final behaviors = _mbsBehaviorItems
        .map((item) => item['behaviorText'].toString())
        .where((item) => item.isNotEmpty)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLead(
          icon: Icons.rule_folder_outlined,
          title: 'Pilih Kategori Perilaku',
          subtitle:
              'Pilih kategori lalu tandai seluruh perilaku yang terlihat.',
        ),
        if (_masterLoading) const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
        else if (_mbsCategories.isNotEmpty)
          ..._mbsCategories.map((item) => _CategoryTile(title: item['name'].toString(), count: int.tryParse(item['behaviorCount'].toString()) ?? 0, selected: _category == item['name'], icon: Icons.category_rounded, onTap: () => _selectCategory(item['name'].toString(), id: int.tryParse(item['id'].toString()))))
        else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Text('Master kategori BBS belum dapat dimuat dari MBS. Tarik ulang saat koneksi tersedia.', style: TextStyle(color: Colors.black54)),
          ),
        if (_category != null) ...[
          if (_mbsTopics.isNotEmpty) ...[
            const SizedBox(height: 16),
            const _FieldLabel('Topik Perilaku'),
            DropdownButtonFormField<int>(
              initialValue: _topicId,
              isExpanded: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.topic_outlined),
                hintText: 'Pilih topik dari master MBS',
              ),
              items: _mbsTopics.map((topic) => DropdownMenuItem<int>(
                value: int.tryParse(topic['id'].toString()),
                child: Text((topic['name'] ?? topic['topicName'] ?? '').toString(), overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: (id) {
                final selected = _mbsTopics.where((topic) => int.tryParse(topic['id'].toString()) == id);
                _selectTopic(id, selected.isEmpty ? null : (selected.first['name'] ?? selected.first['topicName'])?.toString());
              },
            ),
          ],
          const SizedBox(height: 18),
          _SectionLead(
            icon: Icons.checklist_rounded,
            title: _category!,
            subtitle: 'Anda dapat memilih lebih dari satu perilaku.',
          ),
          if (behaviors.isEmpty && !_masterLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Butir perilaku belum tersedia dari master MBS untuk pilihan ini.', style: TextStyle(color: Colors.black54)),
            ),
          ...behaviors.map((behavior) {
            final selected = _behaviors.contains(behavior);
            final status = _behaviorStatuses[behavior] ?? 'Aman';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFF8FAFC) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                children: [
                  CheckboxListTile(
                    value: selected,
                    onChanged: (value) => setState(() {
                      if (value == true) {
                        _behaviors.add(behavior);
                        _behaviorStatuses.putIfAbsent(behavior, () => 'Aman');
                      } else {
                        _behaviors.remove(behavior);
                        _behaviorStatuses.remove(behavior);
                      }
                    }),
                    title: Text(behavior, style: const TextStyle(fontSize: 13)),
                    activeColor: _blue,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                    dense: true,
                  ),
                  if (selected)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'Aman', label: Text('Aman')),
                          ButtonSegment(value: 'Berisiko', label: Text('Berisiko')),
                        ],
                        selected: {status},
                        onSelectionChanged: (value) => setState(() {
                          _behaviorStatuses[behavior] = value.first;
                          _classification = _behaviorStatuses.values
                                  .any((item) => item == 'Berisiko')
                              ? 'Perilaku Berisiko'
                              : 'Perilaku Aman';
                        }),
                        showSelectedIcon: false,
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          TextField(
            controller: _otherBehavior,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Perilaku lain (opsional)',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ],
    );
  }

  Widget _classificationStep() {
    const triggers = [
      'Terburu-buru / Mengejar target',
      'Kebiasaan',
      'Kurang kesadaran',
      'Pengawasan kurang',
      'Kelelahan (Fatigue)',
      'Kondisi jalan / lingkungan',
      'Cuaca / Visibilitas',
      'Lainnya',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLead(
          icon: Icons.psychology_alt_outlined,
          title: 'Klasifikasi & Konteks',
          subtitle: 'Nilai perilaku berdasarkan apa yang benar-benar diamati.',
        ),
        Row(
          children: [
            Expanded(
              child: _SelectCard(
                title: 'Perilaku Aman',
                subtitle: 'Safe behavior',
                icon: Icons.thumb_up_alt_rounded,
                selected: _classification == 'Perilaku Aman',
                selectedColor: _green,
                onTap: () => setState(() => _classification = 'Perilaku Aman'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SelectCard(
                title: 'Perilaku Berisiko',
                subtitle: 'At-risk behavior',
                icon: Icons.thumb_down_alt_rounded,
                selected: _classification == 'Perilaku Berisiko',
                selectedColor: const Color(0xFFDC2626),
                onTap: () =>
                    setState(() => _classification = 'Perilaku Berisiko'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const _FieldLabel('Kondisi Jalan / Area'),
        _Dropdown(
          value: _roadCondition,
          items: const [
            'Normal / Kering',
            'Basah / Licin',
            'Berdebu / Kabut',
            'Bergelombang / Rusak',
          ],
          onChanged: (value) => setState(() => _roadCondition = value),
        ),
        const _FieldLabel('Kepadatan Aktivitas / Traffic'),
        _Dropdown(
          value: _trafficCondition,
          items: const ['Lancar', 'Sedang', 'Padat / Ramai'],
          onChanged: (value) => setState(() => _trafficCondition = value),
        ),
        const SizedBox(height: 18),
        const _FieldLabel('Faktor Pemicu / Penyebab'),
        const Text(
          'Pilih satu atau lebih faktor yang paling berpengaruh.',
          style: TextStyle(color: Colors.black54, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: triggers
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: FilterChip(
                    label: Align(
                        alignment: Alignment.centerLeft,
                        child:
                            Text(item, style: const TextStyle(fontSize: 11))),
                    selected: _triggerFactors.contains(item),
                    selectedColor: const Color(0xFFDDF2FF),
                    checkmarkColor: _blue,
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _triggerFactors.add(item);
                      } else {
                        _triggerFactors.remove(item);
                      }
                    }),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _actionStep() {
    const actions = [
      'Memberikan apresiasi atas perilaku aman',
      'Melakukan diskusi / coaching singkat di lokasi',
      'Memberikan teguran lisan secara persuasif',
      'Menghentikan aktivitas / unit sementara (Stop Work)',
      'Melaporkan ke pengawas / supervisor',
      'Eskalasi ke tim Safety / HSE',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLead(
          icon: Icons.health_and_safety_outlined,
          title: 'Risiko, Tindakan & Coaching',
          subtitle:
              'Tentukan dampak dan catat dialog perbaikan bersama pekerja.',
        ),
        const _FieldLabel('Level Risiko / Dampak Potensial'),
        ...[
          ('Sangat Tinggi', 'Fatality / cidera berat', const Color(0xFFDC2626)),
          (
            'Tinggi',
            'Cidera sedang / kerusakan besar',
            const Color(0xFFF97316)
          ),
          ('Sedang', 'Cidera ringan / kerusakan alat', const Color(0xFFEAB308)),
          ('Rendah', 'Hampir tidak ada dampak', _green),
        ].map(
          (item) => _RiskOption(
            title: item.$1,
            subtitle: item.$2,
            color: item.$3,
            selected: _riskLevel == item.$1,
            onTap: () => setState(() => _riskLevel = item.$1),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _potentialConsequence,
          minLines: 3,
          maxLines: 5,
          maxLength: 300,
          decoration: const InputDecoration(
            labelText: 'Jelaskan risiko / konsekuensi potensial',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        const _FieldLabel('Tindakan Langsung'),
        ...actions.map(
          (action) => CheckboxListTile(
            value: _immediateActions.contains(action),
            onChanged: (selected) => setState(() {
              if (selected == true) {
                _immediateActions.add(action);
              } else {
                _immediateActions.remove(action);
              }
            }),
            title: Text(action, style: const TextStyle(fontSize: 13)),
            activeColor: _blue,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        TextField(
          controller: _otherAction,
          decoration:
              const InputDecoration(labelText: 'Tindakan lain (opsional)'),
        ),
        const SizedBox(height: 16),
        const _FieldLabel('Respons Pekerja'),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
                value: 'Positif',
                label: Text('Positif'),
                icon: Icon(Icons.sentiment_satisfied_alt_rounded)),
            ButtonSegment(
                value: 'Netral',
                label: Text('Netral'),
                icon: Icon(Icons.sentiment_neutral_rounded)),
            ButtonSegment(
                value: 'Resisten',
                label: Text('Resisten'),
                icon: Icon(Icons.sentiment_dissatisfied_rounded)),
          ],
          selected: {_workerResponse},
          onSelectionChanged: (value) =>
              setState(() => _workerResponse = value.first),
          showSelectedIcon: false,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _coachingNotes,
          minLines: 3,
          maxLines: 5,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Catatan coaching',
            hintText:
                'Tuliskan percakapan, pemahaman pekerja, dan pesan keselamatan.',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _commitment,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Komitmen / tindakan perbaikan',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 14),
        const _FieldLabel('Target Follow Up (opsional)'),
        _ReadOnlyField(
          icon: Icons.event_available_rounded,
          value: _dueDate == null
              ? 'Pilih tanggal target'
              : DateFormat('dd MMMM yyyy').format(_dueDate!),
          onTap: _pickDueDate,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(child: _FieldLabel('Bukti Foto (opsional)')),
            Text(
              '${_evidencePaths.length}/1 foto',
              style: const TextStyle(
                color: _blue,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount:
              _evidencePaths.length + (_evidencePaths.isEmpty ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _evidencePaths.length) {
              return Material(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: _pickEvidence,
                  borderRadius: BorderRadius.circular(14),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_rounded, color: _blue),
                      SizedBox(height: 6),
                      Text(
                        'Tambah Foto',
                        style: TextStyle(
                          color: _blue,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            final path = _evidencePaths[index];
            return Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(File(path), fit: BoxFit.cover),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton.filled(
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: .65),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () =>
                        setState(() => _evidencePaths.removeAt(index)),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _reviewStep() {
    final selectedBehaviors = [..._behaviors];
    if (_otherBehavior.text.trim().isNotEmpty) {
      selectedBehaviors.add(_otherBehavior.text.trim());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFA7F3D0)),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: _green, size: 34),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Siap Disimpan',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 16)),
                    Text('Periksa kembali data sebelum menyimpan observasi.',
                        style:
                            TextStyle(color: Color(0xFF047857), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _ReviewCard(
          title: 'Ringkasan Observasi',
          items: {
            'Jenis': _observationType,
            'Area / Benchmark': [_area, _benchmark].whereType<String>().where((value) => value.isNotEmpty).join(' • '),
            'Koordinat GPS': _coordinate.text.trim(),
            'Departemen': _department.text.trim(),
            'Pekerja': '${_observedPerson.text.trim()} (${_observedNik.text.trim()})',
            'Waktu': DateFormat('dd MMM yyyy, HH:mm').format(_observedAt),
          },
        ),
        _ReviewCard(
          title: 'Perilaku & Risiko',
          items: {
            'Kategori': _category ?? '-',
            'Perilaku': selectedBehaviors.join(', '),
            'Klasifikasi': _classification,
            'Risiko': _riskLevel,
            'Pemicu':
                _triggerFactors.isEmpty ? '-' : _triggerFactors.join(', '),
          },
        ),
        _ReviewCard(
          title: 'Tindakan & Komitmen',
          items: {
            'Tindakan': _immediateActions.join(', '),
            'Respons': _workerResponse,
            'Coaching': _coachingNotes.text.trim(),
            'Komitmen': _commitment.text.trim(),
            'Target': _dueDate == null
                ? '-'
                : DateFormat('dd MMM yyyy').format(_dueDate!),
            'Bukti Foto': '${_evidencePaths.length} foto',
          },
        ),
      ],
    );
  }

}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.step, required this.titles});

  final int step;
  final List<String> titles;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Langkah ${step + 1} dari ${titles.length}',
                style: const TextStyle(
                    color: _blue, fontSize: 11, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text('${((step + 1) / titles.length * 100).round()}%',
                  style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (step + 1) / titles.length,
              minHeight: 7,
              backgroundColor: const Color(0xFFE2E8F0),
              color: _blue,
            ),
          ),
          const SizedBox(height: 8),
          Text(titles[step],
              style:
                  const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
        ],
      ),
    );
  }
}

class _SectionLead extends StatelessWidget {
  const _SectionLead(
      {required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
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
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDCFCE7)),
            ),
            child: Icon(icon, color: _blue, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SelectCard extends StatelessWidget {
  const _SelectCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.selectedColor = _blue,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? selectedColor.withValues(alpha: .08) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: selected ? selectedColor : const Color(0xFFE2E8F0),
                width: selected ? 2 : 1),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: selected ? selectedColor : Colors.blueGrey, size: 28),
              const SizedBox(height: 8),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 12)),
              const SizedBox(height: 3),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54, fontSize: 9)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile(
      {required this.title,
      required this.count,
      required this.selected,
      required this.icon,
      required this.onTap});

  final String title;
  final int count;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? const Color(0xFFE0F2FE) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border:
                  Border.all(color: selected ? _blue : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFF1D6),
                      borderRadius: BorderRadius.circular(11)),
                  child: Icon(icon, color: const Color(0xFFB45309), size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 13)),
                      Text('$count item perilaku',
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 10)),
                    ],
                  ),
                ),
                Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.chevron_right_rounded,
                    color: selected ? _blue : Colors.blueGrey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown(
      {required this.value, required this.items, required this.onChanged});

  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: (value) => onChanged(value!),
    );
  }
}

class _RiskOption extends StatelessWidget {
  const _RiskOption({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? color.withValues(alpha: .08) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? color : const Color(0xFFE2E8F0),
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField(
      {required this.icon, required this.value, required this.onTap});

  final IconData icon;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.indigo.shade200)),
          child: Row(
            children: [
              Icon(icon, color: _blue),
              const SizedBox(width: 12),
              Expanded(child: Text(value)),
              const Icon(Icons.chevron_right_rounded, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.title, required this.items});

  final String title;
  final Map<String, String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const Divider(height: 24),
          ...items.entries.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                      width: 90,
                      child: Text(item.key,
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 11))),
                  Expanded(
                      child: Text(item.value.isEmpty ? '-' : item.value,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 11))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

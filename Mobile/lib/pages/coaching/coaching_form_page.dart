import 'dart:io';

import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../models/coaching_tran_model.dart';
import '../../models/coaching_detail_model.dart';
import '../../services/api.dart';
import '../../services/database.dart';
import '../../services/preference.dart';
import '../../services/sync.dart';
import '../../utils/helpers.dart';
import '../../widgets/snackbar_msg.dart';
import '../../widgets/sap_form_widgets.dart';
import '../../widgets/top_bar.dart';
import '../../widgets/upload_files.dart';

class CoachingFormPage extends StatefulWidget {
  const CoachingFormPage({super.key});

  @override
  State<CoachingFormPage> createState() => _CoachingFormPageState();
}

class _CoachingFormPageState extends State<CoachingFormPage> {
  final _scrollCtrl = ScrollController();
  final _db = DatabaseService();
  final _api = ApiService();
  final _profile = PreferenceService.getProfile();
  final _locationDetail = TextEditingController();
  final _title = TextEditingController();
  final _feedback = TextEditingController();
  final _traineeQuery = TextEditingController();
  final List<dynamic> _rawData = [];
  final List<MapEntry<int, dynamic>> _temaList = [];
  final List<MapEntry<int, dynamic>> _companyList = [];
  // final List<MapEntry<int, dynamic>> _temaList = [
  //   const MapEntry(1, 'Sosialisasi'),
  //   const MapEntry(2, 'Sharing Knowledge'),
  //   const MapEntry(3, 'Pembinaan'),
  // ];
  final List<MapEntry<int, dynamic>> _areaList = [];
  List<MapEntry<int, dynamic>> _locationList = [];
  DateTime? _date = DateTime.now();
  String? _time = DateFormat('hh:mm').format(DateTime.now());
  int? _temaId;
  int? _companyId;
  int? _areaId;
  int? _locationId;
  String? _image;
  final List<Map<String, dynamic>> _traineeResults = [];
  final List<Map<String, dynamic>> _selectedTrainees = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _companyId = _profile?.companyId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fillGpsFromDevice(silent: true);
      _db.rawQuery('''select
        me.id id_area,
        me."name" area,
        me2.id id_lokasi,
        me2."name" lokasi
      from enum_masters me
        left join enum_masters me2 on me2.ref_id=me.id and me2.deleted_at is null
      where me.deleted_at is null and me."type" = 'area' and me."name" not like 'Inspeksi%' and me."name" not like 'Area%'
      order by me."name",me2."name"''').then((val) {
        if (val.isNotEmpty) {
          setState(() {
            _rawData.addAll(val.toList());
            _areaList.addAll({
              for (var row in val.toList()) row['id_area'] as int: row['area']
            }.entries.toList());
            _areaList.sort((a, b) => (a.value).compareTo(b.value));
          });
        }
      });

      _loadCoachingOptionsFromMbs();

      _db.rawQuery('''select id, "name"
        from enum_masters
        where deleted_at is null and type = 'company'
        order by "name"''').then((rows) {
        if (!mounted || rows.isEmpty) return;
        setState(() {
          _companyList
            ..clear()
            ..addAll(rows
                .where((row) => row['id'] != null && row['name'] != null)
                .map((row) => MapEntry<int, dynamic>(
                    row['id'] as int, row['name'].toString())));
          if (!_companyList.any((item) => item.key == _companyId)) {
            _companyId = null;
          }
        });
      });

      _db.rawQuery('''select
        id id_tema,
        "name" tema
      from coaching_masters cm 
      where cm.deleted_at is null
      order by cm."name"''').then((val) {
        if (val.isNotEmpty) {
          setState(() {
            _temaList.addAll({
              for (var row in val.toList()) row['id_tema'] as int: row['tema']
            }.entries.toList());
            _temaList.sort((a, b) => (a.value).compareTo(b.value));
          });
        }
      });
    });
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

  Future<void> _searchTrainees(String value) async {
    final query = value.trim();
    if (query.length < 2) {
      if (mounted) setState(() => _traineeResults.clear());
      return;
    }
    final remoteRows = await _api.searchCoachingEmployees(query);
    if (remoteRows != null) {
      final selectedCompany = _companyList
          .where((item) => item.key == _companyId)
          .firstOrNull
          ?.value
          .toString()
          .toLowerCase();
      final rows = remoteRows.where((row) {
        if (selectedCompany == null || selectedCompany.isEmpty) return true;
        final company = row['perusahaan']?.toString().toLowerCase() ?? '';
        return company.contains(selectedCompany) ||
            selectedCompany.contains(company);
      }).toList();
      if (mounted) {
        setState(() {
          _traineeResults
            ..clear()
            ..addAll(rows);
        });
      }
      return;
    }

    final escaped = query.replaceAll("'", "''").toLowerCase();
    final company = _companyId == null ? '' : 'and e.company_id = $_companyId';
    final rows = await _db.rawQuery('''select e.id, e.no_nik, e.nama_lengkap,
        e.posisi, e.departemen, e.perusahaan
      from employees e where e.deleted_at is null $company
      and (lower(e.nama_lengkap) like '%$escaped%' or lower(e.no_nik) like '%$escaped%')
      order by e.nama_lengkap limit 20''');
    if (mounted) {
      setState(() {
        _traineeResults
          ..clear()
          ..addAll(rows.map((row) => Map<String, dynamic>.from(row)));
      });
    }
  }

  Future<void> _saveCoaching() async {
    if (_saving) return;
    if (_temaId == null || !_temaList.any((item) => item.key == _temaId)) {
      SnackBarMsg.warning(context, 'Pilih tema coaching terlebih dahulu.');
      return;
    }
    if (_selectedTrainees.isEmpty) {
      SnackBarMsg.warning(context, 'Pilih minimal satu peserta coaching.');
      return;
    }
    setState(() => _saving = true);
    final theme =
        _temaList.where((item) => item.key == _temaId).first.value.toString();
    try {
      final tranId = await _db.insert(
          'coaching_trans',
          CoachingTrnModel(
            code:
                '${_profile?.noNik}-${DateTime.now().millisecondsSinceEpoch}0000000000'
                    .substring(0, 24),
            title: theme,
            companyId: _companyId,
            employeeId: _profile?.id,
            trainerId: _profile?.id,
            areaId: _areaId,
            locationId: _locationId,
            locationDetail: _locationDetail.text.trim(),
            date: DateFormat('yyyy-MM-dd').format(_date!),
            time: _time,
            temaId: _temaId,
            purpose: theme,
            remark: theme,
            feedback:
                'Umpan balik:\n${_feedback.text.trim()}\n\nKomitmen bersama:\n${_title.text.trim()}',
            image: _image,
            status: 0,
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ).toJson());
      if (tranId <= 0) throw StateError('Gagal menyimpan laporan lokal');
      for (final trainee in _selectedTrainees) {
        await _db.insert(
            'coaching_details',
            CoachingDetailModel(
              tranId: tranId,
              name: '${trainee['no_nik']} - ${trainee['nama_lengkap']}',
              remark: '${trainee['posisi'] ?? ''}',
              status: 0,
            ).toJson());
      }
      final synced = await syncTran(_db, ApiService(), 'coaching', tranId);
      if (!mounted) return;
      setState(() => _saving = false);
      await _showCoachingSuccessDialog(synced: synced);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        SnackBarMsg.danger(context, 'Gagal menyimpan coaching. Coba kembali.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _fillGpsFromDevice({bool silent = false}) {
    fillGpsCoordinate(
      context,
      _locationDetail,
      () => setState(() {}),
      silent: silent,
    );
  }

  Future<void> _loadCoachingOptionsFromMbs() async {
    // Cache ini berasal dari master MBS yang sama (Area & Perusahaan), dan
    // disimpan saat master berhasil dimuat pada modul lain. Ini menjaga
    // Coaching tetap berisi pada saat halaman Coaching MBS sedang tidak
    // merender daftar masternya sendiri.
    final data = await _api.getCoachingOptions() ??
        PreferenceService.getObservationOptionsCache();
    if (!mounted || data == null) return;
    List<MapEntry<int, dynamic>> entries(String key) {
      final raw = data[key];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((item) {
            final id = int.tryParse(item['id']?.toString() ?? '') ?? 0;
            return MapEntry<int, dynamic>(id, item['name']?.toString() ?? '');
          })
          .where((item) => item.key > 0 && item.value.toString().isNotEmpty)
          .toList();
    }

    final areas = entries('areas');
    final companies = entries('companies');
    final themes = entries('themes');
    setState(() {
      if (areas.isNotEmpty) {
        _areaList
          ..clear()
          ..addAll(areas);
      }
      if (companies.isNotEmpty) {
        _companyList
          ..clear()
          ..addAll(companies);
        if (!_companyList.any((item) => item.key == _companyId)) {
          // Web MBS membuka form Coaching dengan perusahaan akun (Indexim
          // untuk akun ini). Jika profil lama tidak menyimpan companyId,
          // gunakan master resmi Indexim alih-alih item pertama alfabetis.
          _companyId =
              _companyList.where((item) => item.key == 1).firstOrNull?.key ??
                  _companyList.first.key;
        }
      }
      if (themes.isNotEmpty) {
        _temaList
          ..clear()
          ..addAll(themes);
      }
      // Master Coaching pada instalasi lama tidak selalu tersedia ketika
      // perangkat pertama kali dibuka. Tetap sediakan tema standar agar form
      // dapat dipakai sambil master server dimuat kembali.
      if (_temaList.isEmpty) {
        _temaList.addAll(const [
          MapEntry(1, 'Sosialisasi'),
          MapEntry(2, 'Sharing Knowledge'),
          MapEntry(3, 'Pembinaan'),
        ]);
      }
    });
  }

  Future<void> _addCustomLocation() async {
    final item = await showAddCustomLocationDialog(
      context: context,
      db: _db,
      areaId: _areaId,
    );
    if (item == null) return;
    setState(() {
      _locationList.add(item);
      _locationList.sort((a, b) => a.value.compareTo(b.value));
      _locationId = item.key;
    });
  }

  Future<void> _getLocation(int val) async {
    _areaId = val;
    _locationId = null;
    _locationList = {
      for (var row in _rawData
          .where((e) =>
              e['id_lokasi'] != null &&
              e['id_area'] != null &&
              e['id_area'] as int == val)
          .toList())
        row['id_lokasi'] as int: row['lokasi']
    }.entries.toList();
    _locationList.sort((a, b) => (a.value).compareTo(b.value));
    setState(() {});

    final localCustomRows = await _db.rawQuery('''
      select id, name from enum_masters
      where deleted_at is null
        and type = 'location'
        and flag = 'custom-mobile'
        and ref_id = ?
      order by name
    ''', [val]);
    if (!mounted || _areaId != val) return;
    final localCustom = localCustomRows
        .where((row) => row['id'] != null && row['name'] != null)
        .map((row) => MapEntry<int, dynamic>(
            row['id'] as int, row['name'].toString()))
        .toList();
    if (localCustom.isNotEmpty) {
      setState(() {
        final combined = <int, dynamic>{
          for (final item in _locationList) item.key: item.value,
          for (final item in localCustom) item.key: item.value,
        };
        _locationList = combined.entries.toList()
          ..sort((a, b) => a.value.toString().compareTo(b.value.toString()));
      });
    }

    final area = _areaList.where((item) => item.key == val).firstOrNull;
    if (area == null) return;
    final remoteRows = await _api.getCoachingBenchmarks(area.value.toString());
    if (!mounted || _areaId != val || remoteRows == null) return;
    setState(() {
      final combined = <int, dynamic>{
        for (final item in remoteRows)
          if (item['id'] != null && item['name'] != null)
            item['id'] as int: item['name'],
        for (final item in localCustom) item.key: item.value,
      };
      _locationList = combined.entries.toList()
        ..sort((a, b) => a.value.toString().compareTo(b.value.toString()));
    });
  }

  Future<void> _showCoachingSuccessDialog({required bool synced}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: Color(0xFF16A34A), size: 38),
              ),
              const SizedBox(height: 18),
              const Text('Laporan coaching berhasil dibuat',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                synced
                    ? 'Laporan sudah tersimpan dan tersinkron ke server.'
                    : 'Laporan tersimpan di perangkat dan akan tersinkron otomatis saat koneksi tersedia.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Selesai'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoBox({
    required String label,
    required String? localPath,
    required VoidCallback onPick,
    required VoidCallback onRemove,
  }) {
    final hasImage = localPath != null && localPath.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: hasImage ? null : onPick,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            height: 160,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasImage ? const Color(0xFFA855F7) : const Color(0xFFCBD5E1),
              ),
            ),
            child: hasImage
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.file(
                          File(localPath),
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: InkWell(
                          onTap: onRemove,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_rounded, size: 34, color: Color(0xFF94A3B8)),
                      SizedBox(height: 8),
                      Text(
                        'Ambil Foto Kegiatan / Dari Galeri',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFFA855F7)),
              title: const Text('Ambil dari Kamera', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Color(0xFFA855F7)),
              title: const Text('Pilih dari Galeri', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final file = await pickImage(source: source);
    if (file != null) {
      setState(() => _image = file.path);
    }
  }

  Widget _masterPicker({
    required String label,
    required String hint,
    required IconData icon,
    required List<MapEntry<int, dynamic>> items,
    required int? selectedId,
    required ValueChanged<MapEntry<int, dynamic>?> onChanged,
    bool enabled = true,
    bool searchable = true,
  }) {
    MapEntry<int, dynamic>? selected;
    for (final item in items) {
      if (item.key == selectedId) {
        selected = item;
        break;
      }
    }
    final normalBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFA855F7), width: 1.5),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        DropdownSearch<MapEntry<int, dynamic>>(
          enabled: enabled,
          items: items,
          selectedItem: selected,
          itemAsString: (item) => item.value.toString(),
          popupProps: PopupProps.menu(
            showSearchBox: searchable,
            constraints: searchable
                ? const BoxConstraints(maxHeight: 440)
                : const BoxConstraints(maxHeight: 168),
          ),
          dropdownDecoratorProps: DropDownDecoratorProps(
            dropdownSearchDecoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              prefixIcon: Icon(icon, color: const Color(0xFFA855F7), size: 20),
              suffixIconColor: const Color(0xFF64748B),
              filled: true,
              fillColor: enabled
                  ? const Color(0xFFF8FAFC)
                  : const Color(0xFFF1F5F9),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
              border: normalBorder,
              enabledBorder: normalBorder,
              disabledBorder: normalBorder,
              focusedBorder: focusedBorder,
            ),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: const TopBar(title: 'Coaching & Pembinaan', back: 2),
        body: SingleChildScrollView(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SapHeaderCard(
                title: 'Formulir Sesi Coaching',
                subtitle: 'Pendampingan, pembinaan & peningkatan kompetensi keselamatan kerja.',
                icon: Icons.groups_rounded,
                accentColor: Color(0xFFA855F7),
                badgeBgColor: Color(0xFFFAF5FF),
                badgeBorderColor: Color(0xFFF3E8FF),
              ),

              // SECTION 1: Waktu & Lokasi Kegiatan
              SapSectionCard(
                stepNumber: '1',
                title: 'WAKTU & LOKASI KEGIATAN',
                subtitle: 'Waktu pelaksanaan dan titik lokasi kegiatan coaching',
                icon: Icons.location_on_rounded,
                accentColor: const Color(0xFF0284C7),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SapDatePickerTile(
                          label: 'Tanggal',
                          date: _date ?? DateTime.now(),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _date ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) setState(() => _date = picked);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SapTimePickerTile(
                          label: 'Jam Mulai',
                          timeText: _time ?? DateFormat('HH:mm').format(DateTime.now()),
                          onTap: () async {
                            final now = TimeOfDay.now();
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: now,
                            );
                            if (picked != null) {
                              final hh = picked.hour.toString().padLeft(2, '0');
                              final mm = picked.minute.toString().padLeft(2, '0');
                              setState(() => _time = '$hh:$mm');
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  _masterPicker(
                    label: 'Area Utama *',
                    hint: 'Cari area utama',
                    icon: Icons.map_outlined,
                    items: _areaList,
                    selectedId: _areaId,
                    onChanged: (item) {
                      if (item != null) _getLocation(item.key);
                    },
                  ),
                  const SizedBox(height: 14),

                  _masterPicker(
                    label: 'Detail Lokasi / Benchmark *',
                    hint: _areaId == null
                        ? 'Pilih area utama terlebih dahulu'
                        : 'Cari detail lokasi / benchmark',
                    icon: Icons.layers_outlined,
                    items: _locationList,
                    selectedId: _locationId,
                    enabled: _areaId != null,
                    onChanged: (item) => setState(() => _locationId = item?.key),
                  ),
                  AddCustomLocationButton(onPressed: _addCustomLocation),
                  const SizedBox(height: 14),

                  const Text(
                    'LOKASI SPESIFIK / GPS *',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _locationDetail,
                    decoration: gpsInputDecoration(
                      context: context,
                      onPressed: () => _fillGpsFromDevice(),
                      iconColor: const Color(0xFFA855F7),
                    ),
                    style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                    onChanged: (String val) => setState(() {}),
                  ),
                ],
              ),

              // SECTION 2: Tema & Materi Coaching
              SapSectionCard(
                stepNumber: '2',
                title: 'TEMA & MATERI COACHING',
                subtitle: 'Topik pembinaan, evaluasi feedback dan komitmen bersama',
                icon: Icons.menu_book_rounded,
                accentColor: const Color(0xFFA855F7),
                children: [
                  _masterPicker(
                    label: 'Tema Coaching *',
                    hint: 'Pilih tema coaching',
                    icon: Icons.menu_book_outlined,
                    items: _temaList,
                    selectedId: _temaId,
                    searchable: false,
                    onChanged: (item) => setState(() => _temaId = item?.key),
                  ),
                  const SizedBox(height: 14),

                  const Text(
                    'KOMITMEN BERSAMA *',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _title,
                    decoration: InputDecoration(
                      hintText: 'Contoh: Pekerja berkomitmen mematuhi SOP & APD',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      prefixIcon: const Icon(Icons.handshake_outlined, color: Color(0xFFA855F7), size: 20),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                    onChanged: (String val) => setState(() {}),
                  ),
                  const SizedBox(height: 14),

                  const Text(
                    'UMPAN BALIK (FEEDBACK) *',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _feedback,
                    minLines: 3,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Tuliskan catatan evaluasi dan umpan balik pelaksanaan tugas...',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                    onChanged: (String val) => setState(() {}),
                  ),
                ],
              ),

              // SECTION 3: Peserta Coaching (Trainee)
              SapSectionCard(
                stepNumber: '3',
                title: 'PESERTA COACHING (TRAINEE)',
                subtitle: 'Daftar pekerja yang menerima sesi coaching & bimbingan',
                icon: Icons.person_search_rounded,
                accentColor: const Color(0xFF059669),
                children: [
                  _masterPicker(
                    label: 'Perusahaan / Kontraktor *',
                    hint: 'Cari perusahaan atau kontraktor',
                    icon: Icons.apartment_rounded,
                    items: _companyList,
                    selectedId: _companyId,
                    onChanged: (item) => setState(() {
                      _companyId = item?.key;
                      _traineeResults.clear();
                      _selectedTrainees.clear();
                      _traineeQuery.clear();
                    }),
                  ),
                  const SizedBox(height: 14),

                  const Text(
                    'CARI PESERTA (NAMA / NIK) *',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _traineeQuery,
                    onChanged: _searchTrainees,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFA855F7), size: 20),
                      hintText: 'Ketik nama atau NIK peserta (min. 2 karakter)',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                  ),
                  if (_traineeResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      constraints: const BoxConstraints(maxHeight: 210),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _traineeResults.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        itemBuilder: (context, index) {
                          final trainee = _traineeResults[index];
                          final picked = _selectedTrainees.any((item) => item['id'] == trainee['id']);
                          return ListTile(
                            dense: true,
                            leading: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAF5FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.person_outline_rounded, color: Color(0xFFA855F7), size: 18),
                            ),
                            title: Text(
                              '${trainee['no_nik']} - ${trainee['nama_lengkap']}',
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            subtitle: Text(
                              [
                                trainee['posisi'],
                                trainee['departemen'],
                                trainee['perusahaan'],
                              ].where((value) => value != null && value.toString().trim().isNotEmpty).join(' • '),
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                            trailing: picked
                                ? const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 20)
                                : const Icon(Icons.add_circle_outline_rounded, color: Color(0xFFA855F7), size: 20),
                            onTap: picked
                                ? null
                                : () => setState(() {
                                      _selectedTrainees.add(trainee);
                                      _traineeResults.clear();
                                      _traineeQuery.clear();
                                    }),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: _selectedTrainees.isEmpty
                        ? const Text(
                            'Belum ada peserta yang dipilih. Cari dan pilih dari hasil pencarian di atas.',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          )
                        : Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: _selectedTrainees
                                .map((trainee) => Chip(
                                      backgroundColor: const Color(0xFFFAF5FF),
                                      side: const BorderSide(color: Color(0xFFE9D5FF)),
                                      avatar: const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFFA855F7)),
                                      label: Text(
                                        '${trainee['nama_lengkap']}',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B21A8)),
                                      ),
                                      deleteIcon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF9333EA)),
                                      onDeleted: () => setState(() => _selectedTrainees.remove(trainee)),
                                    ))
                                .toList(),
                          ),
                  ),
                ],
              ),

              // SECTION 4: Dokumentasi Foto Kegiatan
              SapSectionCard(
                stepNumber: '4',
                title: 'DOKUMENTASI FOTO KEGIATAN',
                subtitle: 'Foto bukti pelaksanaan sesi coaching bersama peserta',
                icon: Icons.camera_alt_rounded,
                accentColor: const Color(0xFFEAB308),
                children: [
                  _buildPhotoBox(
                    label: 'FOTO KEGIATAN COACHING *',
                    localPath: _image,
                    onPick: _pickPhoto,
                    onRemove: () => setState(() => _image = null),
                  ),
                  if (_image != null) const UploadFiles('CoachingForm', null),
                ],
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFA855F7),
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: (_temaId == null ||
                      _areaId == null ||
                      _locationId == null ||
                      _locationDetail.text.trim().isEmpty ||
                      _title.text.trim().isEmpty ||
                      _feedback.text.trim().isEmpty ||
                      _image == null ||
                      _selectedTrainees.isEmpty ||
                      _saving)
                  ? null
                  : _saveCoaching,
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                    )
                  : const Icon(Icons.check_circle_rounded, size: 20),
              label: Text(
                _saving ? 'Menyimpan...' : 'Simpan Coaching',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

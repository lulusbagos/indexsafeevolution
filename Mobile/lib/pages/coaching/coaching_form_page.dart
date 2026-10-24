import 'dart:io';

import 'package:date_time_picker/date_time_picker.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

import '../../models/coaching_tran_model.dart';
import '../../models/coaching_detail_model.dart';
import '../../services/api.dart';
import '../../services/database.dart';
import '../../services/preference.dart';
import '../../services/sync.dart';
import '../../utils/helpers.dart';
import '../../widgets/button_app.dart';
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
  VideoPlayerController? _videoPlayer;
  File? _videoFile;
  bool _isVideo = false;
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
    _videoPlayer?.dispose();
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
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.25),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        DropdownSearch<MapEntry<int, dynamic>>(
          enabled: enabled,
          items: items,
          selectedItem: selected,
          itemAsString: (item) => item.value.toString(),
          popupProps: PopupProps.menu(
            showSearchBox: searchable,
            // Tema hanya mempunyai tiga pilihan. Panel pendek tanpa kolom
            // pencarian membuatnya terasa seperti pemilih biasa, bukan daftar
            // master perusahaan yang panjang.
            constraints: searchable
                ? const BoxConstraints(maxHeight: 440)
                : const BoxConstraints(maxHeight: 168),
          ),
          dropdownDecoratorProps: DropDownDecoratorProps(
            dropdownSearchDecoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
              prefixIcon: Icon(icon, color: const Color(0xFF475569), size: 21),
              suffixIconColor: const Color(0xFF64748B),
              filled: true,
              fillColor: enabled
                  ? const Color(0xFFF1F5F9)
                  : const Color(0xFFE2E8F0),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
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
        appBar: const TopBar(title: 'Coaching & Pembinaan', back: 2),
        body: SingleChildScrollView(
          controller: _scrollCtrl,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.groups_rounded, color: Color(0xFFA855F7)),
                  SizedBox(width: 8),
                  Text('Catat Sesi Coaching Baru',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Tanggal Kegiatan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              DateTimePicker(
                decoration: InputDecoration(
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Icon(
                      Icons.calendar_month,
                      size: 24,
                      color: Colors.indigo.shade400,
                    ),
                  ),
                ),
                style: const TextStyle(fontSize: 16),
                type: DateTimePickerType.date,
                dateMask: 'dd/MM/yyyy',
                controller: null,
                initialValue: _date != null
                    ? '${_date!.day}/${_date!.month}/${_date!.year}'
                    : null,
                firstDate: DateTime.now(),
                lastDate: DateTime(2100),
                dateLabelText: 'Date',
                timeLabelText: 'Hour',
                onChanged: (val) => {
                  setState(() => _date = DateTime.parse(val)),
                },
              ),
              const SizedBox(height: 15),
              const Text(
                'Waktu Mulai',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              DateTimePicker(
                decoration: InputDecoration(
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Icon(
                      Icons.access_time,
                      size: 24,
                      color: Colors.indigo.shade400,
                    ),
                  ),
                ),
                style: const TextStyle(fontSize: 16),
                type: DateTimePickerType.time,
                dateMask: 'dd/MM/yyyy',
                controller: null,
                initialValue: _time,
                firstDate: DateTime.now(),
                lastDate: DateTime(2100),
                dateLabelText: 'Date',
                timeLabelText: 'Hour',
                onChanged: (val) => {
                  setState(() => _time = val),
                },
              ),
              const SizedBox(height: 15),
              _masterPicker(
                label: 'Area Utama',
                hint: 'Cari area',
                icon: Icons.map_outlined,
                items: _areaList,
                selectedId: _areaId,
                onChanged: (item) {
                  if (item != null) _getLocation(item.key);
                },
              ),
              const SizedBox(height: 15),
              _masterPicker(
                label: 'Detail Lokasi / Benchmark',
                hint: _areaId == null
                    ? 'Pilih area utama terlebih dahulu'
                    : 'Cari detail lokasi',
                icon: Icons.layers_outlined,
                items: _locationList,
                selectedId: _locationId,
                enabled: _areaId != null,
                onChanged: (item) => setState(() => _locationId = item?.key),
              ),
              AddCustomLocationButton(onPressed: _addCustomLocation),
              const SizedBox(height: 15),
              const Text(
                'Lokasi Spesifik',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _locationDetail,
                decoration: gpsInputDecoration(
                  context: context,
                  onPressed: () => _fillGpsFromDevice(),
                  iconColor: Colors.indigo.shade400,
                ),
                style: const TextStyle(fontSize: 16),
                onChanged: (String val) => setState(() {}),
              ),
              const SizedBox(height: 15),
              const SizedBox(height: 8),
              _masterPicker(
                label: 'Tema Coaching',
                hint: 'Pilih tema coaching',
                icon: Icons.menu_book_outlined,
                items: _temaList,
                selectedId: _temaId,
                searchable: false,
                onChanged: (item) => setState(() => _temaId = item?.key),
              ),
              const SizedBox(height: 24),
              const Text('Pilih Peserta Coaching (Trainee)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text(
                  'Tentukan perusahaan, lalu cari berdasarkan nama atau NIK.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 18),
              _masterPicker(
                label: 'Perusahaan / Kontraktor',
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
              const SizedBox(height: 18),
              const Text('Cari Peserta',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _traineeQuery,
                onChanged: _searchTrainees,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Ketik nama atau NIK peserta (min. 2 karakter)',
                ),
              ),
              if (_traineeResults.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  constraints: const BoxConstraints(maxHeight: 210),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _traineeResults.length,
                    itemBuilder: (context, index) {
                      final trainee = _traineeResults[index];
                      final picked = _selectedTrainees
                          .any((item) => item['id'] == trainee['id']);
                      return ListTile(
                        leading: const Icon(Icons.person_outline_rounded),
                        title: Text(
                            '${trainee['no_nik']} - ${trainee['nama_lengkap']}'),
                        subtitle: Text(
                          [
                            trainee['posisi'],
                            trainee['departemen'],
                            trainee['perusahaan'],
                          ]
                              .where((value) =>
                                  value != null &&
                                  value.toString().trim().isNotEmpty)
                              .join(' • '),
                        ),
                        trailing: picked
                            ? const Icon(Icons.check_circle_rounded,
                                color: Color(0xFF059669))
                            : null,
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
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12)),
                child: _selectedTrainees.isEmpty
                    ? const Text(
                        'Belum ada peserta yang dipilih. Cari dan pilih dari hasil pencarian di atas.',
                        style:
                            TextStyle(color: Color(0xFF64748B), fontSize: 12))
                    : Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: _selectedTrainees
                            .map((trainee) => InputChip(
                                  label: Text('${trainee['nama_lengkap']}'),
                                  onDeleted: () => setState(
                                      () => _selectedTrainees.remove(trainee)),
                                ))
                            .toList(),
                      ),
              ),
              const SizedBox(height: 15),
              const Text(
                'Komitmen Bersama',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _title,
                decoration: InputDecoration(
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Icon(
                      Icons.text_fields,
                      size: 24,
                      color: Colors.indigo.shade400,
                    ),
                  ),
                ),
                style: const TextStyle(fontSize: 16),
                onChanged: (String val) => setState(() {}),
              ),
              const SizedBox(height: 15),
              const Text(
                'Umpan Balik (Feedback)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _feedback,
                minLines: 3,
                maxLines: 3,
                decoration: InputDecoration(
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Icon(
                      Icons.textsms_outlined,
                      size: 24,
                      color: Colors.indigo.shade400,
                    ),
                  ),
                ),
                style: const TextStyle(fontSize: 16),
                onChanged: (String val) => setState(() {}),
              ),
              const SizedBox(height: 15),
              const Text(
                'Foto Kegiatan Coaching',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: () async {
                  await showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.camera_alt,
                                color: Colors.grey),
                            title: const Text('Camera'),
                            onTap: () {
                              Navigator.pop(context);
                              Future<File?> imageFile =
                                  pickImage(source: ImageSource.camera);
                              imageFile.then((value) {
                                if (value != null) {
                                  setState(() => _image = value.path);
                                }
                              });
                            },
                          ),
                          ListTile(
                            leading:
                                const Icon(Icons.image, color: Colors.grey),
                            title: const Text('Gallery'),
                            onTap: () {
                              Navigator.pop(context);
                              Future<File?> imageFile =
                                  pickImage(source: ImageSource.gallery);
                              imageFile.then((value) {
                                if (value != null) {
                                  setState(() => _image = value.path);
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: Container(
                  width: MediaQuery.of(context).size.width,
                  height: 150,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _image == null || _image == ''
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Foto Kegiatan Coaching',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        )
                      : Image.file(File(_image!)),
                ),
              ),
              if (_image != null) const UploadFiles('CoachingForm', null),
              const SizedBox(height: 15),
              Visibility(
                visible: false,
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Apakah ada video hazard?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Switch(
                      value: _isVideo,
                      activeThumbColor: Colors.indigo,
                      onChanged: (value) {
                        setState(() => _isVideo = value);

                        Future.delayed(const Duration(milliseconds: 200), () {
                          _scrollCtrl.animateTo(
                            _scrollCtrl.position.maxScrollExtent,
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOut,
                          );
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _isVideo == true
                  ? Center(
                      child: _videoFile != null
                          ? Column(
                              children: [
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (_videoPlayer!.value.isPlaying) {
                                        _videoPlayer!.pause();
                                      } else {
                                        _videoPlayer!.play();
                                      }
                                    });
                                  },
                                  child: Container(
                                    width: MediaQuery.of(context).size.width,
                                    height: 200,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: Colors.indigo.shade200),
                                      color: Colors.white54,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: AspectRatio(
                                        aspectRatio:
                                            _videoPlayer!.value.aspectRatio,
                                        child: VideoPlayer(
                                          _videoPlayer!,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 15),
                                buttonApp(
                                  label: 'Ganti Video',
                                  onPressed: () async {
                                    final ImagePicker picker = ImagePicker();
                                    final File videoPicked =
                                        File((await picker.pickVideo(
                                      source: ImageSource.camera,
                                      maxDuration: const Duration(seconds: 10),
                                    ))!
                                            .path);
                                    setState(() {
                                      _videoFile = File(videoPicked.path);
                                      _videoPlayer = VideoPlayerController.file(
                                          _videoFile!)
                                        ..initialize().then((_) {
                                          setState(() {});
                                        });
                                    });
                                  },
                                )
                              ],
                            )
                          : Container(
                              width: MediaQuery.of(context).size.width,
                              height: 200,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: Colors.indigo.shade200),
                                color: Colors.white54,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.video_collection,
                                      size: 30,
                                      color: Colors.indigo.shade400,
                                    ),
                                    onPressed: () async {
                                      final ImagePicker picker = ImagePicker();
                                      final File videoPicked =
                                          File((await picker.pickVideo(
                                        source: ImageSource.camera,
                                        maxDuration:
                                            const Duration(seconds: 10),
                                      ))!
                                              .path);
                                      setState(() {
                                        _videoFile = File(videoPicked.path);
                                        _videoPlayer = VideoPlayerController
                                            .file(_videoFile!)
                                          ..initialize().then((_) {
                                            setState(() {});
                                          });
                                      });
                                    },
                                  ),
                                  const Text('Pilih Video'),
                                ],
                              ),
                            ),
                    )
                  : const SizedBox(),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: (_temaId == null ||
                    _areaId == null ||
                    _locationId == null ||
                    _locationDetail.text == '' ||
                    _title.text == '' ||
                    _feedback.text == '' ||
                    _image == null ||
                    _selectedTrainees.isEmpty ||
                    _saving)
                ? null
                : _saveCoaching,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : const Text('Simpan Coaching'),
          ),
        ),
      ),
    );
  }
}

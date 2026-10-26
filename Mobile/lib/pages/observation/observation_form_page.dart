import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/observation_tran_model.dart';
import '../../models/observation_detail_model.dart';
import '../../services/database.dart';
import '../../services/api.dart';
import '../../services/preference.dart';
import '../../widgets/sap_form_widgets.dart';
import '../../widgets/top_bar.dart';
import 'observation_detail_page.dart';

class ObservationFormPage extends StatefulWidget {
  const ObservationFormPage({this.editData, super.key});
  final Map<String, dynamic>? editData;

  @override
  State<ObservationFormPage> createState() => _ObservationFormPageState();
}

class _ObservationFormPageState extends State<ObservationFormPage> {
  final _scrollCtrl = ScrollController();
  final _db = DatabaseService();
  final _api = ApiService();
  final _profile = PreferenceService.getProfile();
  final _locationDetail = TextEditingController();
  final _subject = TextEditingController();
  final List<dynamic> _rawData = [];
  List<MapEntry<String, dynamic>> _penilaianList = [];
  final List<MapEntry<int, dynamic>> _deptList = [];
  final List<MapEntry<int, dynamic>> _docList = [];
  final List<MapEntry<int, dynamic>> _riskList = [];
  final List<MapEntry<int, dynamic>> _areaList = [];
  List<MapEntry<int, dynamic>> _locationList = [];
  DateTime? _date = DateTime.now();
  String? _time = DateFormat('hh:mm').format(DateTime.now());
  int? _deptId;
  int? _companyId;
  int? _docId;
  int? _riskId;
  int? _areaId;
  int? _locationId;
  String? _penilaianId;
  List<MapEntry<int, dynamic>> _perihalOptions = [];
  List<MapEntry<int, dynamic>> _hasilOptions = [];
  List<MapEntry<int, dynamic>> _companyOptions = [];
  List<ObservationDetailModel> _editDetails = [];
  Map<String, dynamic> _companyDeptMap = {};
  bool _loadingEditDetails = false;
  bool _loadingOptions = true;
  bool _loadingDepts = false;
  String? _optionsError;

  @override
  void initState() {
    super.initState();
    _companyId = widget.editData?['company_id'] as int? ?? _profile?.companyId;
    if (widget.editData != null) {
      _subject.text = widget.editData!['title']?.toString() ?? '';
      _locationDetail.text =
          widget.editData!['location_detail']?.toString() ?? '';
      _date = DateTime.tryParse(widget.editData!['date']?.toString() ?? '') ??
          _date;
      final savedTime = widget.editData!['time']?.toString();
      if (savedTime != null && savedTime.isNotEmpty) _time = savedTime;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.editData == null) _fillGpsFromDevice(silent: true);
      _loadObservationOptions(_companyId);
      if (widget.editData != null) _loadEditDetails();

      _db.rawQuery('''select
        id id_dokumen_pendukung,
        "name" dokumen_pendukung
      from observation_masters om 
      where om.deleted_at is null and type = 'document'
      order by om."name"''').then((val) {
        if (val.isNotEmpty) {
          setState(() {
            _docList.addAll({
              for (var row in val.toList())
                row['id_dokumen_pendukung'] as int: row['dokumen_pendukung']
            }.entries.toList());
            _docList.sort((a, b) => (a.value).compareTo(b.value));
          });
        }
      });

      _db.rawQuery('''select
        id id_resiko_kritis,
        "name" resiko_kritis
      from observation_masters om 
      where om.deleted_at is null and type = 'risk'
      order by om."name"''').then((val) {
        if (val.isNotEmpty) {
          setState(() {
            _riskList.addAll({
              for (var row in val.toList())
                row['id_resiko_kritis'] as int: row['resiko_kritis']
            }.entries.toList());
            _riskList.sort((a, b) => (a.value).compareTo(b.value));
          });
        }
      });

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
    });
  }

  Future<void> _loadEditDetails() async {
    final rawId = widget.editData?['id'];
    final tranId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    if (tranId == null) return;
    setState(() => _loadingEditDetails = true);
    try {
      final rows = await _db.rawQuery('''select * from observation_details
             where tran_id = ? and deleted_at is null
             order by id asc''', [tranId]);
      if (!mounted) return;
      setState(() {
        _editDetails = rows
            .map((row) =>
                ObservationDetailModel.fromJson(Map<String, dynamic>.from(row)))
            .toList();
        _loadingEditDetails = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingEditDetails = false);
    }
  }

  List<MapEntry<int, dynamic>> _entries(Map<String, dynamic> data, String key) {
    final raw = data[key];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((item) {
          final id = int.tryParse(item['id'].toString()) ?? 0;
          return MapEntry(id, item['name']?.toString() ?? '');
        })
        .where((item) => item.key > 0 && item.value.toString().isNotEmpty)
        .toList();
  }

  Future<void> _loadObservationOptions(int? companyId) async {
    if (mounted) {
      setState(() {
        _loadingOptions = true;
        _optionsError = null;
      });
    }
    final onlineData =
        await _api.getObservationOptions(perusahaanId: companyId);
    if (!mounted) return;
    Map<String, dynamic>? data = onlineData ?? PreferenceService.getObservationOptionsCache();
    if (data == null) {
      try {
        final depts = await _db.rawQuery('''select me.id, me."name" 
          from enum_masters me 
          where me.deleted_at is null and me."type" = 'dept' order by me."name"''');
        final docs = await _db.rawQuery('''select om.id, om."name" 
          from observation_masters om 
          where om.deleted_at is null and om.type = 'document' order by om."name"''');
        final risks = await _db.rawQuery('''select om.id, om."name" 
          from observation_masters om 
          where om.deleted_at is null and om.type = 'risk' order by om."name"''');
        final areasRows = await _db.rawQuery('''select me.id, me."name" 
          from enum_masters me 
          where me.deleted_at is null and me."type" = 'area' and me."name" not like 'Inspeksi%' and me."name" not like 'Area%' order by me."name"''');
        final locRows = await _db.rawQuery('''select me2.id, me2."name", me."name" as area 
          from enum_masters me 
          join enum_masters me2 on me2.ref_id = me.id and me2.deleted_at is null 
          where me.deleted_at is null and me."type" = 'area' order by me2."name"''');
        final comps = await _db.rawQuery('''select c.id, c."name" 
          from enum_masters c 
          where c.deleted_at is null and c."type" = 'company' order by c."name"''');
        final subjects = await _db.rawQuery('''select om.id, om."name" 
          from observation_masters om 
          where om.deleted_at is null and om.type = 'subject' order by om."name"''');

        if (depts.isNotEmpty || docs.isNotEmpty || areasRows.isNotEmpty) {
          data = {
            'departments': depts.map((r) => {'id': r['id'], 'name': r['name']}).toList(),
            'documents': docs.map((r) => {'id': r['id'], 'name': r['name']}).toList(),
            'criticalRisks': risks.map((r) => {'id': r['id'], 'name': r['name']}).toList(),
            'areas': areasRows.map((r) => {'id': r['id'], 'name': r['name']}).toList(),
            'locations': locRows.map((r) => {'id': r['id'], 'name': r['name'], 'area': r['area']}).toList(),
            'companies': comps.isNotEmpty
                ? comps.map((r) => {'id': r['id'], 'name': r['name']}).toList()
                : [{'id': 1, 'name': 'PT INDEXIM COALINDO'}],
            'riskLevels': [
              {'id': 1, 'name': 'Low'},
              {'id': 2, 'name': 'Medium'},
              {'id': 3, 'name': 'High'},
              {'id': 4, 'name': 'Critical'},
            ],
            'subjects': subjects.isNotEmpty
                ? subjects.map((r) => {'id': r['id'], 'name': r['name']}).toList()
                : [{'id': 1, 'name': 'Pengoperasian Kendaraan / Unit'}, {'id': 2, 'name': 'Bekerja di Ketinggian'}, {'id': 3, 'name': 'Housekeeping'}],
            'results': [
              {'id': 1, 'name': 'Aman (Safe)'},
              {'id': 2, 'name': 'Tidak Aman (At Risk)'},
            ],
          };
        }
      } catch (_) {}
    }
    if (data == null) {
      setState(() {
        _loadingOptions = false;
        _optionsError =
            'Master Observasi belum pernah tersimpan di perangkat. Sambungkan backend sekali untuk memuat data awal.';
      });
      return;
    }
    final options = data;
    final locations = _entries(options, 'locations');
    final areas = _entries(options, 'areas');
    final rawLocations = locations.map((location) {
      final source = (options['locations'] as List).whereType<Map>().firstWhere(
            (item) => item['id'].toString() == location.key.toString(),
            orElse: () => <String, dynamic>{},
          );
      final areaName = source['area']?.toString() ?? '';
      final area = areas
          .where((entry) => entry.value.toString() == areaName)
          .firstOrNull;
      return <String, dynamic>{
        'id_area': area?.key,
        'area': areaName,
        'id_lokasi': location.key,
        'lokasi': location.value
      };
    }).toList();
    setState(() {
      if (options['companyDeptMap'] is Map) {
        _companyDeptMap = Map<String, dynamic>.from(options['companyDeptMap'] as Map);
      }

      // Populate departments for the active company
      List<MapEntry<int, dynamic>> depts = [];
      if (companyId != null && companyId > 0 && _companyDeptMap.isNotEmpty) {
        final list = _companyDeptMap[companyId.toString()];
        if (list is List && list.isNotEmpty) {
          final strings = list.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
          depts = List.generate(strings.length, (i) => MapEntry(i + 1, strings[i]));
        }
      }
      if (depts.isEmpty) {
        depts = _entries(options, 'departments');
      }

      _deptList
        ..clear()
        ..addAll(depts);
      _companyOptions = _entries(options, 'companies');
      _docList
        ..clear()
        ..addAll(_entries(options, 'documents'));
      _riskList
        ..clear()
        ..addAll(_entries(options, 'criticalRisks'));
      _areaList
        ..clear()
        ..addAll(areas);
      _rawData
        ..clear()
        ..addAll(rawLocations);
      _penilaianList = _entries(options, 'riskLevels')
          .map((entry) => MapEntry(entry.value.toString(), entry.value))
          .toList();
      _perihalOptions = _entries(options, 'subjects');
      _hasilOptions = _entries(options, 'results');
      _deptId = _docId = _riskId = _areaId = _locationId = null;
      _penilaianId = null;
      _locationList = [];
      if (widget.editData != null) {
        int? findId(List<MapEntry<int, dynamic>> values, String key) => values
            .where((e) =>
                e.value.toString() == (widget.editData![key] ?? '').toString())
            .firstOrNull
            ?.key;
        _deptId = findId(_deptList, 'dept_name');
        _docId = findId(_docList, 'doc_name');
        _riskId = findId(_riskList, 'risk_name');
        _penilaianId = widget.editData!['risk_level']?.toString();
        _areaId = findId(_areaList, 'area');
        if (_areaId != null) {
          _getLocation(_areaId!);
          _locationId = findId(_locationList, 'lokasi');
        }
      }
      _loadingOptions = false;
    });
  }

  /// Dynamically update departments when user picks an observed company,
  /// matching web ObservationController logic.
  Future<void> _updateDepartmentsForCompany(int companyId) async {
    setState(() => _loadingDepts = true);
    List<String> deptNames = [];

    // 1. Instant local lookup from cached companyDeptMap
    if (_companyDeptMap.isNotEmpty) {
      final raw = _companyDeptMap[companyId.toString()];
      if (raw is List && raw.isNotEmpty) {
        deptNames = raw
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }

    // 2. Fetch from Backend API / Web MBS if not found locally
    if (deptNames.isEmpty) {
      deptNames = await _api.getDepartmentsByCompany(companyId);
    }

    if (!mounted) return;
    setState(() {
      _deptList.clear();
      if (deptNames.isNotEmpty) {
        _deptList.addAll(List.generate(
            deptNames.length, (i) => MapEntry(i + 1, deptNames[i])));
      }
      _deptId = null;
      _loadingDepts = false;
    });
  }

  @override
  void dispose() {
    /** */

    super.dispose();
  }

  void _fillGpsFromDevice({bool silent = false}) {
    fillGpsCoordinate(
      context,
      _locationDetail,
      () => setState(() {}),
      silent: silent,
    );
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

  void _getLocation(int val) {
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
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: const TopBar(title: 'Observation', back: 2),
        body: _loadingOptions
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 14),
                    Text('Memuat data Observasi dari MBS...'),
                  ],
                ),
              )
            : _optionsError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off_rounded, size: 42),
                          const SizedBox(height: 12),
                          Text(_optionsError!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () =>
                                _loadObservationOptions(_companyId),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Muat ulang'),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SapHeaderCard(
                          title: 'Formulir Laporan Observasi',
                          subtitle: 'Catat observasi perilaku, kondisi lingkungan, dan kepatuhan K3.',
                          icon: Icons.fact_check_rounded,
                          accentColor: Color(0xFF0284C7),
                          badgeBgColor: Color(0xFFF0F9FF),
                          badgeBorderColor: Color(0xFFE0F2FE),
                        ),

                        // SECTION 1: Waktu & Lokasi
                        SapSectionCard(
                          stepNumber: '1',
                          title: 'WAKTU & LOKASI OBSERVASI',
                          subtitle: 'Tanggal, jam, perusahaan dan titik lokasi pengamatan',
                          icon: Icons.location_on_rounded,
                          accentColor: const Color(0xFF0284C7),
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: SapDatePickerTile(
                                    label: 'Tanggal Observasi',
                                    date: _date ?? DateTime.now(),
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: _date ?? DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime.now(),
                                      );
                                      if (picked != null) setState(() => _date = picked);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SapTimePickerTile(
                                    label: 'Waktu Observasi',
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

                            const Text('PERUSAHAAN YANG DIAMATI *', style: TextStyle(color: Color(0xFF0F172A), fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                            const SizedBox(height: 6),
                            DropdownSearch<MapEntry<int, dynamic>>(
                              selectedItem: _companyOptions
                                  .where((item) => item.key == _companyId)
                                  .firstOrNull,
                              items: _companyOptions,
                              itemAsString: (item) => item.value.toString(),
                              dropdownDecoratorProps: DropDownDecoratorProps(
                                dropdownSearchDecoration: InputDecoration(
                                  hintText: 'Pilih perusahaan...',
                                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                  prefixIcon: const Icon(Icons.business_rounded, color: Color(0xFF0284C7), size: 20),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                ),
                              ),
                              popupProps: const PopupProps.menu(
                                fit: FlexFit.loose,
                                showSearchBox: true,
                                searchFieldProps: TextFieldProps(
                                  decoration: InputDecoration(
                                    hintText: 'Cari perusahaan...',
                                    prefixIcon: Icon(Icons.search_rounded),
                                  ),
                                ),
                              ),
                              onChanged: (item) {
                                if (item == null) return;
                                final newCompanyId = item.key;
                                setState(() {
                                  _companyId = newCompanyId;
                                  _deptId = null;
                                });
                                _updateDepartmentsForCompany(newCompanyId);
                              },
                            ),
                            const SizedBox(height: 14),

                            const Text('AREA UTAMA *', style: TextStyle(color: Color(0xFF0F172A), fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: _areaId,
                                  isExpanded: true,
                                  hint: const Text('Pilih Area Utama', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                                  items: _areaList.map((item) {
                                    return DropdownMenuItem<int>(
                                      value: item.key,
                                      child: Text(
                                        item.value.toString(),
                                        style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (int? val) {
                                    if (val != null) setState(() => _getLocation(val));
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            const Text('DETAIL LOKASI / BENCHMARK *', style: TextStyle(color: Color(0xFF0F172A), fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: _locationId,
                                  isExpanded: true,
                                  hint: const Text('Pilih Detail Lokasi', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                                  items: _locationList.map((item) {
                                    return DropdownMenuItem<int>(
                                      value: item.key,
                                      child: Text(
                                        item.value.toString(),
                                        style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (int? val) {
                                    if (val != null) setState(() => _locationId = val);
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            AddCustomLocationButton(onPressed: _addCustomLocation),
                            const SizedBox(height: 12),

                            const Text('LOKASI SPESIFIK / GPS', style: TextStyle(color: Color(0xFF0F172A), fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _locationDetail,
                              decoration: gpsInputDecoration(
                                context: context,
                                onPressed: () => _fillGpsFromDevice(),
                                iconColor: const Color(0xFF0284C7),
                              ).copyWith(
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              ),
                              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                              onChanged: (_) => setState(() {}),
                            ),
                          ],
                        ),

                        // SECTION 2: Kegiatan & Risiko
                        SapSectionCard(
                          stepNumber: '2',
                          title: 'KEGIATAN & KLASIFIKASI RISIKO',
                          subtitle: 'Aktivitas yang diamati, departemen terkait dan tingkat risiko',
                          icon: Icons.shield_outlined,
                          accentColor: const Color(0xFFD97706),
                          children: [
                            const Text('KEGIATAN YANG DIAMATI *', style: TextStyle(color: Color(0xFF0F172A), fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _subject,
                              decoration: InputDecoration(
                                hintText: 'Contoh: Pengelasan pipa di Workshop Mitra',
                                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                prefixIcon: const Icon(Icons.content_paste_search_rounded, color: Color(0xFFD97706), size: 20),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              ),
                              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 14),

                            const Text('DEPARTEMEN PEKERJAAN *', style: TextStyle(color: Color(0xFF0F172A), fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                            const SizedBox(height: 6),
                            DropdownSearch<MapEntry<int, dynamic>>(
                              selectedItem: _deptList.where((e) => e.key == _deptId).firstOrNull,
                              items: _deptList.toList(),
                              enabled: !_loadingDepts && _companyId != null,
                              itemAsString: (MapEntry<int, dynamic>? e) => e?.value ?? '',
                              dropdownDecoratorProps: DropDownDecoratorProps(
                                dropdownSearchDecoration: InputDecoration(
                                  hintText: _loadingDepts
                                      ? 'Memuat departemen...'
                                      : (_companyId == null
                                          ? 'Pilih Perusahaan terlebih dahulu...'
                                          : (_deptList.isEmpty
                                              ? '(Tidak ada departemen terdaftar)'
                                              : 'Pilih Departemen...')),
                                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                  prefixIcon: _loadingDepts
                                      ? const Padding(
                                          padding: EdgeInsets.all(12),
                                          child: SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Color(0xFFD97706)),
                                          ),
                                        )
                                      : const Icon(Icons.corporate_fare_rounded, color: Color(0xFFD97706), size: 20),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                  disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                ),
                              ),
                              popupProps: const PopupProps.menu(
                                fit: FlexFit.loose,
                                showSearchBox: true,
                                searchFieldProps: TextFieldProps(
                                  decoration: InputDecoration(
                                    hintText: 'Cari departemen...',
                                    prefixIcon: Icon(Icons.search_rounded),
                                  ),
                                ),
                              ),
                              onChanged: (val) {
                                if (val != null) setState(() => _deptId = val.key);
                              },
                            ),
                            const SizedBox(height: 14),

                            const Text('DOKUMEN PENDUKUNG *', style: TextStyle(color: Color(0xFF0F172A), fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: _docId,
                                  isExpanded: true,
                                  hint: const Text('Pilih Dokumen', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                                  items: _docList.map((item) {
                                    return DropdownMenuItem<int>(
                                      value: item.key,
                                      child: Text(
                                        item.value.toString(),
                                        style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (int? val) {
                                    if (val != null) setState(() => _docId = val);
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            const Text('RISIKO KRITIS *', style: TextStyle(color: Color(0xFF0F172A), fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: _riskId,
                                  isExpanded: true,
                                  hint: const Text('Pilih Risiko Kritis', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                                  items: _riskList.map((item) {
                                    return DropdownMenuItem<int>(
                                      value: item.key,
                                      child: Text(
                                        item.value.toString(),
                                        style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (int? val) {
                                    if (val != null) setState(() => _riskId = val);
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            const Text('PENILAIAN TINGKAT RISIKO *', style: TextStyle(color: Color(0xFF0F172A), fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _penilaianList.map((item) {
                                final isSel = _penilaianId == item.key;
                                Color badgeColor = const Color(0xFF0284C7);
                                final lower = item.value.toString().toLowerCase();
                                if (lower.contains('critical') || lower.contains('high')) {
                                  badgeColor = const Color(0xFFDC2626);
                                } else if (lower.contains('medium')) {
                                  badgeColor = const Color(0xFFD97706);
                                } else if (lower.contains('low')) {
                                  badgeColor = const Color(0xFF16A34A);
                                }

                                return InkWell(
                                  onTap: () => setState(() => _penilaianId = item.key),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSel ? badgeColor : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: isSel ? badgeColor : const Color(0xFFE2E8F0)),
                                    ),
                                    child: Text(
                                      item.value.toString(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                        color: isSel ? Colors.white : const Color(0xFF334155),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
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
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Lanjut ke Detail Temuan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            onPressed: (_deptId == null ||
                    _docId == null ||
                    _riskId == null ||
                    _areaId == null ||
                    _locationId == null ||
                    _locationDetail.text == '' ||
                    _subject.text == '' ||
                    _penilaianId == null ||
                    _loadingEditDetails)
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ObservationDetailPage(
                          observationTrnModel: ObservationTrnModel(
                            // Identitas lokal diperlukan saat Simpan Edit agar
                            // History/PDF membaca header yang sudah terbaru.
                            id: int.tryParse(
                                widget.editData?['id']?.toString() ?? ''),
                            refId: int.tryParse(
                                widget.editData?['ref_id']?.toString() ?? ''),
                            syncId: int.tryParse(
                                widget.editData?['sync_id']?.toString() ?? ''),
                            code:
                                '${_profile?.noNik}-${DateTime.now().millisecondsSinceEpoch}0000000000'
                                    .substring(0, 24),
                            title: _subject.text,
                            companyId: _companyId,
                            companyName: _companyOptions
                                .where((i) => i.key == _companyId)
                                .firstOrNull
                                ?.value
                                .toString(),
                            employeeId: _profile?.id,
                            deptId: _deptId,
                            areaId: _areaId,
                            locationId: _locationId,
                            locationDetail: _locationDetail.text,
                            date: _date!.toString().substring(0, 10),
                            time: _time!,
                            subject: _subject.text,
                            activity: _penilaianId,
                            createdAt: DateTime.now().toString(),
                            updatedAt: DateTime.now().toString(),
                            docId: _docId,
                            riskId: _riskId,
                            area: _areaList
                                .where((i) => i.key == _areaId)
                                .first
                                .value
                                .toString(),
                            lokasi: _locationList
                                .where((i) => i.key == _locationId)
                                .first
                                .value
                                .toString(),
                            deptName: _deptList
                                .where((i) => i.key == _deptId)
                                .firstOrNull
                                ?.value
                                ?.toString() ??
                                '',
                            docName: _docList
                                .where((i) => i.key == _docId)
                                .first
                                .value
                                .toString(),
                            riskName: _riskList
                                .where((i) => i.key == _riskId)
                                .first
                                .value
                                .toString(),
                            riskLevel: _penilaianId,
                            remark: _docList
                                .where((i) => i.key == _docId)
                                .first
                                .value
                                .toString(),
                          ),
                          observationPoints: _perihalOptions,
                          observationResults: _hasilOptions,
                          editServerId: widget.editData?['sync_id'] as int?,
                          initialDetails: _editDetails,
                          initialDetail: widget.editData == null ||
                                  _editDetails.isNotEmpty
                              ? null
                              : ObservationDetailModel(
                                  point:
                                      widget.editData!['perihal']?.toString(),
                                  type: widget.editData!['hasil']?.toString(),
                                  remark:
                                      widget.editData!['remark']?.toString(),
                                ),
                        ),
                      ),
                    );
                  },
            ),
          ),
        ),
      ),
    );
  }
}

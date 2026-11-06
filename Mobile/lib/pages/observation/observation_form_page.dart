import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../models/observation_detail_model.dart';
import '../../models/observation_tran_model.dart';
import '../../services/api.dart';
import '../../services/database.dart';
import '../../services/preference.dart';
import '../../services/sync.dart';
import '../../utils/app_date_time_picker.dart';
import '../../utils/globals.dart' as globals;
import '../../utils/helpers.dart';
import '../../widgets/professional_success_sheet.dart';
import '../../widgets/sap_form_widgets.dart';
import '../../widgets/snackbar_msg.dart';
import '../../widgets/top_bar.dart';
import '../home_page.dart';

class ObservationFormPage extends StatefulWidget {
  const ObservationFormPage({this.editData, super.key});
  final Map<String, dynamic>? editData;

  @override
  State<ObservationFormPage> createState() => _ObservationFormPageState();
}

class _ObservationFormPageState extends State<ObservationFormPage> {
  static const Color primaryBlue = Color(0xFF0284C7);

  final _scrollCtrl = ScrollController();
  final _db = DatabaseService();
  final _api = ApiService();
  final _profile = PreferenceService.getProfile();
  final _locationDetail = TextEditingController();
  final _subject = TextEditingController();
  final _findingRemark = TextEditingController();

  final List<dynamic> _rawData = [];
  List<MapEntry<String, dynamic>> _penilaianList = [];
  final List<MapEntry<int, dynamic>> _deptList = [];
  final List<MapEntry<int, dynamic>> _docList = [];
  final List<MapEntry<int, dynamic>> _riskList = [];
  final List<MapEntry<int, dynamic>> _areaList = [];
  List<MapEntry<int, dynamic>> _locationList = [];
  DateTime? _date = DateTime.now();
  String? _time = DateFormat('HH:mm').format(DateTime.now());
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

  // Findings list and bottom sheet state
  final List<ObservationDetailModel> _itemList = [];
  int? _modalPerihalId;
  int? _modalHasilId;
  String? _modalImage;
  int _pointCounter = 0;

  bool _loadingOptions = true;
  bool _loadingDepts = false;
  bool _isSaving = false;
  String? _optionsError;

  @override
  void initState() {
    super.initState();
    _companyId = widget.editData?['company_id'] as int? ?? _profile?.companyId;
    if (widget.editData != null) {
      _subject.text = widget.editData!['title']?.toString() ??
          widget.editData!['subject']?.toString() ??
          '';
      _locationDetail.text =
          widget.editData!['location_detail']?.toString() ?? '';
      _date = DateTime.tryParse(widget.editData!['date']?.toString() ?? '') ??
          _date;
      final savedTime = widget.editData!['time']?.toString();
      if (savedTime != null && savedTime.isNotEmpty) {
        _time = savedTime;
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.editData == null) {
        _fillGpsFromDevice(silent: true);
      }
      _loadObservationOptions(_companyId);
      if (widget.editData != null) {
        _loadEditDetails();
      }

      _db.rawQuery('''select
        id id_dokumen_pendukung,
        "name" dokumen_pendukung
      from observation_masters om 
      where om.deleted_at is null and type = 'document'
      order by om."name"''').then((val) {
        if (val.isNotEmpty && mounted) {
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
        if (val.isNotEmpty && mounted) {
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
        if (val.isNotEmpty && mounted) {
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
    if (tranId == null) {
      if (widget.editData!['perihal'] != null) {
        setState(() {
          _itemList.add(ObservationDetailModel(
            point: widget.editData!['perihal']?.toString(),
            type: widget.editData!['hasil']?.toString(),
            remark: widget.editData!['remark']?.toString(),
            image: widget.editData!['image']?.toString(),
          ));
        });
      }
      return;
    }

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
        _itemList.clear();
        if (_editDetails.isNotEmpty) {
          _itemList.addAll(_editDetails);
        } else if (widget.editData!['perihal'] != null) {
          _itemList.add(ObservationDetailModel(
            point: widget.editData!['perihal']?.toString(),
            type: widget.editData!['hasil']?.toString(),
            remark: widget.editData!['remark']?.toString(),
            image: widget.editData!['image']?.toString(),
          ));
        }
      });
    } catch (_) {}
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
    Map<String, dynamic>? data =
        onlineData ?? PreferenceService.getObservationOptionsCache();
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
          where om.deleted_at is null and (om.type = 'subject' or om.type = 'point') order by om."name"''');

        if (depts.isNotEmpty || docs.isNotEmpty || areasRows.isNotEmpty) {
          data = {
            'departments':
                depts.map((r) => {'id': r['id'], 'name': r['name']}).toList(),
            'documents':
                docs.map((r) => {'id': r['id'], 'name': r['name']}).toList(),
            'criticalRisks':
                risks.map((r) => {'id': r['id'], 'name': r['name']}).toList(),
            'areas': areasRows
                .map((r) => {'id': r['id'], 'name': r['name']})
                .toList(),
            'locations': locRows
                .map((r) =>
                    {'id': r['id'], 'name': r['name'], 'area': r['area']})
                .toList(),
            'companies': comps.isNotEmpty
                ? comps.map((r) => {'id': r['id'], 'name': r['name']}).toList()
                : [
                    {'id': 1, 'name': 'PT INDEXIM COALINDO'}
                  ],
            'riskLevels': [
              {'id': 1, 'name': 'Low'},
              {'id': 2, 'name': 'Medium'},
              {'id': 3, 'name': 'High'},
              {'id': 4, 'name': 'Critical'},
            ],
            'subjects': subjects.isNotEmpty
                ? subjects
                    .map((r) => {'id': r['id'], 'name': r['name']})
                    .toList()
                : [
                    {'id': 1, 'name': 'Pengoperasian Kendaraan / Unit'},
                    {'id': 2, 'name': 'Bekerja di Ketinggian'},
                    {'id': 3, 'name': 'Housekeeping'}
                  ],
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
        _companyDeptMap =
            Map<String, dynamic>.from(options['companyDeptMap'] as Map);
      }

      // Populate departments for the active company
      List<MapEntry<int, dynamic>> depts = [];
      if (companyId != null && companyId > 0 && _companyDeptMap.isNotEmpty) {
        final list = _companyDeptMap[companyId.toString()];
        if (list is List && list.isNotEmpty) {
          final strings = list
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList();
          depts = List.generate(
              strings.length, (i) => MapEntry(i + 1, strings[i]));
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
      final seenLevels = <String>{};
      final cleanLevels = <MapEntry<String, dynamic>>[];
      for (final entry in _entries(options, 'riskLevels')) {
        var str = entry.value.toString().trim();
        if (str.toLowerCase() == 'low') {
          str = 'Rendah';
        } else if (str.toLowerCase() == 'medium') {
          str = 'Sedang';
        } else if (str.toLowerCase() == 'high') {
          str = 'Tinggi';
        } else if (str.toLowerCase() == 'critical' ||
            str.toLowerCase() == 'extreme') {
          str = 'Ekstrim';
        }
        if (str.isNotEmpty && seenLevels.add(str.toLowerCase())) {
          cleanLevels.add(MapEntry(str, str));
        }
      }
      _penilaianList = cleanLevels.isNotEmpty
          ? cleanLevels
          : [
              const MapEntry('Rendah', 'Rendah'),
              const MapEntry('Sedang', 'Sedang'),
              const MapEntry('Tinggi', 'Tinggi'),
              const MapEntry('Ekstrim', 'Ekstrim'),
            ];
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

  /// Dynamically update departments when user picks an observed company.
  Future<void> _updateDepartmentsForCompany(int companyId) async {
    setState(() => _loadingDepts = true);
    List<String> deptNames = [];

    if (_companyDeptMap.isNotEmpty) {
      final raw = _companyDeptMap[companyId.toString()];
      if (raw is List && raw.isNotEmpty) {
        deptNames = raw
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }

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
    _scrollCtrl.dispose();
    _locationDetail.dispose();
    _subject.dispose();
    _findingRemark.dispose();
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

  void _prepareNewDetail() {
    _pointCounter++;
    _modalPerihalId = null;
    _modalHasilId = null;
    _findingRemark.clear();
    _modalImage = null;
  }

  int? _findPointId(String? point) => _perihalOptions
      .where((item) => item.value.toString() == (point ?? ''))
      .firstOrNull
      ?.key;

  int? _findResultId(String? result) {
    final value = (result ?? '').trim().toUpperCase();
    return _hasilOptions
        .where((item) {
          final candidate = item.value.toString().trim().toUpperCase();
          return candidate == value ||
              (value.isNotEmpty && candidate.startsWith(value.substring(0, 1)));
        })
        .firstOrNull
        ?.key;
  }

  Color _getResultBadgeColor(String? typeStr) {
    final t = (typeStr ?? '').toUpperCase();
    if (t.contains('P') ||
        t.contains('SAFE') ||
        t.contains('AMAN') ||
        t.contains('POSITIF') ||
        t.contains('POSITIVE')) {
      return const Color(0xFF16A34A);
    } else if (t.contains('I') ||
        t.contains('IMPROVE') ||
        t.contains('PERBAIKAN')) {
      return const Color(0xFFD97706);
    } else {
      return const Color(0xFFDC2626);
    }
  }

  String _getResultLabel(String? typeStr) {
    final t = (typeStr ?? '').toUpperCase();
    if (t.contains('P') ||
        t.contains('SAFE') ||
        t.contains('AMAN') ||
        t.contains('POSITIF') ||
        t.contains('POSITIVE')) {
      return 'AMAN (SAFE)';
    } else if (t.contains('I') ||
        t.contains('IMPROVE') ||
        t.contains('PERBAIKAN')) {
      return 'PERBAIKAN';
    } else {
      return 'BERISIKO (AT-RISK)';
    }
  }

  Widget _observationImagePreview(String path,
      {double? height, BoxFit fit = BoxFit.cover}) {
    final source = path.trim();
    final remote = source.startsWith('http://') ||
        source.startsWith('https://') ||
        source.startsWith('/uploads/') ||
        source.startsWith('uploads/') ||
        source.startsWith('~/uploads/');
    final remoteUrl =
        source.startsWith('http://') || source.startsWith('https://')
            ? source
            : '${_api.mbsWebUrl}/${source.replaceFirst(RegExp(r'^~?/+'), '')}';
    final image = remote
        ? Image.network(
            remoteUrl,
            width: double.infinity,
            height: height ?? double.infinity,
            fit: fit,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFFF1F5F9),
              child: const Center(
                child: Icon(Icons.broken_image_rounded,
                    color: Color(0xFF94A3B8), size: 28),
              ),
            ),
          )
        : Image.file(
            File(source),
            width: double.infinity,
            height: height ?? double.infinity,
            fit: fit,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFFF1F5F9),
              child: const Center(
                child: Icon(Icons.broken_image_rounded,
                    color: Color(0xFF94A3B8), size: 28),
              ),
            ),
          );
    return ClipRRect(borderRadius: BorderRadius.circular(10), child: image);
  }

  void _showImageSourcePicker(void Function(void Function()) setStateModal) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Pilih Sumber Foto',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Ambil foto temuan perilaku atau kondisi kerja yang diamati',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        pickImage(source: ImageSource.camera).then((file) {
                          if (file != null) {
                            setStateModal(() => _modalImage = file.path);
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.photo_camera_rounded,
                                color: Color(0xFF16A34A), size: 30),
                            SizedBox(height: 8),
                            Text(
                              'Kamera',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF065F46),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        pickImage(source: ImageSource.gallery).then((file) {
                          if (file != null) {
                            setStateModal(() => _modalImage = file.path);
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.photo_library_rounded,
                                color: Color(0xFF2563EB), size: 30),
                            SizedBox(height: 8),
                            Text(
                              'Galeri',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E40AF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Future<dynamic> _showFindingBottomSheet({int? editIndex}) {
    final editing = editIndex != null;
    final oldDetail = editing ? _itemList[editIndex] : null;
    if (editing) {
      _modalPerihalId = _findPointId(oldDetail?.point);
      _modalHasilId = _findResultId(oldDetail?.type);
      _findingRemark.text = oldDetail?.remark ?? '';
      _modalImage = oldDetail?.image;
      _pointCounter = oldDetail?.pointId ?? _pointCounter;
    }

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return StatefulBuilder(builder: (context, setStateModal) {
          final isModalValid = _modalPerihalId != null &&
              _modalHasilId != null &&
              _findingRemark.text.trim().isNotEmpty;

          return FractionallySizedBox(
            heightFactor: 0.92,
            child: SafeArea(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 16, 14),
                    decoration: const BoxDecoration(
                      border:
                          Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                    ),
                    child: Column(
                      children: [
                        Center(
                          child: Container(
                            width: 38,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFCBD5E1),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.visibility_rounded,
                                color: primaryBlue,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    editing
                                        ? 'Edit Temuan Observasi'
                                        : 'Tambah Temuan Observasi',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const Text(
                                    'Pilih perihal perilaku, hasil observasi, dan dokumentasi',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  color: Color(0xFF64748B), size: 20),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        20,
                        16,
                        20,
                        24 + MediaQuery.of(context).viewInsets.bottom,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PERIHAL YANG DIOBSERVASI *',
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownSearch<MapEntry<int, dynamic>>(
                            selectedItem: _perihalOptions
                                .where((item) => item.key == _modalPerihalId)
                                .firstOrNull,
                            items: _perihalOptions,
                            itemAsString: (item) => item.value.toString(),
                            dropdownDecoratorProps: DropDownDecoratorProps(
                              dropdownSearchDecoration: InputDecoration(
                                hintText: 'Pilih perihal yang diamati...',
                                hintStyle: const TextStyle(
                                    color: Color(0xFF94A3B8), fontSize: 13),
                                prefixIcon: const Icon(
                                    Icons.visibility_outlined,
                                    color: primaryBlue,
                                    size: 20),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                              ),
                            ),
                            popupProps: const PopupProps.menu(
                              fit: FlexFit.loose,
                              showSearchBox: true,
                              searchFieldProps: TextFieldProps(
                                decoration: InputDecoration(
                                  hintText: 'Cari perihal yang diobservasi...',
                                  prefixIcon: Icon(Icons.search_rounded),
                                ),
                              ),
                            ),
                            onChanged: (item) {
                              if (item == null) return;
                              setStateModal(() => _modalPerihalId = item.key);
                            },
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'HASIL OBSERVASI *',
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownSearch<MapEntry<int, dynamic>>(
                            selectedItem: _hasilOptions
                                .where((item) => item.key == _modalHasilId)
                                .firstOrNull,
                            items: _hasilOptions,
                            itemAsString: (item) => item.value.toString(),
                            dropdownDecoratorProps: DropDownDecoratorProps(
                              dropdownSearchDecoration: InputDecoration(
                                hintText:
                                    'Pilih hasil evaluasi observasi...',
                                hintStyle: const TextStyle(
                                    color: Color(0xFF94A3B8), fontSize: 13),
                                prefixIcon: const Icon(
                                    Icons.fact_check_outlined,
                                    color: primaryBlue,
                                    size: 20),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                              ),
                            ),
                            popupProps: const PopupProps.menu(
                              fit: FlexFit.loose,
                              showSearchBox: true,
                              searchFieldProps: TextFieldProps(
                                decoration: InputDecoration(
                                  hintText: 'Cari hasil observasi...',
                                  prefixIcon: Icon(Icons.search_rounded),
                                ),
                              ),
                            ),
                            onChanged: (item) {
                              if (item == null) return;
                              setStateModal(() => _modalHasilId = item.key);
                            },
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'KETERANGAN / TINDAKAN *',
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _findingRemark,
                            minLines: 3,
                            maxLines: 4,
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              hintText:
                                  'Tuliskan detail pengamatan perilaku atau tindakan koreksi yang dilakukan...',
                              hintStyle: const TextStyle(
                                  color: Color(0xFF94A3B8), fontSize: 12.5),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: primaryBlue, width: 1.5),
                              ),
                            ),
                            onChanged: (_) => setStateModal(() {}),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'DOKUMENTASI FOTO (OPSIONAL)',
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () =>
                                _showImageSourcePicker(setStateModal),
                            borderRadius: BorderRadius.circular(14),
                            child: _modalImage == null || _modalImage == ''
                                ? Container(
                                    width: double.infinity,
                                    height: 115,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                          color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE0F2FE),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color:
                                                    const Color(0xFFBAE6FD)),
                                          ),
                                          child: const Icon(
                                            Icons.camera_alt_rounded,
                                            color: primaryBlue,
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Ambil atau Unggah Foto Temuan',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        const Text(
                                          'Ketuk untuk membuka Kamera atau Galeri ponsel',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : Container(
                                    width: double.infinity,
                                    height: 160,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                          color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: _observationImagePreview(
                                              _modalImage!,
                                              height: 160),
                                        ),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: InkWell(
                                            onTap: () => setStateModal(
                                                () => _modalImage = null),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Colors.black
                                                    .withValues(alpha: 0.65),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.close_rounded,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 8,
                                          right: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.black
                                                  .withValues(alpha: 0.65),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.cached_rounded,
                                                    color: Colors.white,
                                                    size: 14),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Ganti Foto',
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton.icon(
                              icon: Icon(editing
                                  ? Icons.check_rounded
                                  : Icons.add_rounded),
                              label: Text(
                                editing
                                    ? 'Simpan Perubahan'
                                    : 'Tambahkan Temuan',
                                style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: isModalValid
                                    ? primaryBlue
                                    : const Color(0xFFCBD5E1),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: !isModalValid
                                  ? null
                                  : () {
                                      var point = _perihalOptions
                                          .where((i) =>
                                              i.key == _modalPerihalId)
                                          .firstOrNull
                                          ?.value
                                          ?.toString() ??
                                          'Observasi Perilaku';
                                      var type = _hasilOptions
                                          .where((i) => i.key == _modalHasilId)
                                          .firstOrNull
                                          ?.value
                                          ?.toString() ??
                                          'Aman';

                                      final detail = ObservationDetailModel(
                                        name: '$point - $type',
                                        point: point,
                                        type: type.isNotEmpty
                                            ? type.substring(0, 1)
                                            : 'A',
                                        image: _modalImage,
                                        remark: _findingRemark.text.trim(),
                                        pointId: editing
                                            ? oldDetail?.pointId
                                            : _pointCounter,
                                        id: oldDetail?.id,
                                        tranId: oldDetail?.tranId,
                                        refId: oldDetail?.refId,
                                        syncId: oldDetail?.syncId,
                                      );

                                      setState(() {
                                        if (editing) {
                                          _itemList[editIndex] = detail;
                                        } else {
                                          _itemList.add(detail);
                                        }
                                        _modalPerihalId = null;
                                        _modalHasilId = null;
                                        _modalImage = null;
                                        _findingRemark.clear();
                                      });
                                      Navigator.pop(context);
                                    },
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
        });
      },
    );
  }

  Future<void> _saveObservation() async {
    if (_isSaving || _itemList.isEmpty) return;
    setState(() => _isSaving = true);
    SnackBarMsg.loader(context, true);

    try {
      final now = DateTime.now();
      final dateStr = _date != null
          ? DateFormat('yyyy-MM-dd').format(_date!)
          : DateFormat('yyyy-MM-dd').format(now);
      final timeStr = _time ?? DateFormat('HH:mm').format(now);
      final codeStr =
          '${_profile?.noNik ?? "EMP"}-${now.millisecondsSinceEpoch}0000000000'
              .substring(0, 24);

      final areaName = _areaList
              .where((i) => i.key == _areaId)
              .firstOrNull
              ?.value
              ?.toString() ??
          '';
      final locName = _locationList
              .where((i) => i.key == _locationId)
              .firstOrNull
              ?.value
              ?.toString() ??
          '';
      final compName = _companyOptions
              .where((i) => i.key == _companyId)
              .firstOrNull
              ?.value
              ?.toString() ??
          '';
      final deptName = _deptList
              .where((i) => i.key == _deptId)
              .firstOrNull
              ?.value
              ?.toString() ??
          '';
      final docName = _docList
              .where((i) => i.key == _docId)
              .firstOrNull
              ?.value
              ?.toString() ??
          '';
      final riskName = _riskList
              .where((i) => i.key == _riskId)
              .firstOrNull
              ?.value
              ?.toString() ??
          '';

      final serverId = widget.editData?['sync_id'] as int?;

      final observation = ObservationTrnModel(
        id: int.tryParse(widget.editData?['id']?.toString() ?? ''),
        refId: int.tryParse(widget.editData?['ref_id']?.toString() ?? ''),
        syncId: serverId,
        code: codeStr,
        title: _subject.text.trim(),
        companyId: _companyId,
        companyName: compName,
        employeeId: _profile?.id,
        deptId: _deptId,
        areaId: _areaId,
        locationId: _locationId,
        locationDetail: _locationDetail.text.trim(),
        date: dateStr,
        time: timeStr,
        subject: _subject.text.trim(),
        activity: _penilaianId,
        createdAt: now.toString(),
        updatedAt: now.toString(),
        docId: _docId,
        riskId: _riskId,
        area: areaName,
        lokasi: locName,
        deptName: deptName,
        docName: docName,
        riskName: riskName,
        riskLevel: _penilaianId,
        remark: docName,
      );

      if (serverId != null) {
        final updated = await _saveEditedObservation(observation, serverId);
        if (!mounted) return;
        SnackBarMsg.loader(context, false);
        if (updated) {
          await showProfessionalSuccessSheet(
            context: context,
            title: 'Observasi Diperbarui',
            subtitle:
                'Perubahan data observasi perilaku telah berhasil disimpan ke sistem.',
            accentColor: primaryBlue,
            icon: Icons.check_circle_rounded,
            statusBadgeText: 'TERCATAT & TERSIMPAN',
            primaryButtonText: 'Selesai & Ke Beranda',
            receiptItems: [
              const SuccessReceiptItem(
                label: 'Program SAP',
                value: 'Safety Observation (BBS)',
                icon: Icons.visibility_rounded,
              ),
              SuccessReceiptItem(
                label: 'Jumlah Temuan',
                value: '${_itemList.length} Poin Temuan',
                icon: Icons.fact_check_rounded,
                isHighlight: true,
                highlightColor: primaryBlue,
              ),
            ],
            onPrimaryAction: () => _goHome(),
          );
          _goHome();
        } else {
          SnackBarMsg.danger(context,
              'Pembaruan belum berhasil. Periksa koneksi internet lalu coba lagi.');
        }
        return;
      }

      final tranId =
          await _db.insert('observation_trans', observation.toJson());
      if (tranId <= 0) {
        if (mounted) {
          SnackBarMsg.loader(context, false);
          SnackBarMsg.danger(
              context, 'Data observasi gagal disimpan ke database lokal.');
        }
        return;
      }

      for (final row in _itemList) {
        row.tranId = tranId;
        row.status = 0;
        await _db.insert('observation_details', row.toJson());
      }

      final synced = await syncTran(_db, _api, 'observation', tranId);
      if (!mounted) return;
      SnackBarMsg.loader(context, false);

      await showProfessionalSuccessSheet(
        context: context,
        title:
            synced ? 'Observasi Berhasil Disimpan' : 'Data Tersimpan Offline',
        subtitle: synced
            ? 'Seluruh hasil observasi dan bukti foto telah tercatat di server.'
            : 'Data tersimpan aman di perangkat dan akan disinkronkan otomatis saat ada jaringan.',
        accentColor: primaryBlue,
        icon: Icons.check_circle_rounded,
        statusBadgeText: synced ? 'TERCATAT & TERSINKRON' : 'TERSIMPAN OFFLINE',
        isOffline: !synced,
        primaryButtonText: 'Selesai & Ke Beranda',
        receiptItems: [
          const SuccessReceiptItem(
            label: 'Program SAP',
            value: 'Safety Observation (BBS)',
            icon: Icons.visibility_rounded,
          ),
          SuccessReceiptItem(
            label: 'Waktu Observasi',
            value: '${observation.date ?? "-"} ${observation.time ?? ""}',
            icon: Icons.access_time_rounded,
          ),
          SuccessReceiptItem(
            label: 'Perusahaan',
            value: observation.companyName ?? '-',
            icon: Icons.business_rounded,
          ),
          SuccessReceiptItem(
            label: 'Area / Lokasi',
            value:
                '${observation.area ?? "-"} • ${observation.lokasi ?? "-"}',
            icon: Icons.place_rounded,
          ),
          SuccessReceiptItem(
            label: 'Jumlah Temuan',
            value: '${_itemList.length} Poin Temuan',
            icon: Icons.fact_check_rounded,
            isHighlight: true,
            highlightColor: primaryBlue,
          ),
          SuccessReceiptItem(
            label: 'Tingkat Risiko',
            value: observation.riskLevel ?? '-',
            icon: Icons.shield_rounded,
          ),
        ],
        onPrimaryAction: () => _goHome(),
      );
      if (!mounted) return;
      _goHome();
    } catch (e) {
      debugPrint('Observation save failed: $e');
      if (mounted) {
        SnackBarMsg.loader(context, false);
        SnackBarMsg.danger(
            context, 'Terjadi kendala saat menyimpan observasi: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _goHome() {
    if (!mounted) return;
    SnackBarMsg.loader(context, false);
    globals.currentPage = 0;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }

  Future<bool> _saveEditedObservation(
      ObservationTrnModel obs, int editServerId) async {
    for (var index = 0; index < _itemList.length; index++) {
      final detail = _itemList[index];
      final serverId = detail.syncId ??
          detail.refId ??
          (index == 0 ? editServerId : null);
      if (serverId == null) return false;

      final payload = <String, dynamic>{
        'kegiatan_yang_diamati': obs.subject ?? '',
        'area': obs.area ?? '',
        'lokasi': obs.lokasi ?? '',
        'detil_lokasi': obs.locationDetail ?? '',
        'tanggal': obs.date ?? '',
        'waktu': obs.time ?? '',
        'perusahaan_id': obs.companyId?.toString() ?? '',
        'perusahaan_yang_diamati': obs.companyName ?? '',
        'departemen_yang_diamati': obs.deptName ?? '',
        'dokumen_pendukung': obs.docName ?? '',
        'resiko_kritis': obs.riskName ?? '',
        'tingkat_resiko': obs.riskLevel ?? '',
        'perihal_yang_diamati': detail.point ?? detail.name ?? '',
        'hasil_observasi': detail.type ?? '',
        'keterangan': detail.remark ?? '',
      };
      final imagePath = detail.image;
      if (imagePath != null &&
          imagePath.isNotEmpty &&
          await File(imagePath).exists()) {
        payload['image'] = await MultipartFile.fromFile(imagePath);
      }
      final updated = await _api.updateObservation(serverId, payload);
      if (!updated) return false;

      if (detail.id != null) {
        await _db.update('observation_details', detail.toJson(), detail.id!);
      }
    }
    final localObservationId = obs.id;
    if (localObservationId != null) {
      await _db.update('observation_trans', obs.toJson(), localObservationId);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final isHeaderValid = _deptId != null &&
        _docId != null &&
        _riskId != null &&
        _areaId != null &&
        _locationId != null &&
        _locationDetail.text.trim().isNotEmpty &&
        _subject.text.trim().isNotEmpty &&
        _penilaianId != null;

    final canSave = isHeaderValid && _itemList.isNotEmpty && !_isSaving;

    return PopScope(
      canPop: true,
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
                          subtitle:
                              'Catat observasi perilaku, kondisi lingkungan, dan kepatuhan K3.',
                          icon: Icons.fact_check_rounded,
                          accentColor: primaryBlue,
                          badgeBgColor: Color(0xFFF0F9FF),
                          badgeBorderColor: Color(0xFFE0F2FE),
                        ),

                        // SECTION 1: Waktu & Lokasi
                        SapSectionCard(
                          stepNumber: '1',
                          title: 'WAKTU & LOKASI OBSERVASI',
                          subtitle:
                              'Tanggal, jam, perusahaan dan titik lokasi pengamatan',
                          icon: Icons.location_on_rounded,
                          accentColor: primaryBlue,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: SapDatePickerTile(
                                    label: 'Tanggal Observasi',
                                    date: _date ?? DateTime.now(),
                                    onTap: () async {
                                      final picked =
                                          await AppDateTimePicker
                                              .showDatePickerDialog(
                                        context: context,
                                        initialDate: _date,
                                        restrict3DaysBack: true,
                                      );
                                      if (picked != null) {
                                        setState(() => _date = picked);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SapTimePickerTile(
                                    label: 'Waktu Observasi',
                                    timeText: _time ??
                                        DateFormat('HH:mm')
                                            .format(DateTime.now()),
                                    onTap: () async {
                                      final picked =
                                          await AppDateTimePicker
                                              .showTimePickerDialog(
                                        context: context,
                                      );
                                      if (picked != null) {
                                        final hh = picked.hour
                                            .toString()
                                            .padLeft(2, '0');
                                        final mm = picked.minute
                                            .toString()
                                            .padLeft(2, '0');
                                        setState(() => _time = '$hh:$mm');
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            const Text('PERUSAHAAN YANG DIAMATI *',
                                style: TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5)),
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
                                  hintStyle: const TextStyle(
                                      color: Color(0xFF94A3B8), fontSize: 13),
                                  prefixIcon: const Icon(
                                      Icons.business_rounded,
                                      color: primaryBlue,
                                      size: 20),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFE2E8F0))),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFE2E8F0))),
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

                            const Text('AREA UTAMA *',
                                style: TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5)),
                            const SizedBox(height: 6),
                            DropdownSearch<MapEntry<int, dynamic>>(
                              selectedItem: _areaList
                                  .where((item) => item.key == _areaId)
                                  .firstOrNull,
                              items: _areaList,
                              itemAsString: (item) => item.value.toString(),
                              dropdownDecoratorProps: DropDownDecoratorProps(
                                dropdownSearchDecoration: InputDecoration(
                                  hintText: 'Pilih Area Utama...',
                                  hintStyle: const TextStyle(
                                      color: Color(0xFF94A3B8), fontSize: 13),
                                  prefixIcon: const Icon(Icons.map_rounded,
                                      color: primaryBlue, size: 20),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFE2E8F0))),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFE2E8F0))),
                                ),
                              ),
                              popupProps: const PopupProps.menu(
                                fit: FlexFit.loose,
                                showSearchBox: true,
                                searchFieldProps: TextFieldProps(
                                  decoration: InputDecoration(
                                    hintText: 'Cari area utama...',
                                    prefixIcon: Icon(Icons.search_rounded),
                                  ),
                                ),
                              ),
                              onChanged: (item) {
                                if (item != null) {
                                  setState(() => _getLocation(item.key));
                                }
                              },
                            ),
                            const SizedBox(height: 14),

                            const Text('DETAIL LOKASI / BENCHMARK *',
                                style: TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5)),
                            const SizedBox(height: 6),
                            DropdownSearch<MapEntry<int, dynamic>>(
                              selectedItem: _locationList
                                  .where((item) => item.key == _locationId)
                                  .firstOrNull,
                              items: _locationList,
                              enabled: _areaId != null,
                              itemAsString: (item) => item.value.toString(),
                              dropdownDecoratorProps: DropDownDecoratorProps(
                                dropdownSearchDecoration: InputDecoration(
                                  hintText: _areaId == null
                                      ? 'Pilih Area Utama terlebih dahulu...'
                                      : (_locationList.isEmpty
                                          ? '(Tidak ada benchmark di area ini)'
                                          : 'Pilih Detail Lokasi / Benchmark...'),
                                  hintStyle: const TextStyle(
                                      color: Color(0xFF94A3B8), fontSize: 13),
                                  prefixIcon: const Icon(
                                      Icons.place_rounded,
                                      color: primaryBlue,
                                      size: 20),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFE2E8F0))),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFE2E8F0))),
                                  disabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFE2E8F0))),
                                ),
                              ),
                              popupProps: const PopupProps.menu(
                                fit: FlexFit.loose,
                                showSearchBox: true,
                                searchFieldProps: TextFieldProps(
                                  decoration: InputDecoration(
                                    hintText: 'Cari lokasi / benchmark...',
                                    prefixIcon: Icon(Icons.search_rounded),
                                  ),
                                ),
                              ),
                              onChanged: (item) {
                                if (item != null) {
                                  setState(() => _locationId = item.key);
                                }
                              },
                            ),
                            const SizedBox(height: 6),
                            AddCustomLocationButton(
                                onPressed: _addCustomLocation),
                            const SizedBox(height: 12),

                            const Text('LOKASI SPESIFIK / GPS',
                                style: TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5)),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _locationDetail,
                              decoration: gpsInputDecoration(
                                context: context,
                                onPressed: () => _fillGpsFromDevice(),
                                iconColor: primaryBlue,
                              ).copyWith(
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFE2E8F0))),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFE2E8F0))),
                              ),
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF0F172A)),
                              onChanged: (_) => setState(() {}),
                            ),
                          ],
                        ),

                        // SECTION 2: Kegiatan & Risiko
                        SapSectionCard(
                          stepNumber: '2',
                          title: 'KEGIATAN & KLASIFIKASI RISIKO',
                          subtitle:
                              'Aktivitas yang diamati, departemen terkait dan tingkat risiko',
                          icon: Icons.shield_outlined,
                          accentColor: const Color(0xFFD97706),
                          children: [
                            const Text('KEGIATAN YANG DIAMATI *',
                                style: TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5)),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _subject,
                              decoration: InputDecoration(
                                hintText:
                                    'Contoh: Pengelasan pipa di Workshop Mitra',
                                hintStyle: const TextStyle(
                                    color: Color(0xFF94A3B8), fontSize: 13),
                                prefixIcon: const Icon(
                                    Icons.content_paste_search_rounded,
                                    color: Color(0xFFD97706),
                                    size: 20),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFE2E8F0))),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFE2E8F0))),
                              ),
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF0F172A),
                                  fontWeight: FontWeight.w600),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 14),

                            const Text('DEPARTEMEN PEKERJAAN *',
                                style: TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5)),
                            const SizedBox(height: 6),
                            DropdownSearch<MapEntry<int, dynamic>>(
                              selectedItem: _deptList
                                  .where((e) => e.key == _deptId)
                                  .firstOrNull,
                              items: _deptList.toList(),
                              enabled: !_loadingDepts && _companyId != null,
                              itemAsString: (MapEntry<int, dynamic>? e) =>
                                  e?.value ?? '',
                              dropdownDecoratorProps: DropDownDecoratorProps(
                                dropdownSearchDecoration: InputDecoration(
                                  hintText: _loadingDepts
                                      ? 'Memuat departemen...'
                                      : (_companyId == null
                                          ? 'Pilih Perusahaan terlebih dahulu...'
                                          : (_deptList.isEmpty
                                              ? '(Tidak ada departemen terdaftar)'
                                              : 'Pilih Departemen...')),
                                  hintStyle: const TextStyle(
                                      color: Color(0xFF94A3B8), fontSize: 13),
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
                                      : const Icon(
                                          Icons.corporate_fare_rounded,
                                          color: Color(0xFFD97706),
                                          size: 20),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFE2E8F0))),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFE2E8F0))),
                                  disabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFE2E8F0))),
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
                                if (val != null) {
                                  setState(() => _deptId = val.key);
                                }
                              },
                            ),
                            const SizedBox(height: 14),

                            const Text('DOKUMEN PENDUKUNG *',
                                style: TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5)),
                            const SizedBox(height: 6),
                            DropdownSearch<MapEntry<int, dynamic>>(
                              selectedItem: _docList
                                  .where((item) => item.key == _docId)
                                  .firstOrNull,
                              items: _docList,
                              itemAsString: (item) => item.value.toString(),
                              dropdownDecoratorProps: DropDownDecoratorProps(
                                dropdownSearchDecoration: InputDecoration(
                                  hintText:
                                      'Pilih Dokumen Pendukung (IK/SOP)...',
                                  hintStyle: const TextStyle(
                                      color: Color(0xFF94A3B8), fontSize: 13),
                                  prefixIcon: const Icon(
                                      Icons.description_rounded,
                                      color: primaryBlue,
                                      size: 20),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFE2E8F0))),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFE2E8F0))),
                                ),
                              ),
                              popupProps: const PopupProps.menu(
                                fit: FlexFit.loose,
                                showSearchBox: true,
                                searchFieldProps: TextFieldProps(
                                  decoration: InputDecoration(
                                    hintText: 'Cari dokumen...',
                                    prefixIcon: Icon(Icons.search_rounded),
                                  ),
                                ),
                              ),
                              onChanged: (item) {
                                if (item != null) {
                                  setState(() => _docId = item.key);
                                }
                              },
                            ),
                            const SizedBox(height: 14),

                            const Text('RISIKO KRITIS *',
                                style: TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5)),
                            const SizedBox(height: 6),
                            DropdownSearch<MapEntry<int, dynamic>>(
                              selectedItem: _riskList
                                  .where((item) => item.key == _riskId)
                                  .firstOrNull,
                              items: _riskList,
                              itemAsString: (item) => item.value.toString(),
                              dropdownDecoratorProps: DropDownDecoratorProps(
                                dropdownSearchDecoration: InputDecoration(
                                  hintText: 'Pilih Risiko Kritis Terkait...',
                                  hintStyle: const TextStyle(
                                      color: Color(0xFF94A3B8), fontSize: 13),
                                  prefixIcon: const Icon(
                                      Icons.warning_amber_rounded,
                                      color: primaryBlue,
                                      size: 20),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFE2E8F0))),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFE2E8F0))),
                                ),
                              ),
                              popupProps: const PopupProps.menu(
                                fit: FlexFit.loose,
                                showSearchBox: true,
                                searchFieldProps: TextFieldProps(
                                  decoration: InputDecoration(
                                    hintText: 'Cari risiko kritis...',
                                    prefixIcon: Icon(Icons.search_rounded),
                                  ),
                                ),
                              ),
                              onChanged: (item) {
                                if (item != null) {
                                  setState(() => _riskId = item.key);
                                }
                              },
                            ),
                            const SizedBox(height: 14),

                            const Text('PENILAIAN TINGKAT RISIKO *',
                                style: TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _penilaianList.map((item) {
                                final isSel = _penilaianId == item.key;
                                Color badgeColor = primaryBlue;
                                final lower =
                                    item.value.toString().toLowerCase();
                                if (lower.contains('critical') ||
                                    lower.contains('ekstrim') ||
                                    lower.contains('extreme')) {
                                  badgeColor = const Color(0xFFDC2626);
                                } else if (lower.contains('high') ||
                                    lower.contains('tinggi')) {
                                  badgeColor = const Color(0xFFEA580C);
                                } else if (lower.contains('medium') ||
                                    lower.contains('sedang')) {
                                  badgeColor = const Color(0xFFD97706);
                                } else {
                                  badgeColor = const Color(0xFF16A34A);
                                }

                                return InkWell(
                                  onTap: () => setState(
                                      () => _penilaianId = item.key),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSel
                                          ? badgeColor
                                          : const Color(0xFFF8FAFC),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      border: Border.all(
                                          color: isSel
                                              ? badgeColor
                                              : const Color(0xFFE2E8F0)),
                                    ),
                                    child: Text(
                                      item.value.toString(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSel
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                        color: isSel
                                            ? Colors.white
                                            : const Color(0xFF334155),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),

                        // SECTION 3: Detail Temuan Observasi
                        SapSectionCard(
                          stepNumber: '3',
                          title: 'DETAIL TEMUAN OBSERVASI',
                          subtitle:
                              'Evaluasi perilaku kerja aman atau berisiko beserta bukti temuan',
                          icon: Icons.playlist_add_check_rounded,
                          accentColor: const Color(0xFF059669),
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(10),
                                    border:
                                        Border.all(color: const Color(0xFFA7F3D0)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                          Icons.check_circle_outline_rounded,
                                          size: 13,
                                          color: Color(0xFF059669)),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${_itemList.length} Temuan Dicatat',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF059669),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_itemList.isNotEmpty)
                                  TextButton.icon(
                                    onPressed: () {
                                      _prepareNewDetail();
                                      _showFindingBottomSheet();
                                    },
                                    icon: const Icon(Icons.add_rounded,
                                        size: 16, color: primaryBlue),
                                    label: const Text(
                                      '+ Tambah Temuan',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: primaryBlue),
                                    ),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_itemList.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 28, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE0F2FE),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: const Color(0xFFBAE6FD)),
                                      ),
                                      child: const Icon(
                                        Icons.playlist_add_check_rounded,
                                        color: primaryBlue,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Belum Ada Temuan Observasi',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Tambahkan temuan perilaku aman (Safe) atau perilaku berisiko (At-Risk) yang diobservasi.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF64748B),
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    FilledButton.icon(
                                      icon: const Icon(Icons.add_rounded,
                                          size: 18),
                                      label:
                                          const Text('Tambah Temuan Pertama'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: primaryBlue,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                      onPressed: () {
                                        _prepareNewDetail();
                                        _showFindingBottomSheet();
                                      },
                                    ),
                                  ],
                                ),
                              )
                            else ...[
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _itemList.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final item = _itemList[index];
                                  final badgeColor =
                                      _getResultBadgeColor(item.type);
                                  final badgeLabel =
                                      _getResultLabel(item.type);
                                  final hasImage =
                                      (item.image ?? '').trim().isNotEmpty;

                                  return Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius:
                                          BorderRadius.circular(14),
                                      border: Border.all(
                                          color: const Color(0xFFE2E8F0)),
                                      boxShadow: [
                                        BoxShadow(
                                          color:
                                              Colors.black.withValues(alpha: 0.02),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(14),
                                      child: IntrinsicHeight(
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Container(
                                                width: 5, color: badgeColor),
                                            Expanded(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(12),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    if (hasImage)
                                                      Container(
                                                        width: 52,
                                                        height: 52,
                                                        margin:
                                                            const EdgeInsets
                                                                .only(right: 12),
                                                        decoration:
                                                            BoxDecoration(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(10),
                                                          border: Border.all(
                                                              color:
                                                                  const Color(
                                                                      0xFFE2E8F0)),
                                                        ),
                                                        child: ClipRRect(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(9),
                                                          child:
                                                              _observationImagePreview(
                                                                  item.image!,
                                                                  height: 52),
                                                        ),
                                                      )
                                                    else
                                                      Container(
                                                        width: 44,
                                                        height: 44,
                                                        margin:
                                                            const EdgeInsets
                                                                .only(right: 12),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: badgeColor
                                                              .withValues(alpha: 0.1),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(10),
                                                        ),
                                                        child: Icon(
                                                          badgeLabel.contains(
                                                                  'AMAN')
                                                              ? Icons
                                                                  .check_circle_outline_rounded
                                                              : Icons
                                                                  .warning_amber_rounded,
                                                          color: badgeColor,
                                                          size: 22,
                                                        ),
                                                      ),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              Container(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .symmetric(
                                                                        horizontal:
                                                                            7,
                                                                        vertical:
                                                                            2),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: badgeColor
                                                                      .withValues(
                                                                          alpha: 0.1),
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              6),
                                                                  border: Border.all(
                                                                      color: badgeColor
                                                                          .withValues(alpha: 0.25)),
                                                                ),
                                                                child: Text(
                                                                  badgeLabel,
                                                                  style:
                                                                      TextStyle(
                                                                    fontSize:
                                                                        10,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color:
                                                                        badgeColor,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(
                                                              height: 6),
                                                          Text(
                                                            (item.point ??
                                                                    item.name ??
                                                                    'Temuan Lapangan')
                                                                .trim(),
                                                            style:
                                                                const TextStyle(
                                                              fontSize: 13,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: Color(
                                                                  0xFF0F172A),
                                                            ),
                                                          ),
                                                          if ((item.remark ??
                                                                  '')
                                                              .trim()
                                                              .isNotEmpty) ...[
                                                            const SizedBox(
                                                                height: 3),
                                                            Text(
                                                              item.remark!
                                                                  .trim(),
                                                              style:
                                                                  const TextStyle(
                                                                fontSize: 11.5,
                                                                color: Color(
                                                                    0xFF64748B),
                                                             ),
                                                              maxLines: 2,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    ),
                                                    Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        IconButton(
                                                          tooltip:
                                                              'Edit temuan',
                                                          visualDensity:
                                                              VisualDensity
                                                                  .compact,
                                                          icon: const Icon(
                                                              Icons
                                                                  .edit_outlined,
                                                              color:
                                                                  primaryBlue,
                                                              size: 19),
                                                          onPressed: () =>
                                                              _showFindingBottomSheet(
                                                                  editIndex:
                                                                      index),
                                                        ),
                                                        IconButton(
                                                          tooltip:
                                                              'Hapus temuan',
                                                          visualDensity:
                                                              VisualDensity
                                                                  .compact,
                                                          icon: const Icon(
                                                              Icons
                                                                  .delete_outline_rounded,
                                                              color: Color(
                                                                  0xFFDC2626),
                                                              size: 19),
                                                          onPressed: () {
                                                            setState(() =>
                                                                _itemList
                                                                    .removeAt(
                                                                        index));
                                                          },
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('Tambah Temuan Lainnya'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: primaryBlue,
                                  side: const BorderSide(color: primaryBlue),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  minimumSize: const Size.fromHeight(42),
                                ),
                                onPressed: () {
                                  _prepareNewDetail();
                                  _showFindingBottomSheet();
                                },
                              ),
                            ],
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
            child: _itemList.isEmpty
                ? FilledButton.icon(
                    icon:
                        const Icon(Icons.add_circle_outline_rounded, size: 20),
                    label: const Text(
                      '+ Tambah Temuan Observasi',
                      style: TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.bold),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryBlue,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      _prepareNewDetail();
                      _showFindingBottomSheet();
                    },
                  )
                : Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: SizedBox(
                          height: 50,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.add_rounded, size: 20),
                            label: const Text(
                              'Tambah',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryBlue,
                              side: const BorderSide(
                                  color: primaryBlue, width: 1.5),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () {
                              _prepareNewDetail();
                              _showFindingBottomSheet();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 50,
                          child: FilledButton.icon(
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.check_circle_rounded,
                                    size: 20),
                            label: Text(
                              _isSaving
                                  ? 'Menyimpan...'
                                  : (widget.editData != null
                                      ? 'Simpan Perubahan'
                                      : 'Simpan Observasi'),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: canSave
                                  ? primaryBlue
                                  : const Color(0xFFCBD5E1),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: canSave ? _saveObservation : null,
                          ),
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

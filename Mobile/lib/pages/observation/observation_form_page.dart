import 'dart:io';

import 'package:date_time_picker/date_time_picker.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

import '../../models/observation_tran_model.dart';
import '../../models/observation_detail_model.dart';
import '../../services/database.dart';
import '../../services/api.dart';
import '../../services/preference.dart';
import '../../widgets/button_app.dart';
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
  bool _loadingEditDetails = false;
  VideoPlayerController? _videoPlayer;
  File? _videoFile;
  bool _isVideo = false;
  bool _loadingOptions = true;
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
      /* Legacy local-master fallback for already downloaded offline data.
         Online options are replaced by _loadObservationOptions above. */
      _db.rawQuery('''select
        me.id id_departemen_pekerja_yang_diamati,
        me."name" departemen_pekerja_yang_diamati 
      from enum_masters me 
      where me.deleted_at is null and me."type" = 'dept'
      order by me."name"''').then((val) {
        if (val.isNotEmpty) {
          setState(() {
            _deptList.addAll({
              for (var row in val.toList())
                row['id_departemen_pekerja_yang_diamati'] as int:
                    row['departemen_pekerja_yang_diamati']
            }.entries.toList());
            _deptList.sort((a, b) => (a.value).compareTo(b.value));
          });
        }
      });

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
    final data = onlineData ?? PreferenceService.getObservationOptionsCache();
    if (data == null) {
      setState(() {
        _loadingOptions = false;
        _optionsError =
            'Master Observasi belum pernah tersimpan di perangkat. Sambungkan backend sekali untuk memuat data awal.';
      });
      return;
    }
    final locations = _entries(data, 'locations');
    final areas = _entries(data, 'areas');
    final rawLocations = locations.map((location) {
      final source = (data['locations'] as List).whereType<Map>().firstWhere(
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
      _deptList
        ..clear()
        ..addAll(_entries(data, 'departments'));
      _companyOptions = _entries(data, 'companies');
      _docList
        ..clear()
        ..addAll(_entries(data, 'documents'));
      _riskList
        ..clear()
        ..addAll(_entries(data, 'criticalRisks'));
      _areaList
        ..clear()
        ..addAll(areas);
      _rawData
        ..clear()
        ..addAll(rawLocations);
      _penilaianList = _entries(data, 'riskLevels')
          .map((entry) => MapEntry(entry.value.toString(), entry.value))
          .toList();
      _perihalOptions = _entries(data, 'subjects');
      _hasilOptions = _entries(data, 'results');
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
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SapFormIntroCard(
                          title: 'Observasi Lapangan',
                          subtitle:
                              'Laporkan aktivitas, perilaku, dan kondisi operasional yang diamati.',
                          icon: Icons.visibility_rounded,
                          color: Color(0xFF2563EB),
                        ),
                        const SapFormSectionTitle(
                          title: 'Waktu Observasi',
                          subtitle: 'Tanggal dan jam observasi lapangan.',
                          icon: Icons.schedule_rounded,
                          color: Color(0xFF2563EB),
                        ),
                        const Text(
                          'Tanggal Observasi',
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
                          'Waktu Observasi',
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
                        DropdownSearch<MapEntry<int, dynamic>>(
                          selectedItem: _companyOptions
                              .where((item) => item.key == _companyId)
                              .firstOrNull,
                          items: _companyOptions,
                          itemAsString: (item) => item.value.toString(),
                          dropdownDecoratorProps: const DropDownDecoratorProps(
                            dropdownSearchDecoration: InputDecoration(
                              labelText: 'Perusahaan yang Diamati',
                              prefixIcon: Icon(Icons.business_rounded),
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
                            setState(() => _companyId = item.key);
                            _loadObservationOptions(item.key);
                          },
                        ),
                        const SapFormSectionTitle(
                          title: 'Lokasi Observasi',
                          subtitle:
                              'Isi area utama, benchmark, dan lokasi spesifik/GPS.',
                          icon: Icons.place_rounded,
                          color: Color(0xFF2563EB),
                        ),
                        const Text(
                          'Area Utama',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField(
                          initialValue: _areaId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: Icon(
                                Icons.map,
                                size: 24,
                                color: Colors.indigo.shade400,
                              ),
                            ),
                          ),
                          style: const TextStyle(fontSize: 16),
                          icon: const Icon(Icons.arrow_drop_down),
                          items: _areaList.map((item) {
                            return DropdownMenuItem<int>(
                              value: item.key,
                              child: Text(
                                item.value.toString(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (int? val) {
                            setState(() {
                              _getLocation(val!);
                            });
                          },
                        ),
                        const SizedBox(height: 15),
                        const Text(
                          'Detail Lokasi / Benchmark',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField(
                          initialValue: _locationId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: Icon(
                                Icons.layers_outlined,
                                size: 24,
                                color: Colors.indigo.shade400,
                              ),
                            ),
                          ),
                          style: const TextStyle(fontSize: 16),
                          icon: const Icon(Icons.arrow_drop_down),
                          items: _locationList.map((item) {
                            return DropdownMenuItem<int>(
                              value: item.key,
                              child: Text(
                                item.value.toString(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (int? val) {
                            setState(() {
                              _locationId = val!;
                            });
                          },
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
                        const Text(
                          'Kegiatan yang Diamati',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _subject,
                          decoration: InputDecoration(
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: Icon(
                                Icons.content_paste_search,
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
                          'Departemen Pekerjaan yang Diamati',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownSearch<MapEntry<int, dynamic>>(
                          selectedItem: null,
                          dropdownDecoratorProps: DropDownDecoratorProps(
                            baseStyle: const TextStyle(fontSize: 16),
                            dropdownSearchDecoration: InputDecoration(
                              prefixIcon: Padding(
                                padding: const EdgeInsets.only(left: 10),
                                child: Icon(
                                  Icons.image_search,
                                  size: 24,
                                  color: Colors.indigo.shade400,
                                ),
                              ),
                            ),
                          ),
                          items: _deptList.toList(),
                          itemAsString: (MapEntry<int, dynamic>? e) => e?.value,
                          popupProps: const PopupProps.menu(
                            fit: FlexFit.loose,
                            showSearchBox: true,
                          ),
                          onChanged: (val) {
                            setState(() => _deptId = val!.key);
                          },
                        ),
                        const SizedBox(height: 15),
                        const Text(
                          'Dokumen Pendukung',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField(
                          initialValue: _docId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: Icon(
                                Icons.event_note,
                                size: 24,
                                color: Colors.indigo.shade400,
                              ),
                            ),
                          ),
                          style: const TextStyle(fontSize: 16),
                          icon: const Icon(Icons.arrow_drop_down),
                          items: _docList.map((item) {
                            return DropdownMenuItem<int>(
                              value: item.key,
                              child: Text(
                                item.value.toString(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (int? val) {
                            setState(() {
                              _docId = val!;
                            });
                          },
                        ),
                        const SizedBox(height: 15),
                        const Text(
                          'Risiko Kritis',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField(
                          initialValue: _riskId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: Icon(
                                Icons.broken_image_outlined,
                                size: 24,
                                color: Colors.indigo.shade400,
                              ),
                            ),
                          ),
                          style: const TextStyle(fontSize: 16),
                          icon: const Icon(Icons.arrow_drop_down),
                          items: _riskList.map((item) {
                            return DropdownMenuItem<int>(
                              value: item.key,
                              child: Text(
                                item.value.toString(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (int? val) {
                            setState(() {
                              _riskId = val!;
                            });
                          },
                        ),
                        const SizedBox(height: 15),
                        const Text(
                          'Penilaian Risiko',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField(
                          initialValue: _penilaianId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: Icon(
                                Icons.star_half,
                                size: 24,
                                color: Colors.indigo.shade400,
                              ),
                            ),
                          ),
                          style: const TextStyle(fontSize: 16),
                          icon: const Icon(Icons.arrow_drop_down),
                          items: _penilaianList.map((item) {
                            return DropdownMenuItem<String>(
                              value: item.key,
                              child: Text(
                                item.value.toString(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (String? val) {
                            setState(() {
                              _penilaianId = val!;
                            });
                          },
                        ),
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

                                  Future.delayed(
                                      const Duration(milliseconds: 200), () {
                                    _scrollCtrl.animateTo(
                                      _scrollCtrl.position.maxScrollExtent,
                                      duration:
                                          const Duration(milliseconds: 500),
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
                                                if (_videoPlayer!
                                                    .value.isPlaying) {
                                                  _videoPlayer!.pause();
                                                } else {
                                                  _videoPlayer!.play();
                                                }
                                              });
                                            },
                                            child: Container(
                                              width: MediaQuery.of(context)
                                                  .size
                                                  .width,
                                              height: 200,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                    color:
                                                        Colors.indigo.shade200),
                                                color: Colors.white54,
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                child: AspectRatio(
                                                  aspectRatio: _videoPlayer!
                                                      .value.aspectRatio,
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
                                              final ImagePicker picker =
                                                  ImagePicker();
                                              final File videoPicked =
                                                  File((await picker.pickVideo(
                                                source: ImageSource.camera,
                                                maxDuration:
                                                    const Duration(seconds: 10),
                                              ))!
                                                      .path);
                                              setState(() {
                                                _videoFile =
                                                    File(videoPicked.path);
                                                _videoPlayer =
                                                    VideoPlayerController.file(
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
                                        width:
                                            MediaQuery.of(context).size.width,
                                        height: 200,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                              color: Colors.indigo.shade200),
                                          color: Colors.white54,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            IconButton(
                                              icon: Icon(
                                                Icons.video_collection,
                                                size: 30,
                                                color: Colors.indigo.shade400,
                                              ),
                                              onPressed: () async {
                                                final ImagePicker picker =
                                                    ImagePicker();
                                                final File videoPicked = File(
                                                    (await picker.pickVideo(
                                                  source: ImageSource.camera,
                                                  maxDuration: const Duration(
                                                      seconds: 10),
                                                ))!
                                                        .path);
                                                setState(() {
                                                  _videoFile =
                                                      File(videoPicked.path);
                                                  _videoPlayer =
                                                      VideoPlayerController
                                                          .file(_videoFile!)
                                                        ..initialize()
                                                            .then((_) {
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
          child: buttonApp(
            label: 'Lanjut',
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
                                .first
                                .value
                                .toString(),
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
    );
  }
}

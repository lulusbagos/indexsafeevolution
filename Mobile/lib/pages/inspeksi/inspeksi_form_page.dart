import 'dart:io';

import 'package:date_time_picker/date_time_picker.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

import '../../models/inspect_tran_model.dart';
import '../../services/database.dart';
import '../../services/preference.dart';
import '../../utils/enums.dart';
import '../../utils/helpers.dart';
import '../../widgets/button_app.dart';
import '../../widgets/sap_form_widgets.dart';
import '../../widgets/top_bar.dart';
import 'inspeksi_checklist_page.dart';

class InspeksiFormPage extends StatefulWidget {
  const InspeksiFormPage(this.module, {this.idx, super.key});

  final Module module;
  final int? idx;

  @override
  State<InspeksiFormPage> createState() => _InspeksiFormPageState();
}

class _InspeksiFormPageState extends State<InspeksiFormPage> {
  final _scrollCtrl = ScrollController();
  final _db = DatabaseService();
  final _profile = PreferenceService.getProfile();
  final _locationDetail = TextEditingController();
  final List<dynamic> _rawData = [];
  final List<MapEntry<int, dynamic>> _inspectionList = [];
  final List<MapEntry<int, dynamic>> _inspektorList = [];
  List<MapEntry<int, dynamic>> _areaList = [];
  List<MapEntry<int, dynamic>> _locationList = [];
  List<MapEntry<int, dynamic>> _pjaList = [];
  DateTime? _date = DateTime.now();
  String? _time = DateFormat('hh:mm').format(DateTime.now());
  int? _inspectionId;
  int? _companyId;
  MapEntry<int, dynamic>? _inspectionItem;
  int? _areaId;
  int? _locationId;
  int? _pjaId;
  int _inspektor = 1;
  int? _inspektorId1;
  int? _inspektorId2;
  int? _inspektorId3;
  int? _inspektorId4;
  int? _inspektorId5;
  MapEntry<int, dynamic>? _inspektorItem1;
  MapEntry<int, dynamic>? _inspektorItem2;
  MapEntry<int, dynamic>? _inspektorItem3;
  MapEntry<int, dynamic>? _inspektorItem4;
  MapEntry<int, dynamic>? _inspektorItem5;
  VideoPlayerController? _videoPlayer;
  File? _videoFile;
  bool _isVideo = false;

  @override
  void initState() {
    super.initState();
    _companyId = _profile?.companyId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fillGpsFromDevice(silent: true);
      _db.rawQuery('''select
        e.id id_inspector,
        e.no_nik nik_inspector,
        e.nama_lengkap nama_inspector,
        e.posisi jabatan_inspector
      from employees e
      where e.deleted_at is null
      order by e.no_nik''').then((val) {
        if (val.isNotEmpty) {
          setState(() {
            _inspektorList.addAll({
              for (var row in val.toList())
                row['id_inspector'] as int: row['nama_inspector']
            }.entries.toList());
            _inspektorList.sort((a, b) => (a.value).compareTo(b.value));
          });
        }
      });

      _db.rawQuery('''select
        id_jenis_inspeksi,
        ji.jenis_inspeksi,
        me2.id id_area,
        me2.name area,
        me.id id_lokasi,
        me."name" lokasi,
        e.id id_pja,
        e.nama_lengkap nama_pja
      from (
        select
        id id_jenis_inspeksi,
        name jenis_inspeksi
        from inspection_masters im
        where deleted_at is null and
        ref_id is null and
        name like 'Inspeksi%' and
        name not like 'Inspeksi Daily%' and
        name not like 'Inspeksi Malam%'
      ) ji
        left join enum_bridges meb on meb.secondary_id=ji.id_jenis_inspeksi and meb.deleted_at is null and meb.flag='enum-inspection_header'
        left join enum_masters me on me.id=meb.primary_id and me.deleted_at is null
        left join enum_masters me2 on me2.id=me.ref_id and me2.deleted_at is null
        left join enum_bridges meb2 on meb2.primary_id=me.id and meb2.deleted_at is null and meb2.flag='location-pja'
        left join enum_masters me3 on me3.code=cast(meb2.secondary_id as varchar)
        left join employees e on e.user_id=cast(me3.code as int)
      order by ji.jenis_inspeksi,me."name"''').then((val) {
        if (val.isNotEmpty) {
          setState(() {
            _rawData.addAll(val.toList());
            _inspectionList.addAll({
              for (var row in val.toList())
                row['id_jenis_inspeksi'] as int: row['jenis_inspeksi']
            }.entries.toList());
            _inspectionList.sort((a, b) => (a.value).compareTo(b.value));
          });

          // _getHistory();
        }
      });
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

  void _getArea(MapEntry<int, dynamic>? val) {
    _inspectionId = val!.key;
    _inspectionItem = val;
    _areaId = null;
    _areaList = {
      for (var row in _rawData
          .where((e) =>
              e['id_area'] != null && e['id_jenis_inspeksi'] as int == val.key)
          .toList())
        row['id_area'] as int: row['area']
    }.entries.toList();
    _areaList.sort((a, b) => (a.value).compareTo(b.value));
    _locationId = null;
    _locationList = [];
    _pjaId = null;
    _pjaList = [];
  }

  void _getLocation(int val) {
    _areaId = val;
    _locationId = null;
    _locationList = {
      for (var row in _rawData
          .where((e) =>
              e['id_lokasi'] != null &&
              e['id_area'] != null &&
              e['id_area'] as int == val &&
              e['id_jenis_inspeksi'] != null &&
              e['id_jenis_inspeksi'] as int == _inspectionId)
          .toList())
        row['id_lokasi'] as int: row['lokasi']
    }.entries.toList();
    _locationList.sort((a, b) => (a.value).compareTo(b.value));
    _pjaId = null;
    _pjaList = [];
  }

  void _getPja(int val) {
    _locationId = val;
    _pjaId = null;
    _pjaList = {
      for (var row in _rawData
          .where((e) => e['id_pja'] != null && e['id_lokasi'] as int == val)
          .toList())
        row['id_pja'] as int: row['nama_pja']
    }.entries.toList();
    _pjaList.sort((a, b) => (a.value).compareTo(b.value));
  }

  // void _getHistory() {
  //   if (widget.idx == null) return;
  //   _db.rawQuery(
  //       '''select * from inspection_trans where id=${widget.idx}''').then((val) {
  //     if (val.isNotEmpty) {
  //       var map = Map.of(val[0] as Map<String, dynamic>);
  //       var mod = InspectTrnModel.fromJson(map);
  //
  //       setState(() {
  //         _inspectionId = mod.inspectionId;
  //         _areaId = mod.areaId;
  //         _locationId = mod.locationId;
  //         _pjaId = mod.pjaId;
  //         _date = DateTime.parse(mod.date.toString());
  //         _time = mod.time.toString();
  //         _locationDetail.text = mod.locationDetail.toString();
  //
  //         _inspectionItem = {
  //           for (var row in _rawData
  //               .where((e) =>
  //                   e['id_jenis_inspeksi'] != null &&
  //                   e['id_jenis_inspeksi'] as int == _inspectionId)
  //               .toList())
  //             row['id_jenis_inspeksi'] as int: row['jenis_inspeksi']
  //         }.entries.toList().first;
  //
  //         _areaList = {
  //           for (var row in _rawData
  //               .where((e) =>
  //                   e['id_area'] != null && e['id_area'] as int == _areaId)
  //               .toList())
  //             row['id_area'] as int: row['area']
  //         }.entries.toList();
  //
  //         _locationList = {
  //           for (var row in _rawData
  //               .where((e) =>
  //                   e['id_lokasi'] != null &&
  //                   e['id_lokasi'] as int == _locationId)
  //               .toList())
  //             row['id_lokasi'] as int: row['lokasi']
  //         }.entries.toList();
  //
  //         _pjaList = {
  //           for (var row in _rawData
  //               .where(
  //                   (e) => e['id_pja'] != null && e['id_pja'] as int == _pjaId)
  //               .toList())
  //             row['id_pja'] as int: row['nama_pja']
  //         }.entries.toList();
  //       });
  //     }
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: TopBar(title: pageTitle(widget.module), back: 2),
        body: SingleChildScrollView(
          controller: _scrollCtrl,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SapFormIntroCard(
                title: 'Safety Inspeksi',
                subtitle:
                    'Pemeriksaan operasional untuk memantau kepatuhan K3 area kerja.',
                icon: Icons.fact_check_rounded,
                color: Color(0xFF0F766E),
              ),
              const SapFormSectionTitle(
                title: 'Waktu & Jenis Inspeksi',
                subtitle:
                    'Tentukan tanggal, jam, dan jenis inspeksi sebelum memilih area.',
                icon: Icons.event_note_rounded,
                color: Color(0xFF0F766E),
              ),
              const Text(
                'Tanggal Inspeksi',
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
                'Jam Inspeksi',
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
              const Text(
                'Jenis Inspeksi',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              DropdownSearch<MapEntry<int, dynamic>>(
                selectedItem: _inspectionItem,
                dropdownDecoratorProps: DropDownDecoratorProps(
                  baseStyle: const TextStyle(fontSize: 16),
                  dropdownSearchDecoration: InputDecoration(
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Icon(
                        Icons.event_note,
                        size: 24,
                        color: Colors.indigo.shade400,
                      ),
                    ),
                  ),
                ),
                items: _inspectionList.toList(),
                itemAsString: (MapEntry<int, dynamic>? e) => e?.value,
                popupProps: const PopupProps.menu(
                  fit: FlexFit.loose,
                  showSearchBox: true,
                ),
                onChanged: (val) {
                  setState(() {
                    _getArea(val);
                  });
                },
              ),
              const SizedBox(height: 15),
              const SapFormSectionTitle(
                title: 'Lokasi & Penanggung Jawab',
                subtitle: 'Pilih area utama, detail lokasi/benchmark, dan PJA.',
                icon: Icons.place_rounded,
                color: Color(0xFF0F766E),
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
                    _getPja(val!);
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
              CompanyDropdown(
                initialCompanyId: _profile?.companyId,
                initialCompanyName: _profile?.company,
                onChanged: (value) => setState(() => _companyId = value),
              ),
              const Text(
                'PJA',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField(
                initialValue: _pjaId,
                isExpanded: true,
                decoration: InputDecoration(
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Icon(
                      Icons.account_circle,
                      size: 24,
                      color: Colors.indigo.shade400,
                    ),
                  ),
                ),
                style: const TextStyle(fontSize: 16),
                icon: const Icon(Icons.arrow_drop_down),
                items: _pjaList.map((item) {
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
                    _pjaId = val!;
                  });
                },
              ),
              if (widget.module == Module.inspectionWeekly) ...[
                if (_inspektor >= 1) ...[
                  const SizedBox(height: 15),
                  const SapFormSectionTitle(
                    title: 'Tim Inspektor',
                    subtitle:
                        'Tambahkan satu atau lebih inspektor yang melakukan pemeriksaan.',
                    icon: Icons.groups_rounded,
                    color: Color(0xFF0F766E),
                  ),
                  const Text(
                    'Inspektor 1',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownSearch<MapEntry<int, dynamic>>(
                    selectedItem: _inspektorItem1,
                    dropdownDecoratorProps: DropDownDecoratorProps(
                      baseStyle: const TextStyle(fontSize: 16),
                      dropdownSearchDecoration: InputDecoration(
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: Icon(
                            Icons.account_circle_outlined,
                            size: 24,
                            color: Colors.indigo.shade400,
                          ),
                        ),
                      ),
                    ),
                    items: _inspektorList.toList(),
                    itemAsString: (MapEntry<int, dynamic>? e) => e?.value,
                    popupProps: const PopupProps.menu(
                      fit: FlexFit.loose,
                      showSearchBox: true,
                    ),
                    onChanged: (val) {
                      setState(() {
                        _inspektorId1 = val!.key;
                        _inspektorItem1 = val;
                      });
                    },
                  ),
                ],
                if (_inspektor >= 2) ...[
                  const SizedBox(height: 15),
                  const Text(
                    'Inspektor 2',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownSearch<MapEntry<int, dynamic>>(
                    selectedItem: _inspektorItem2,
                    dropdownDecoratorProps: DropDownDecoratorProps(
                      baseStyle: const TextStyle(fontSize: 16),
                      dropdownSearchDecoration: InputDecoration(
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: Icon(
                            Icons.account_circle_outlined,
                            size: 24,
                            color: Colors.indigo.shade400,
                          ),
                        ),
                      ),
                    ),
                    items: _inspektorList.toList(),
                    itemAsString: (MapEntry<int, dynamic>? e) => e?.value,
                    popupProps: const PopupProps.menu(
                      fit: FlexFit.loose,
                      showSearchBox: true,
                    ),
                    onChanged: (val) {
                      setState(() {
                        _inspektorId2 = val!.key;
                        _inspektorItem2 = val;
                      });
                    },
                  ),
                ],
                if (_inspektor >= 3) ...[
                  const SizedBox(height: 15),
                  const Text(
                    'Inspektor 3',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownSearch<MapEntry<int, dynamic>>(
                    selectedItem: _inspektorItem3,
                    dropdownDecoratorProps: DropDownDecoratorProps(
                      baseStyle: const TextStyle(fontSize: 16),
                      dropdownSearchDecoration: InputDecoration(
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: Icon(
                            Icons.account_circle_outlined,
                            size: 24,
                            color: Colors.indigo.shade400,
                          ),
                        ),
                      ),
                    ),
                    items: _inspektorList.toList(),
                    itemAsString: (MapEntry<int, dynamic>? e) => e?.value,
                    popupProps: const PopupProps.menu(
                      fit: FlexFit.loose,
                      showSearchBox: true,
                    ),
                    onChanged: (val) {
                      setState(() {
                        _inspektorId3 = val!.key;
                        _inspektorItem3 = val;
                      });
                    },
                  ),
                ],
                if (_inspektor >= 4) ...[
                  const SizedBox(height: 15),
                  const Text(
                    'Inspektor 4',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownSearch<MapEntry<int, dynamic>>(
                    selectedItem: _inspektorItem4,
                    dropdownDecoratorProps: DropDownDecoratorProps(
                      baseStyle: const TextStyle(fontSize: 16),
                      dropdownSearchDecoration: InputDecoration(
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: Icon(
                            Icons.account_circle_outlined,
                            size: 24,
                            color: Colors.indigo.shade400,
                          ),
                        ),
                      ),
                    ),
                    items: _inspektorList.toList(),
                    itemAsString: (MapEntry<int, dynamic>? e) => e?.value,
                    popupProps: const PopupProps.menu(
                      fit: FlexFit.loose,
                      showSearchBox: true,
                    ),
                    onChanged: (val) {
                      setState(() {
                        _inspektorId4 = val!.key;
                        _inspektorItem4 = val;
                      });
                    },
                  ),
                ],
                if (_inspektor >= 5) ...[
                  const SizedBox(height: 15),
                  const Text(
                    'Inspektor 5',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownSearch<MapEntry<int, dynamic>>(
                    selectedItem: _inspektorItem5,
                    dropdownDecoratorProps: DropDownDecoratorProps(
                      baseStyle: const TextStyle(fontSize: 16),
                      dropdownSearchDecoration: InputDecoration(
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: Icon(
                            Icons.account_circle_outlined,
                            size: 24,
                            color: Colors.indigo.shade400,
                          ),
                        ),
                      ),
                    ),
                    items: _inspektorList.toList(),
                    itemAsString: (MapEntry<int, dynamic>? e) => e?.value,
                    popupProps: const PopupProps.menu(
                      fit: FlexFit.loose,
                      showSearchBox: true,
                    ),
                    onChanged: (val) {
                      setState(() {
                        _inspektorId5 = val!.key;
                        _inspektorItem5 = val;
                      });
                    },
                  ),
                ],
                const SizedBox(height: 10),
                Container(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(100, 30),
                    ),
                    onPressed: () {
                      setState(() {
                        _inspektor += 1;
                        Future.delayed(const Duration(milliseconds: 200), () {
                          _scrollCtrl.animateTo(
                            _scrollCtrl.position.maxScrollExtent,
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOut,
                          );
                        });
                      });
                    },
                    child: const Text('+ Tambah Inspektor'),
                  ),
                ),
              ],
              const SizedBox(height: 15),
              Visibility(
                visible: false,
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Apakah ada video inspeksi?',
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
          child: buttonApp(
            label: 'Lanjut',
            onPressed: (_inspectionId == null ||
                    _areaId == null ||
                    _locationId == null ||
                    _pjaId == null ||
                    _locationDetail.text == '')
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => InspeksiChecklistPage(
                          widget.module,
                          idx: widget.idx,
                          inspectTrnModel: InspectTrnModel(
                            code:
                                '${_profile?.noNik}-${DateTime.now().millisecondsSinceEpoch}0000000000'
                                    .substring(0, 24),
                            title: _inspectionItem?.value,
                            companyId: _companyId,
                            employeeId: _profile?.id,
                            inspectionId: _inspectionId,
                            areaId: _areaId,
                            locationId: _locationId,
                            locationDetail: _locationDetail.text,
                            date: _date!.toString().substring(0, 10),
                            time: _time!,
                            dangerLevel: 'c',
                            remark: _inspectionItem?.value,
                            video: _videoFile != null ? _videoFile!.path : '',
                            createdAt: DateTime.now().toString(),
                            updatedAt: DateTime.now().toString(),
                            category: widget.module.name,
                            inspektor1Id: _inspektorId1,
                            inspektor2Id: _inspektorId2,
                            inspektor3Id: _inspektorId3,
                            inspektor4Id: _inspektorId4,
                            inspektor5Id: _inspektorId5,
                            pjaId: _pjaId,
                            status: 0,
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

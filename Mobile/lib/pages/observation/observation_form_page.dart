import 'dart:io';

import 'package:date_time_picker/date_time_picker.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

import '../../models/observation_tran_model.dart';
import '../../services/database.dart';
import '../../services/preference.dart';
import '../../widgets/button_app.dart';
import '../../widgets/sap_form_widgets.dart';
import '../../widgets/top_bar.dart';
import 'observation_detail_page.dart';

class ObservationFormPage extends StatefulWidget {
  const ObservationFormPage({super.key});

  @override
  State<ObservationFormPage> createState() => _ObservationFormPageState();
}

class _ObservationFormPageState extends State<ObservationFormPage> {
  final _scrollCtrl = ScrollController();
  final _db = DatabaseService();
  final _profile = PreferenceService.getProfile();
  final _locationDetail = TextEditingController();
  final _subject = TextEditingController();
  final List<dynamic> _rawData = [];
  final List<MapEntry<String, dynamic>> _penilaianList = [
    const MapEntry('Rendah', 'Rendah'),
    const MapEntry('Sedang', 'Sedang'),
    const MapEntry('Tinggi', 'Tinggi'),
    const MapEntry('Ekstrim', 'Ekstrim'),
  ];
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
        body: SingleChildScrollView(
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
              CompanyDropdown(
                initialCompanyId: _profile?.companyId,
                initialCompanyName: _profile?.company,
                onChanged: (value) => setState(() => _companyId = value),
              ),
              const SapFormSectionTitle(
                title: 'Lokasi Observasi',
                subtitle: 'Isi area utama, benchmark, dan lokasi spesifik/GPS.',
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
            onPressed: (_deptId == null ||
                    _docId == null ||
                    _riskId == null ||
                    _areaId == null ||
                    _locationId == null ||
                    _locationDetail.text == '' ||
                    _subject.text == '' ||
                    _penilaianId == null)
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ObservationDetailPage(
                          observationTrnModel: ObservationTrnModel(
                            code:
                                '${_profile?.noNik}-${DateTime.now().millisecondsSinceEpoch}0000000000'
                                    .substring(0, 24),
                            title: _subject.text,
                            companyId: _companyId,
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
                            remark: _docList
                                .where((i) => i.key == _docId)
                                .first
                                .value,
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

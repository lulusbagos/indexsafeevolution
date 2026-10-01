import 'dart:io';

import 'package:date_time_picker/date_time_picker.dart';
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
import 'daily_checklist_page.dart';

class DailyFormPage extends StatefulWidget {
  const DailyFormPage(this.module, {super.key});

  final Module module;

  @override
  State<DailyFormPage> createState() => _DailyFormPageState();
}

class _DailyFormPageState extends State<DailyFormPage> {
  final _scrollCtrl = ScrollController();
  final _db = DatabaseService();
  final _profile = PreferenceService.getProfile();
  final _locationDetail = TextEditingController();
  final List<dynamic> _rawData = [];
  final List<MapEntry<int, dynamic>> _shiftList = [];
  final List<MapEntry<int, dynamic>> _areaList = [];
  List<MapEntry<int, dynamic>> _locationList = [];
  List<MapEntry<int, dynamic>> _pjaList = [];
  DateTime? _date = DateTime.now();
  String? _time = DateFormat('hh:mm').format(DateTime.now());
  int? _companyId;
  int? _shiftId;
  int? _areaId;
  int? _locationId;
  int? _pjaId;
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
        me.id id_shift,
        me."name" shift
      from enum_masters me
      where me.deleted_at is null and type = 'shift'
      order by me.id ''').then((val) {
        if (val.isNotEmpty) {
          setState(() {
            _shiftList.addAll({
              for (var row in val.toList()) row['id_shift'] as int: row['shift']
            }.entries.toList());
            _shiftList.sort((a, b) => (a.value).compareTo(b.value));
          });
        }
      });

      _db.rawQuery('''select
        me.id id_area,
        me."name" area,
        me2.id id_lokasi,
        me2."name" lokasi,
        e.id id_pja,
        e.nama_lengkap nama_pja
      from enum_masters me
        left join enum_masters me2 on me2.ref_id=me.id and me2.deleted_at is null
        left join enum_bridges meb on meb.primary_id=me2.id and meb.deleted_at is null and meb.flag='location-pja'
        left join enum_masters me3 on me3.code=cast(meb.secondary_id as varchar)
        left join employees e on e.user_id=cast(me3.code as int)
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

  Future<void> _fillGpsFromDevice({bool silent = false}) {
    return fillGpsCoordinate(
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
              const SizedBox(height: 15),
              const Text(
                'Shift',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField(
                initialValue: _shiftId,
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
                items: _shiftList.map((item) {
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
                    _shiftId = val!;
                  });
                },
              ),
              const SizedBox(height: 15),
              const Text(
                'Area Inspeksi',
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
                'Lokasi',
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
                'Lokasi Detail',
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
                  onPressed: _fillGpsFromDevice,
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
            onPressed: (_shiftId == null ||
                    _areaId == null ||
                    _locationId == null ||
                    _pjaId == null ||
                    _locationDetail.text == '')
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DailyChecklistPage(
                          widget.module,
                          inspectTrnModel: InspectTrnModel(
                            code:
                                '${_profile?.noNik}-${DateTime.now().millisecondsSinceEpoch}0000000000'
                                    .substring(0, 24),
                            title: 'Inspeksi Daily',
                            companyId: _companyId,
                            employeeId: _profile?.id,
                            inspectionId: 1360,
                            areaId: _areaId,
                            locationId: _locationId,
                            locationDetail: _locationDetail.text,
                            date: _date!.toString().substring(0, 10),
                            time: _time!,
                            dangerLevel: 'c',
                            remark: 'Inspeksi Daily',
                            video: _videoFile != null ? _videoFile!.path : '',
                            createdAt: DateTime.now().toString(),
                            updatedAt: DateTime.now().toString(),
                            category: widget.module.name,
                            shiftId: _shiftId,
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

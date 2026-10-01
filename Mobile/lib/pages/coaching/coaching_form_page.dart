import 'dart:io';

import 'package:date_time_picker/date_time_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

import '../../models/coaching_tran_model.dart';
import '../../services/database.dart';
import '../../services/preference.dart';
import '../../utils/helpers.dart';
import '../../widgets/button_app.dart';
import '../../widgets/sap_form_widgets.dart';
import '../../widgets/top_bar.dart';
import '../../widgets/upload_files.dart';
import 'coaching_detail_page.dart';

class CoachingFormPage extends StatefulWidget {
  const CoachingFormPage({super.key});

  @override
  State<CoachingFormPage> createState() => _CoachingFormPageState();
}

class _CoachingFormPageState extends State<CoachingFormPage> {
  final _scrollCtrl = ScrollController();
  final _db = DatabaseService();
  final _profile = PreferenceService.getProfile();
  final _locationDetail = TextEditingController();
  final _title = TextEditingController();
  final _feedback = TextEditingController();
  final List<dynamic> _rawData = [];
  final List<MapEntry<int, dynamic>> _temaList = [];
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

      _db.rawQuery('''select
        id id_tema,
        "name" tema
      from coaching_masters cm 
      where cm.deleted_at is null and type = 'theme'
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
        appBar: const TopBar(title: 'Coaching & Pembinaan', back: 2),
        body: SingleChildScrollView(
          controller: _scrollCtrl,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SapFormIntroCard(
                title: 'Coaching & Pembinaan',
                subtitle:
                    'Dokumentasikan sesi pembinaan, sharing knowledge, feedback, dan komitmen bersama.',
                icon: Icons.record_voice_over_rounded,
                color: Color(0xFF7C3AED),
              ),
              const SapFormSectionTitle(
                title: 'Waktu & Lokasi Coaching',
                subtitle:
                    'Isi tanggal, waktu mulai, area, dan detail lokasi kegiatan.',
                icon: Icons.event_available_rounded,
                color: Color(0xFF7C3AED),
              ),
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
              CompanyDropdown(
                initialCompanyId: _profile?.companyId,
                initialCompanyName: _profile?.company,
                onChanged: (value) => setState(() => _companyId = value),
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
              const SapFormSectionTitle(
                title: 'Materi & Evidence Coaching',
                subtitle:
                    'Pilih tema, isi judul, feedback/komitmen, lalu unggah foto kegiatan.',
                icon: Icons.menu_book_rounded,
                color: Color(0xFF7C3AED),
              ),
              const Text(
                'Tema Coaching',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField(
                initialValue: _temaId,
                isExpanded: true,
                decoration: InputDecoration(
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Icon(
                      Icons.abc_outlined,
                      size: 24,
                      color: Colors.indigo.shade400,
                    ),
                  ),
                ),
                style: const TextStyle(fontSize: 16),
                icon: const Icon(Icons.arrow_drop_down),
                items: _temaList.map((item) {
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
                    _temaId = val!;
                  });
                },
              ),
              const SizedBox(height: 15),
              const Text(
                'Judul / Topik Coaching',
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
                'Umpan Balik (Feedback) & Komitmen Bersama',
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
          child: buttonApp(
            label: 'Lanjut',
            onPressed: (_temaId == null ||
                    _areaId == null ||
                    _locationId == null ||
                    _locationDetail.text == '' ||
                    _title.text == '' ||
                    _feedback.text == '' ||
                    _image == null)
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CoachingDetailPage(
                          coachingTrnModel: CoachingTrnModel(
                            code:
                                '${_profile?.noNik}-${DateTime.now().millisecondsSinceEpoch}0000000000'
                                    .substring(0, 24),
                            title: _title.text,
                            companyId: _companyId,
                            employeeId: _profile?.id,
                            trainerId: _profile?.id,
                            areaId: _areaId,
                            locationId: _locationId,
                            locationDetail: _locationDetail.text,
                            date: _date!.toString().substring(0, 10),
                            time: _time!,
                            remark: _temaList
                                .where((i) => i.key == _temaId)
                                .first
                                .value,
                            image: _image,
                            createdAt: DateTime.now().toString(),
                            updatedAt: DateTime.now().toString(),
                            purpose: _temaList
                                .where((i) => i.key == _temaId)
                                .first
                                .value,
                            feedback: _feedback.text,
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

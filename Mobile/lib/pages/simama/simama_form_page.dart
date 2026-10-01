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
import 'simama_checklist_page.dart';

class SimamaFormPage extends StatefulWidget {
  const SimamaFormPage(this.module, {super.key});

  final Module module;

  @override
  State<SimamaFormPage> createState() => _SimamaFormPageState();
}

class _SimamaFormPageState extends State<SimamaFormPage> {
  final _scrollCtrl = ScrollController();
  final _db = DatabaseService();
  final _profile = PreferenceService.getProfile();
  final _summary = TextEditingController();
  final List<dynamic> _rawData = [];
  final List<MapEntry<int, dynamic>> _inspektorList = [];
  final List<MapEntry<int, dynamic>> _areaList = [];
  DateTime? _date = DateTime.now();
  String? _time = DateFormat('hh:mm').format(DateTime.now());
  int? _companyId;
  int? _areaId;
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
  final List<String> _eventImages = [];

  String? get _eventImage => _eventImages.isEmpty ? null : _eventImages.first;

  @override
  void initState() {
    super.initState();
    _companyId = _profile?.companyId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
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
        me.id id_area,
        me."name" area,
        me2.id id_lokasi,
        me2."name" lokasi,
        im.id id_list_pertanyaan,
        im."name" list_pertanyaan
      from enum_masters me
        left join enum_masters me2 on me2.ref_id=me.id and me2.deleted_at is null
        left join inspection_masters im on im.code=me2.code and im.deleted_at is null
      where me.deleted_at is null and me."type" = 'area' and me."name" like 'Area%'
      order by me."name",me2.id,im.id''').then((val) {
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
    _summary.dispose();

    super.dispose();
  }

  void _addEventImage(String path) {
    if (path.isEmpty) return;
    setState(() {
      if (!_eventImages.contains(path)) {
        _eventImages.add(path);
      }
    });
  }

  void _removeEventImage(String path) {
    setState(() => _eventImages.remove(path));
  }

  Future<void> _pickMultipleEventImages() async {
    final images = await ImagePicker().pickMultiImage(imageQuality: 80);
    if (images.isEmpty) return;
    setState(() {
      for (final image in images) {
        if (!_eventImages.contains(image.path)) {
          _eventImages.add(image.path);
        }
      }
    });
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
              CompanyDropdown(
                initialCompanyId: _profile?.companyId,
                initialCompanyName: _profile?.company,
                onChanged: (value) => setState(() => _companyId = value),
              ),
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
                    _areaId = val!;
                    _inspektorId1 = null;
                    _inspektorId2 = null;
                    _inspektorId3 = null;
                    _inspektorItem1 = null;
                    _inspektorItem2 = null;
                    _inspektorItem3 = null;
                  });
                },
              ),
              if (_inspektor >= 1) ...[
                const SizedBox(height: 15),
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
              const SizedBox(height: 15),
              const Text(
                'Foto Kegiatan',
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
                                  _addEventImage(value.path);
                                }
                              });
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.collections,
                                color: Colors.grey),
                            title: const Text('Gallery Multi Foto'),
                            onTap: () {
                              Navigator.pop(context);
                              _pickMultipleEventImages();
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: Container(
                  width: MediaQuery.of(context).size.width,
                  height: _eventImages.isEmpty ? 150 : 178,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _eventImages.isEmpty
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Upload Foto',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Bisa lebih dari 1 foto',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        )
                      : Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${_eventImages.length} foto dipilih',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'Tap untuk tambah',
                                    style: TextStyle(
                                      color: Colors.indigo.shade400,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Expanded(
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _eventImages.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 10),
                                  itemBuilder: (context, index) {
                                    final path = _eventImages[index];
                                    return Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: Image.file(
                                            File(path),
                                            width: 115,
                                            height: 115,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: InkWell(
                                            onTap: () =>
                                                _removeEventImage(path),
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: const BoxDecoration(
                                                color: Colors.black54,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.close,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _pickMultipleEventImages,
                  icon: const Icon(Icons.add_photo_alternate_rounded),
                  label: const Text('Tambah Foto dari Gallery'),
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'Kesimpulan Si Mama',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _summary,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText:
                      'Tulis ringkasan hasil sidak, kondisi utama, dan arahan tindak lanjut...',
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Icon(
                      Icons.summarize_rounded,
                      size: 24,
                      color: Colors.indigo.shade400,
                    ),
                  ),
                ),
                style: const TextStyle(fontSize: 16),
                onChanged: (String val) => setState(() {}),
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
            onPressed: (_areaId == null ||
                    _eventImages.isEmpty ||
                    (_inspektorId1 == null &&
                        _inspektorId2 == null &&
                        _inspektorId3 == null &&
                        _inspektorId4 == null &&
                        _inspektorId5 == null))
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SimamaChecklistPage(
                          widget.module,
                          inspectTrnModel: InspectTrnModel(
                            code:
                                '${_profile?.noNik}-${DateTime.now().millisecondsSinceEpoch}0000000000'
                                    .substring(0, 24),
                            title: 'Sidak Malam Management',
                            companyId: _companyId,
                            employeeId: _profile?.id,
                            inspectionId: 1359,
                            areaId: _areaId,
                            locationId: null,
                            locationDetail: null,
                            date: _date!.toString().substring(0, 10),
                            time: _time!,
                            dangerLevel: 'c',
                            remark: _summary.text.trim().isEmpty
                                ? 'Sidak Malam Management'
                                : _summary.text.trim(),
                            video: _videoFile != null ? _videoFile!.path : '',
                            createdAt: DateTime.now().toString(),
                            updatedAt: DateTime.now().toString(),
                            category: widget.module.name,
                            inspektor1Id: _inspektorId1,
                            inspektor2Id: _inspektorId2,
                            inspektor3Id: _inspektorId3,
                            inspektor4Id: _inspektorId4,
                            inspektor5Id: _inspektorId5,
                            image: _eventImage,
                            pjaId: null,
                            status: 0,
                          ),
                          eventImages: List<String>.from(_eventImages),
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

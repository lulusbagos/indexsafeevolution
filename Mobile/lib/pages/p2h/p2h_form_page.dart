import 'dart:io';

import 'package:date_time_picker/date_time_picker.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

import '../../models/p2h_tran_model.dart';
import '../../services/database.dart';
import '../../services/preference.dart';
import '../../widgets/button_app.dart';
import '../../widgets/sap_form_widgets.dart';
import '../../widgets/top_bar.dart';
import 'p2h_detail_page.dart';

class P2HFormPage extends StatefulWidget {
  const P2HFormPage({super.key});

  @override
  State<P2HFormPage> createState() => _P2HFormPageState();
}

class _P2HFormPageState extends State<P2HFormPage> {
  final _scrollCtrl = ScrollController();
  final _db = DatabaseService();
  final _profile = PreferenceService.getProfile();
  final _km = TextEditingController();
  final _remark = TextEditingController();
  final List<dynamic> _rawType = [];
  final List<MapEntry<dynamic, dynamic>> _jenisList = [];
  List<MapEntry<int, dynamic>> _vehicleList = [];
  MapEntry<int, dynamic>? _vehicleItem;
  DateTime? _date = DateTime.now();
  String? _time = DateFormat('hh:mm').format(DateTime.now());
  int? _companyId;
  String? _jenisId;
  int? _vehicleId;
  int _simper = 0;
  VideoPlayerController? _videoPlayer;
  File? _videoFile;
  bool _isVideo = false;

  @override
  void initState() {
    super.initState();
    _companyId = _profile?.companyId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _db.rawQuery('''select
        mv.id id_jenis_kendaraan,
        mv.type jenis_kendaraan,
        mv.code no_lambung_kendaraan,
        mv."name" merek_kendaraan
      from vehicle_masters mv
      where mv.deleted_at is null
      order by mv.type,mv.code''').then((val) {
        if (val.isNotEmpty) {
          setState(() {
            _rawType.addAll(val.toList());
            _jenisList.addAll({
              for (var row in val.toList())
                row['jenis_kendaraan']: row['jenis_kendaraan']
            }.entries.toList());
            _jenisList.sort((a, b) => (a.value).compareTo(b.value));
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

  void _getVehicle(String val) {
    _jenisId = val;
    _vehicleId = null;
    _vehicleItem = null;
    _vehicleList = {
      for (var row in _rawType
          .where((e) =>
              e['id_jenis_kendaraan'] != null && e['jenis_kendaraan'] == val)
          .toList())
        row['id_jenis_kendaraan'] as int: row['no_lambung_kendaraan']
    }.entries.toList();
    _vehicleList.sort((a, b) => (a.value).compareTo(b.value));
    _remark.text = '';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: const TopBar(title: 'P2H', back: 2),
        body: SingleChildScrollView(
          controller: _scrollCtrl,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tanggal',
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
                'Jam',
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
                'Jenis Kendaraan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField(
                initialValue: _jenisId,
                isExpanded: true,
                decoration: InputDecoration(
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Icon(
                      Icons.directions_car_filled,
                      size: 24,
                      color: Colors.indigo.shade400,
                    ),
                  ),
                ),
                style: const TextStyle(fontSize: 16),
                icon: const Icon(Icons.arrow_drop_down),
                items: _jenisList.map((item) {
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
                    _getVehicle(val!);
                  });
                },
              ),
              const SizedBox(height: 15),
              const Text(
                'No Lambung Kendaraan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              DropdownSearch<MapEntry<int, dynamic>>(
                selectedItem: _vehicleItem,
                dropdownDecoratorProps: DropDownDecoratorProps(
                  baseStyle: const TextStyle(fontSize: 16),
                  dropdownSearchDecoration: InputDecoration(
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Icon(
                        Icons.qr_code,
                        size: 24,
                        color: Colors.indigo.shade400,
                      ),
                    ),
                  ),
                ),
                items: _vehicleList.toList(),
                itemAsString: (MapEntry<int, dynamic>? e) => e?.value,
                popupProps: const PopupProps.menu(
                  fit: FlexFit.loose,
                  showSearchBox: true,
                ),
                onChanged: (val) {
                  setState(() {
                    _vehicleId = val!.key;
                    _vehicleItem = val;
                    var ve = _rawType
                        .where((e) => e['id_jenis_kendaraan'] as int == val.key)
                        .first as Map<String, dynamic>;
                    _remark.text = ve['merek_kendaraan'];
                  });
                },
              ),
              const SizedBox(height: 15),
              const Text(
                'Kilometer',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _km,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
                ],
                decoration: InputDecoration(
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Icon(
                      Icons.speed_outlined,
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
                'Merek Kendaraan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _remark,
                readOnly: true,
                decoration: InputDecoration(
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Icon(
                      Icons.filter_b_and_w,
                      size: 24,
                      color: Colors.indigo.shade400,
                    ),
                  ),
                ),
                style: const TextStyle(fontSize: 16),
                onChanged: (String val) => setState(() {}),
              ),
              const SizedBox(height: 25),
              Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _simper == 1,
                      activeColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(2.0),
                      ),
                      side: WidgetStateBorderSide.resolveWith(
                        (states) => const BorderSide(color: Colors.green),
                      ),
                      onChanged: (bool? val) {
                        setState(() => _simper = (val! ? 1 : 0));
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Apakah Anda memiliki SIMPER / KIMPER ?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
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
            onPressed: (_jenisId == null ||
                    _vehicleId == null ||
                    _km.text == '' ||
                    _remark.text == '' ||
                    _simper == 0)
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => P2HDetailPage(
                          p2hTrnModel: P2HTrnModel(
                            code:
                                '${_profile?.noNik}-${DateTime.now().millisecondsSinceEpoch}0000000000'
                                    .substring(0, 24),
                            title: _remark.text,
                            companyId: _companyId,
                            employeeId: _profile?.id,
                            vehicleId: _vehicleId,
                            hm: null,
                            km: double.parse(_km.text),
                            simper: _simper,
                            date: _date!.toString().substring(0, 10),
                            time: _time!,
                            image: null,
                            merek: _remark.text,
                            remark: _jenisId,
                            createdAt: DateTime.now().toString(),
                            updatedAt: DateTime.now().toString(),
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

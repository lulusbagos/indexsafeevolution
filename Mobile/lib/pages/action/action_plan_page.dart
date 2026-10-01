import 'dart:io';

import 'package:date_time_picker/date_time_picker.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../services/api.dart';
import '../../services/database.dart';
import '../../services/sync.dart';
import '../../utils/enums.dart';
import '../../utils/helpers.dart';
import '../../widgets/alert_app.dart';
import '../../widgets/button_app.dart';
import '../../widgets/snackbar_msg.dart';
import '../../widgets/top_bar.dart';
import '../../widgets/upload_files.dart';

class ActionPlanPage extends StatefulWidget {
  const ActionPlanPage(this.module, this.data, this.isPJA, {super.key});

  final Module module;
  final Map<String, dynamic> data;
  final bool isPJA;

  @override
  State<ActionPlanPage> createState() => _ActionPlanPageState();
}

class _ActionPlanPageState extends State<ActionPlanPage> {
  final _scrollCtrl = ScrollController();
  final _db = DatabaseService();
  final _api = ApiService();
  final _plan = TextEditingController();
  final _planDate = TextEditingController();
  final _overdue = TextEditingController();
  final _reason = TextEditingController();
  final _action = TextEditingController();
  final _actionDate = TextEditingController();
  final List<MapEntry<int, dynamic>> _picList = [];
  int? _pjaId;
  int? _picId;
  MapEntry<int, dynamic>? _picItem;
  VideoPlayerController? _videoPlayer;
  File? _videoFile;
  bool _isVideo = false;
  String? _image;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _db.rawQuery('''select
        e.id id_pic,
        e.no_nik nik_pic,
        e.nama_lengkap nama_pic,
        e.posisi jabatan_pic
      from employees e
      where e.deleted_at is null
      order by e.no_nik''').then((val) {
        if (val.isNotEmpty) {
          setState(() {
            _picList.addAll({
              for (var row in val.toList())
                row['id_pic'] as int: '${row['nik_pic']} - ${row['nama_pic']}'
            }.entries.toList());
            _picList.sort((a, b) => (a.value).compareTo(b.value));
          });
        }
      });

      setState(() {
        if (widget.data['pja_id'] != null) {
          _pjaId = widget.data['pja_id'];
        }
        if (widget.data['pic_id'] != null) {
          _picId = widget.data['pic_id'];
          _picItem = MapEntry(widget.data['pic_id'], widget.data['pic_name']);
        }
        if (widget.data['plan'] != null) {
          _plan.text = widget.data['plan'];
        }
        if (widget.data['plan_date'] != null) {
          _planDate.text = widget.data['plan_date'];
        }
        if (widget.data['overdue'] != null) {
          _overdue.text = '${widget.data['overdue']}';
        }
        if (widget.data['reason'] != null) {
          _reason.text = widget.data['reason'];
        }
        if (widget.data['action'] != null) {
          _action.text = widget.data['action'];
        }
        if (widget.data['action_date'] != null) {
          _actionDate.text = widget.data['action_date'];
        }
        if (widget.data['action_image'] != null &&
            widget.data['action_image'] != '' &&
            File(widget.data['action_image']).existsSync()) {
          _image = widget.data['action_image'];
        }
      });
    });
  }

  @override
  void dispose() {
    /** */

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: TopBar(title: 'Action ${pageTitle(widget.module)}', back: 2),
        body: SingleChildScrollView(
          controller: _scrollCtrl,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.isPJA == true) ...[
                const Text(
                  'PIC Perbaikan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                DropdownSearch<MapEntry<int, dynamic>>(
                  selectedItem: _picItem,
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
                  items: _picList.toList(),
                  itemAsString: (MapEntry<int, dynamic>? e) => e?.value,
                  popupProps: const PopupProps.menu(
                    fit: FlexFit.loose,
                    showSearchBox: true,
                  ),
                  onChanged: (val) {
                    setState(() {
                      _picId = val!.key;
                      _picItem = val;
                    });
                  },
                ),
                const SizedBox(height: 15),
                if (_pjaId != null && _pjaId != _picId) ...[
                  Card.filled(
                    color: Colors.yellow.shade100,
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Text(
                        'PJA Dapat Menugaskan Dirinya Sebagai PIC Perbaikan.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                ],
              ],
              if (widget.isPJA == false ||
                  (_pjaId != null && _pjaId == _picId)) ...[
                const Text(
                  'Rencana Perbaikan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _plan,
                  minLines: 3,
                  maxLines: 3,
                  decoration: InputDecoration(
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Icon(
                        Icons.note_alt_outlined,
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
                  'Due Date Perbaikan',
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
                  controller: _planDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100),
                  dateLabelText: 'Date',
                  timeLabelText: 'Hour',
                  onChanged: (String val) => setState(() {}),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Over Due',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _overdue,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                  onChanged: (String val) => setState(() {}),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Alasan Over Due',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _reason,
                  minLines: 3,
                  maxLines: 3,
                  decoration: InputDecoration(
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Icon(
                        Icons.note_alt_outlined,
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
                  'Tindakan Perbaikan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _action,
                  minLines: 3,
                  maxLines: 3,
                  decoration: InputDecoration(
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Icon(
                        Icons.note_alt_outlined,
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
                  'Tanggal Perbaikan',
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
                  controller: _actionDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100),
                  dateLabelText: 'Date',
                  timeLabelText: 'Hour',
                  onChanged: (String val) => setState(() {}),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Upload Foto',
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
                                'Upload Foto',
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
                if (_image != null) const UploadFiles('ActionPlan', null),
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
            ],
          ),
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: buttonApp(
            label: (widget.isPJA) ? 'Kirim' : 'Simpan',
            onPressed: ((widget.isPJA == true && _picId == null) ||
                    (widget.isPJA == false &&
                        (_plan.text == '' || _planDate.text == '')))
                ? null
                : () async {
                    try {
                      var row = <String, dynamic>{};
                      for (var e in (widget.data).entries) {
                        if (e.value != null) {
                          row[e.key] = e.value;
                        }
                      }
                      row['pic_id'] = _picId;
                      row['updated_at'] = null;
                      if (widget.isPJA == true) {
                        row['status'] = 1;
                      }
                      if (widget.isPJA == false ||
                          (_pjaId != null && _pjaId == _picId)) {
                        row['plan'] = _plan.text;
                        row['plan_date'] = _planDate.text;
                        row['overdue'] = _overdue.text;
                        row['reason'] = _reason.text;
                        row['action'] = _action.text;
                        row['action_date'] = _actionDate.text;
                        row['action_image'] = _image;
                        row['status'] =
                            (_action.text != '' && _actionDate.text != '')
                                ? 2
                                : 1;
                      }
                      row.remove('area_name');
                      row.remove('location_name');
                      row.remove('pja_name');
                      row.remove('pic_name');
                      row.remove('sync_id');
                      _db
                          .update('action_plans', row, row['id'] as int)
                          .then((tranId) {
                        if (tranId > 0) {
                          syncAction(_db, _api, row['table'], row['id'] as int)
                              .then((sync) {
                            if (sync == true) {
                              SnackBarMsg.success(context, 'Berhasil sinkron!');
                            } else {
                              SnackBarMsg.danger(context, 'Gagal sinkron!');
                            }
                          });
                          alertSuccess(context, widget.module,
                              msg: 'dikirim', lastId: tranId);
                        } else {
                          alertFailed(context, widget.module, msg: 'dikirim');
                        }
                      });
                    } catch (e) {
                      debugPrint(e.toString());
                      alertFailed(context, widget.module, msg: 'dikirim');
                    }
                  },
          ),
        ),
      ),
    );
  }
}

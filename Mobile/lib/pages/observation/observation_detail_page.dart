import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/observation_detail_model.dart';
import '../../models/observation_tran_model.dart';
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

class ObservationDetailPage extends StatefulWidget {
  const ObservationDetailPage({this.observationTrnModel, super.key});

  final ObservationTrnModel? observationTrnModel;

  @override
  State<ObservationDetailPage> createState() => _ObservationDetailPageState();
}

class _ObservationDetailPageState extends State<ObservationDetailPage> {
  final _scrollCtrl = ScrollController();
  final _db = DatabaseService();
  final _api = ApiService();
  final _remark = TextEditingController();
  final List<ObservationDetailModel> _itemList = [];
  final List<MapEntry<int, dynamic>> _perihalList = [];
  final List<MapEntry<int, dynamic>> _hasilList = [];
  int? _perihalId;
  int? _hasilId;
  int _pointId = 0;
  String? _image;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _db.dropFiles('ObservationDetail');

      _db.rawQuery('''select
        id id_perihal_yang_diobservasi,
        "name" perihal_yang_diobservasi
      from observation_masters om 
      where om.deleted_at is null and type = 'point'
      order by om."name"''').then((val) {
        if (val.isNotEmpty) {
          setState(() {
            _perihalList.addAll({
              for (var row in val.toList())
                row['id_perihal_yang_diobservasi'] as int:
                    row['perihal_yang_diobservasi']
            }.entries.toList());
            _perihalList.sort((a, b) => (a.value).compareTo(b.value));
          });
        }
      });

      _db.rawQuery('''select
        id id_hasil_observasi,
        "name" hasil_observasi
      from observation_masters om 
      where om.deleted_at is null and type = 'result'
      order by om."name"''').then((val) {
        if (val.isNotEmpty) {
          setState(() {
            _hasilList.addAll({
              for (var row in val.toList())
                row['id_hasil_observasi'] as int: row['hasil_observasi']
            }.entries.toList());
            _hasilList.sort((a, b) => (a.value).compareTo(b.value));
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

  Future<dynamic> _showBottomSheet() {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) {
        return StatefulBuilder(builder: (context, setState_) {
          return FractionallySizedBox(
            heightFactor:
                0.95 + (MediaQuery.of(context).viewInsets.bottom / 530),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Perihal yang Diobservasi',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField(
                    initialValue: _perihalId,
                    isExpanded: true,
                    style: const TextStyle(fontSize: 16),
                    icon: const Icon(Icons.arrow_drop_down),
                    items: _perihalList.map((item) {
                      return DropdownMenuItem<int>(
                        value: item.key,
                        child: Text(
                          item.value.toString(),
                          style: const TextStyle(
                              fontSize: 16, color: Colors.black),
                        ),
                      );
                    }).toList(),
                    onChanged: (int? val) {
                      setState_(() {
                        _perihalId = val!;
                      });
                    },
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Hasil Observasi',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField(
                    initialValue: _hasilId,
                    isExpanded: true,
                    style: const TextStyle(fontSize: 16),
                    icon: const Icon(Icons.arrow_drop_down),
                    items: _hasilList.map((item) {
                      return DropdownMenuItem<int>(
                        value: item.key,
                        child: Text(
                          item.value.toString(),
                          style: const TextStyle(
                              fontSize: 16, color: Colors.black),
                        ),
                      );
                    }).toList(),
                    onChanged: (int? val) {
                      setState_(() {
                        _hasilId = val!;
                      });
                    },
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Keterangan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _remark,
                    minLines: 3,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 16),
                    onChanged: (String val) => setState_(() {}),
                  ),
                  const SizedBox(height: 15),
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
                                      setState_(() => _image = value.path);
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
                                      setState_(() => _image = value.path);
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
                  if (_image != null)
                    UploadFiles('ObservationDetail', _pointId),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: MediaQuery.of(context).size.width,
                    child: buttonApp(
                      label: 'Tambah',
                      onPressed: (_perihalId == null ||
                              _hasilId == null ||
                              _remark.text == '')
                          ? null
                          : () {
                              var point = _perihalList
                                  .where((i) => i.key == _perihalId)
                                  .first
                                  .value;
                              var type = _hasilList
                                  .where((i) => i.key == _hasilId)
                                  .first
                                  .value;

                              setState(() {
                                _itemList.add(ObservationDetailModel(
                                  name: '$point - $type',
                                  point: point,
                                  type: type.substring(0, 1),
                                  image: _image,
                                  remark: _remark.text,
                                  pointId: _pointId,
                                ));
                                _perihalId = null;
                                _hasilId = null;
                                _image = null;
                                _remark.text = '';
                                Navigator.pop(context);
                              });
                            },
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: const TopBar(title: 'Detail Observation', back: 2),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ListView.builder(
            controller: _scrollCtrl,
            shrinkWrap: true,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: _itemList.length,
            itemBuilder: (context, index) {
              return Card(
                color: Colors.white,
                shadowColor: Colors.indigo,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(
                    (_itemList[index].name ?? '').trim(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.indigo,
                    ),
                  ),
                  subtitle: Text(
                    (_itemList[index].remark ?? '').trim(),
                  ),
                  trailing: SizedBox(
                    width: 20,
                    child: IconButton(
                      padding: const EdgeInsets.all(0),
                      alignment: Alignment.centerRight,
                      icon: Icon(
                        Icons.cancel,
                        color: Colors.red.shade400,
                        size: 18,
                      ),
                      onPressed: () {
                        setState(() => _itemList.removeAt(index));
                      },
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              );
            },
          ),
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          height: 150,
          child: Column(
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width,
                child: buttonApp(
                  label: 'Masukkan Hasil Observasi',
                  bgColor: Colors.green,
                  onPressed: () {
                    setState(() => _pointId = _pointId + 1);
                    _showBottomSheet();
                  },
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: MediaQuery.of(context).size.width,
                child: buttonApp(
                  label: 'Simpan',
                  onPressed: (_itemList.isEmpty)
                      ? null
                      : () {
                          widget.observationTrnModel?.createdAt =
                              DateTime.now().toString();
                          widget.observationTrnModel?.updatedAt =
                              DateTime.now().toString();
                          try {
                            _db
                                .insert('observation_trans',
                                    widget.observationTrnModel!.toJson())
                                .then((tranId) {
                              if (tranId > 0) {
                                syncTran(_db, _api, 'observation', tranId)
                                    .then((sync) {
                                  if (sync == true) {
                                    SnackBarMsg.success(
                                        context, 'Berhasil sinkron!');
                                  } else {
                                    SnackBarMsg.danger(
                                        context, 'Gagal sinkron!');
                                  }
                                });
                                for (var row in _itemList) {
                                  row.tranId = tranId;
                                  row.status = 0;
                                  _db
                                      .insert(
                                          'observation_details', row.toJson())
                                      .then((itemId) {
                                    _db.saveFiles('ObservationDetail',
                                        row.pointId!, tranId, itemId);
                                  });
                                }
                                alertSuccess(context, Module.observation,
                                    lastId: tranId);
                              } else {
                                alertFailed(context, Module.observation);
                              }
                            });
                          } catch (e) {
                            debugPrint(e.toString());
                            alertFailed(context, Module.observation);
                          }
                        },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

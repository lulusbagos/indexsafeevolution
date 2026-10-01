import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/inspect_detail_model.dart';
import '../../utils/enums.dart';
import '../../utils/globals.dart' as globals;
import '../../utils/helpers.dart';
import '../../widgets/button_app.dart';
import '../../widgets/top_bar.dart';
import '../../widgets/upload_files.dart';

class SimamaCheckitemPage extends StatefulWidget {
  const SimamaCheckitemPage(this.module, this.checkList, {super.key});

  final Module module;
  final InspectDetailModel checkList;

  @override
  State<SimamaCheckitemPage> createState() => _SimamaCheckitemPageState();
}

class _SimamaCheckitemPageState extends State<SimamaCheckitemPage> {
  final _scrollCtrl = ScrollController();
  bool _ready = false;

  @override
  void initState() {
    super.initState();

    // setState(() {
    //   widget.checkList.yesno = 1;
    //   widget.checkList.repair = 1;
    //   widget.checkList.image = '';
    //   widget.checkList.remark = '';
    //   widget.checkList.repairImage = '';
    //   widget.checkList.repairRemark = '';
    // });

    Future.delayed(const Duration(milliseconds: 100), () {
      setState(() {
        _ready = true;
        // widget.checkList.yesno = null;
        // widget.checkList.repair = null;
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
    return Scaffold(
      appBar: TopBar(title: 'Checklist ${pageTitle(widget.module)}'),
      body: SingleChildScrollView(
        controller: _scrollCtrl,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: (_ready == false)
            ? Container()
            : Container(
                padding: const EdgeInsets.all(20),
                width: MediaQuery.of(context).size.width,
                decoration: BoxDecoration(
                  color: Colors.white54,
                  border: Border.all(color: Colors.indigo.shade200),
                  borderRadius: const BorderRadius.all(Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Text(
                      widget.checkList.name ?? '',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.indigo,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 40,
                          child: Radio(
                            activeColor: Colors.green,
                            value: 1,
                            groupValue: widget.checkList.yesno,
                            onChanged: (value) {
                              setState(() => widget.checkList.yesno = 1);
                            },
                          ),
                        ),
                        const Text('YA'),
                        const SizedBox(width: 40),
                        SizedBox(
                          width: 40,
                          child: Radio(
                            activeColor: Colors.red,
                            value: 0,
                            groupValue: widget.checkList.yesno,
                            onChanged: (value) {
                              setState(() => widget.checkList.yesno = 0);
                            },
                          ),
                        ),
                        const Text('TIDAK'),
                        const SizedBox(width: 20),
                        SizedBox(
                          width: 40,
                          child: Radio(
                            activeColor: Colors.blue,
                            value: 2,
                            groupValue: widget.checkList.yesno,
                            onChanged: (value) {
                              setState(() => widget.checkList.yesno = 2);
                            },
                          ),
                        ),
                        const Text('N/A'),
                      ],
                    ),
                    Visibility(
                      visible: widget.checkList.yesno == 0,
                      child: InkWell(
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
                                          setState(() => widget
                                              .checkList.image = value.path);
                                        }
                                      });
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.image,
                                        color: Colors.grey),
                                    title: const Text('Gallery'),
                                    onTap: () {
                                      Navigator.pop(context);
                                      Future<File?> imageFile = pickImage(
                                          source: ImageSource.gallery);
                                      imageFile.then((value) {
                                        if (value != null) {
                                          setState(() => widget
                                              .checkList.image = value.path);
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
                          child: widget.checkList.image == null ||
                                  widget.checkList.image == ''
                              ? const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.camera_alt,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(height: 5),
                                    Text(
                                      'Upload Foto Temuan',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                )
                              : Image.file(File(widget.checkList.image!)),
                        ),
                      ),
                    ),
                    if (widget.checkList.image != null &&
                        widget.checkList.image != '')
                      Visibility(
                        visible: widget.checkList.yesno == 0,
                        child: UploadFiles(
                            'SimamaCheckitem1', widget.checkList.pointId),
                      ),
                    Visibility(
                      visible: widget.checkList.yesno == 0,
                      child: Column(
                        children: [
                          const SizedBox(height: 30),
                          const Text(
                            'Keterangan Temuan',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            maxLines: 2,
                            initialValue: widget.checkList.remark,
                            onChanged: (value) {
                              setState(() => widget.checkList.remark = value);
                              Future.delayed(const Duration(milliseconds: 200),
                                  () {
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
                    Visibility(
                      visible: (widget.checkList.yesno == 100 &&
                              widget.checkList.remark != '')
                          ? true
                          : false,
                      child: Container(
                        margin: const EdgeInsets.only(top: 30),
                        width: MediaQuery.of(context).size.width,
                        child: Card(
                          color: Colors.yellow.shade200,
                          shadowColor: Colors.transparent,
                          child: const Padding(
                            padding: EdgeInsets.all(5),
                            child: Text(
                              'Apakah temuan dapat diselesaikan saat ini?',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Visibility(
                      visible: (widget.checkList.yesno == 100 &&
                              widget.checkList.remark != '')
                          ? true
                          : false,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 40,
                            child: Radio(
                              activeColor: Colors.green,
                              value: 1,
                              groupValue: widget.checkList.repair,
                              onChanged: (value) {
                                setState(() => widget.checkList.repair = 1);
                                Future.delayed(
                                    const Duration(milliseconds: 200), () {
                                  _scrollCtrl.animateTo(
                                    _scrollCtrl.position.maxScrollExtent,
                                    duration: const Duration(milliseconds: 500),
                                    curve: Curves.easeOut,
                                  );
                                });
                              },
                            ),
                          ),
                          const Text('YA'),
                          const SizedBox(width: 50),
                          SizedBox(
                            width: 40,
                            child: Radio(
                              activeColor: Colors.red,
                              value: 0,
                              groupValue: widget.checkList.repair,
                              onChanged: (value) {
                                setState(() => widget.checkList.repair = 0);
                              },
                            ),
                          ),
                          const Text('TIDAK'),
                        ],
                      ),
                    ),
                    Visibility(
                      visible: (widget.checkList.yesno == 100 &&
                          widget.checkList.repair == 1),
                      child: InkWell(
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
                                          setState(() => widget.checkList
                                              .repairImage = value.path);
                                        }
                                      });
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.image,
                                        color: Colors.grey),
                                    title: const Text('Gallery'),
                                    onTap: () {
                                      Navigator.pop(context);
                                      Future<File?> imageFile = pickImage(
                                          source: ImageSource.gallery);
                                      imageFile.then((value) {
                                        if (value != null) {
                                          setState(() => widget.checkList
                                              .repairImage = value.path);
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
                          child: widget.checkList.repairImage == null ||
                                  widget.checkList.repairImage == ''
                              ? const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.camera_alt,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(height: 5),
                                    Text(
                                      'Upload Foto Perbaikan',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                )
                              : Image.file(File(widget.checkList.repairImage!)),
                        ),
                      ),
                    ),
                    if (widget.checkList.repairImage != null)
                      Visibility(
                        visible: (widget.checkList.yesno == 100 &&
                            widget.checkList.repair == 1),
                        child: UploadFiles(
                            'SimamaCheckitem2', widget.checkList.pointId),
                      ),
                    Visibility(
                      visible: (widget.checkList.yesno == 100 &&
                          widget.checkList.repair == 1),
                      child: Column(
                        children: [
                          const SizedBox(height: 30),
                          const Text(
                            'Keterangan Perbaikan',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            maxLines: 2,
                            initialValue: widget.checkList.repairRemark,
                            onChanged: (value) {
                              setState(
                                  () => widget.checkList.repairRemark = value);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: buttonApp(
          label: 'Lanjut',
          onPressed: (widget.checkList.yesno == null)
              ? null
              : () {
                  if (widget.checkList.yesno == 0 &&
                      (widget.checkList.remark == '')) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Silahkan lengkapi keterangan temuan yang belum diisi!',
                          style: TextStyle(color: Colors.white),
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  if (widget.checkList.repair == 1 &&
                      (widget.checkList.repairRemark == '')) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Silahkan lengkapi keterangan perbaikan yang belum diisi!',
                          style: TextStyle(color: Colors.white),
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  // if (widget.checkList?.repair == 1) {
                  //   widget.checkList?.yesno = widget.checkList?.repair;
                  // }

                  globals.checkList = widget.checkList;
                  Future.delayed(const Duration(milliseconds: 500), () {
                    Navigator.pop(context, false);
                  });
                },
        ),
      ),
    );
  }
}

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/file_model.dart';
import '../services/database.dart';

class UploadFiles extends StatefulWidget {
  const UploadFiles(this.type, this.pointId, {super.key});

  final String? type;
  final int? pointId;

  @override
  State<UploadFiles> createState() => _UploadFilesState();
}

class _UploadFilesState extends State<UploadFiles> {
  final _db = DatabaseService();
  final List<FileModel> _itemList = [];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getFiles();
    });
  }

  @override
  void dispose() {
    /** */

    super.dispose();
  }

  void _getFiles() {
    if (widget.pointId == null) return;
    _itemList.clear();
    _db.rawQuery(
        '''select * from files where deleted_at is null and type='${widget.type}' and point_id=${widget.pointId} and tran_id is null and detail_id is null order by id desc''').then((val) {
      for (var row in val.toList()) {
        _itemList.add(FileModel.fromJson(row as Map<String, dynamic>));
      }
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return (widget.pointId != null)
        ? Column(
            children: [
              const SizedBox(height: 10),
              Container(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(100, 30),
                  ),
                  onPressed: () async {
                    var result = await FilePicker.platform.pickFiles(
                      allowMultiple: true,
                      type: FileType.custom,
                      allowedExtensions: ['jpg', 'jpeg', 'png', 'gif'],
                    );
                    if (result != null) {
                      int i = 1;
                      for (var path in result.paths) {
                        _db
                            .insert(
                                'files',
                                FileModel(
                                  name: path,
                                  type: widget.type,
                                  pointId: widget.pointId,
                                ).toJson())
                            .then((val) {
                          if (i == result.paths.length) _getFiles();
                          i++;
                        });
                      }
                    }
                  },
                  child: const Text('+ Upload Foto Lainnya'),
                ),
              ),
              const SizedBox(height: 10),
              (_itemList.isNotEmpty)
                  ? SizedBox(
                      height: 100,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (var item in _itemList)
                            Container(
                              margin: const EdgeInsets.only(right: 10),
                              height: 90,
                              child: Image.file(File(item.name!)),
                            )
                        ],
                      ),
                    )
                  : Container(),
            ],
          )
        : Container();
  }
}

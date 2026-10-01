import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/file_model.dart';
import '../services/database.dart';
import '../widgets/top_bar.dart';

class UploadPage extends StatefulWidget {
  const UploadPage(this.title, {super.key});

  final String? title;

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final _scrollCtrl = ScrollController();
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
    _itemList.clear();
    _db.rawQuery(
        '''select * from files where deleted_at is null order by id desc''').then((val) {
      for (var row in val.toList()) {
        _itemList.add(FileModel.fromJson(row as Map<String, dynamic>));
      }
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const TopBar(title: 'Upload File'),
      body: Column(
        children: [
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
                  allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'mp4'],
                );
                if (result != null) {
                  int i = 1;
                  for (var path in result.paths) {
                    _db
                        .insert('files', FileModel(name: path).toJson())
                        .then((val) {
                      if (i == result.paths.length) _getFiles();
                      i++;
                    });
                  }
                }
              },
              child: const Text('+ Upload Multiple Files'),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              shrinkWrap: true,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
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
                          _db.delete('files', _itemList[index].id!).then((val) {
                            _getFiles();
                          });
                        },
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

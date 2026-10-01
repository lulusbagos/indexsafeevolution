import 'package:flutter/material.dart';

import '../../models/p5m_detail_model.dart';
import '../../models/p5m_tran_model.dart';
import '../../services/api.dart';
import '../../services/database.dart';
import '../../services/preference.dart';
import '../../services/sync.dart';
import '../../utils/enums.dart';
import '../../utils/globals.dart' as globals;
import '../../widgets/alert_app.dart';
import '../../widgets/button_app.dart';
import '../../widgets/snackbar_msg.dart';
import '../../widgets/top_bar.dart';

class P5MDetailPage extends StatefulWidget {
  const P5MDetailPage({this.p5mTrnModel, super.key});

  final P5MTrnModel? p5mTrnModel;

  @override
  State<P5MDetailPage> createState() => _P5MDetailPageState();
}

class _P5MDetailPageState extends State<P5MDetailPage> {
  final _scrollCtrl = ScrollController();
  final _db = DatabaseService();
  final _api = ApiService();
  final _profile = PreferenceService.getProfile();
  final List<dynamic> _rawData = [];
  final Map<int, P5MDetailModel> _checkList = {};

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      int usia = 0;
      if (_profile?.tglLahir != null && _profile?.tglLahir != '') {
        try {
          usia = DateTime.now().year -
              int.parse(_profile!.tglLahir!.substring(0, 4));
        } catch (e) {
          debugPrint(e.toString());
        }
      }

      int onsite = 1;
      if (_profile?.userId != null &&
          globals.onsite[_profile?.userId] != null) {
        onsite = globals.onsite[_profile?.userId]! + 1;
      }
      if (onsite > 42) onsite = 1;

      _db.dropFiles('P5MDetail');

      _db.rawQuery('''select
        pmm.id,
        pmm."name"
      from p5m_masters pmm
      where pmm.deleted_at is null and pmm.type = 'detail'
      order by pmm.id''').then((val) {
        if (val.isNotEmpty) {
          setState(() {
            _rawData.addAll(val.toList());
            for (var row in val.toList()) {
              var remark = '';
              if (row['name'].toString().toLowerCase().contains('umur anda')) {
                remark = '$usia';
              }
              if (row['name'].toString().toLowerCase().contains('42 hari')) {
                remark = '$onsite';
              }
              _checkList[row['id'] as int] = P5MDetailModel(
                pointId: row['id'] as int,
                name: row['name'] as String,
                remark: remark,
              );
            }
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: const TopBar(title: 'Checklist P5M', back: 2),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              width: MediaQuery.of(context).size.width,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.green,
                  minimumSize: const Size(100, 30),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text(
                          'Tentukan Nilai Awal Jawaban',
                          textAlign: TextAlign.center,
                        ),
                        content: SizedBox(
                          height: 125,
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      textStyle: Theme.of(context)
                                          .textTheme
                                          .labelLarge,
                                    ),
                                    child: const Text('YA'),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      for (var i in _checkList.keys) {
                                        _checkList[i]?.yesno = 1;
                                      }
                                      setState(() {});
                                    },
                                  ),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      textStyle: Theme.of(context)
                                          .textTheme
                                          .labelLarge,
                                    ),
                                    child: const Text('TIDAK'),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      for (var i in _checkList.keys) {
                                        _checkList[i]?.yesno = 0;
                                      }
                                      setState(() {});
                                    },
                                  ),
                                  const Text('atau'),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      textStyle: Theme.of(context)
                                          .textTheme
                                          .labelLarge,
                                    ),
                                    child: const Text('KOSONG'),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      for (var i in _checkList.keys) {
                                        _checkList[i]?.yesno = null;
                                      }
                                      setState(() {});
                                    },
                                  ),
                                ],
                              ),
                              Card(
                                color: Colors.yellow.shade200,
                                shadowColor: Colors.transparent,
                                margin: const EdgeInsets.only(top: 10),
                                child: const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: Text(
                                    'pastikan anda tetap melakukan cek setiap list P5M',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            style: TextButton.styleFrom(
                              textStyle: Theme.of(context).textTheme.labelLarge,
                            ),
                            child: const Text('Cancel'),
                            onPressed: () {
                              Navigator.pop(context);
                            },
                          ),
                        ],
                        actionsPadding: const EdgeInsets.all(0),
                        actionsAlignment: MainAxisAlignment.center,
                      );
                    },
                  );
                },
                child: const Text('Tentukan nilai awal jawaban'),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollCtrl,
                shrinkWrap: true,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                itemCount: _rawData.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Row(
                      children: [
                        SizedBox(width: 30, child: Text('${index + 1}.')),
                        Flexible(
                          child: Text(
                            _rawData[index]['name'] ?? '',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.indigo,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(left: 20),
                      child: Column(
                        children: [
                          (_checkList[_rawData[index]['id']]!
                                  .name
                                  .toString()
                                  .toLowerCase()
                                  .contains('umur anda'))
                              ? const SizedBox(height: 10)
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 40,
                                      child: Radio(
                                        activeColor: Colors.green,
                                        value: 1,
                                        groupValue:
                                            _checkList[_rawData[index]['id']]
                                                ?.yesno,
                                        onChanged: (value) {
                                          setState(() =>
                                              _checkList[_rawData[index]['id']]
                                                  ?.yesno = 1);
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
                                        groupValue:
                                            _checkList[_rawData[index]['id']]
                                                ?.yesno,
                                        onChanged: (value) {
                                          setState(() =>
                                              _checkList[_rawData[index]['id']]
                                                  ?.yesno = 0);
                                        },
                                      ),
                                    ),
                                    const Text('TIDAK'),
                                  ],
                                ),
                          TextFormField(
                            minLines: 1,
                            maxLines: 1,
                            style: const TextStyle(fontSize: 16),
                            initialValue:
                                _checkList[_rawData[index]['id']]?.remark,
                            onChanged: (String val) => setState(() =>
                                _checkList[_rawData[index]['id']]?.remark =
                                    val),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: buttonApp(
            label: 'Simpan',
            onPressed: (_checkList.isEmpty ||
                    [for (var e in _checkList.entries) e.value]
                        .where((i) =>
                            i.yesno == null &&
                            !i.name
                                .toString()
                                .toLowerCase()
                                .contains('umur anda'))
                        .isNotEmpty)
                ? null
                : () {
                    widget.p5mTrnModel?.createdAt = DateTime.now().toString();
                    widget.p5mTrnModel?.updatedAt = DateTime.now().toString();
                    try {
                      _db
                          .insert('p5m_trans', widget.p5mTrnModel!.toJson())
                          .then((tranId) {
                        if (tranId > 0) {
                          syncTran(_db, _api, 'p5m', tranId).then((sync) {
                            if (sync == true) {
                              SnackBarMsg.success(context, 'Berhasil sinkron!');
                            } else {
                              SnackBarMsg.danger(context, 'Gagal sinkron!');
                            }
                          });
                          var items = [
                            for (var e in _checkList.entries) e.value
                          ];
                          for (var row in items) {
                            row.tranId = tranId;
                            row.status = (row.yesno == 0) ? 0 : 1;
                            if (row.name
                                    .toString()
                                    .toLowerCase()
                                    .contains('42 hari') &&
                                row.remark != '') {
                              globals.onsite[_profile!.userId!] =
                                  int.tryParse(row.remark!) ?? 0;
                            }
                            _db
                                .insert('p5m_details', row.toJson())
                                .then((itemId) {
                              _db.saveFiles(
                                  'P5MDetail', row.pointId!, tranId, itemId);
                            });
                          }
                          alertSuccess(context, Module.p5m, lastId: tranId);
                        } else {
                          alertFailed(context, Module.p5m);
                        }
                      });
                    } catch (e) {
                      debugPrint(e.toString());
                      alertFailed(context, Module.p5m);
                    }
                  },
          ),
        ),
      ),
    );
  }
}

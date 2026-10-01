import 'package:flutter/material.dart';

import '../../models/p2h_detail_model.dart';
import '../../models/p2h_tran_model.dart';
import '../../services/api.dart';
import '../../services/database.dart';
import '../../services/sync.dart';
import '../../utils/enums.dart';
import '../../widgets/alert_app.dart';
import '../../widgets/button_app.dart';
import '../../widgets/snackbar_msg.dart';
import '../../widgets/top_bar.dart';

class P2HDetailPage extends StatefulWidget {
  const P2HDetailPage({this.p2hTrnModel, super.key});

  final P2HTrnModel? p2hTrnModel;

  @override
  State<P2HDetailPage> createState() => _P2HDetailPageState();
}

class _P2HDetailPageState extends State<P2HDetailPage> {
  final _scrollCtrl = ScrollController();
  final _db = DatabaseService();
  final _api = ApiService();
  final List<dynamic> _rawData = [];
  List<dynamic> _typeList = [];
  final Map<int, P2HDetailModel> _checkList = {};

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _db.dropFiles('P2HDetail');

      _db.rawQuery(
          '''select id, code, name, type, ref_id, 0 as isExpanded from p2h_masters
      where deleted_at is null
      order by code asc''').then((val) {
        if (val.isNotEmpty) {
          setState(() {
            _rawData.addAll(val.toList());
            _typeList = val
                .toList()
                .where((e) => e['type'] == 'header')
                .toList()
                .map((e) {
              return {
                'id': e['id'],
                'code': e['code'],
                'name': e['name'],
                'isExpanded': 0
              };
            }).toList();
            for (var row in val.toList()) {
              if (row['type'] == 'detail') {
                _checkList[row['id'] as int] = P2HDetailModel(
                  pointId: row['id'] as int,
                  name: row['name'] as String,
                  type: '${row['ref_id']}',
                  remark: '',
                );
              }
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
        appBar: const TopBar(title: 'Checklist P2H', back: 2),
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
                                    child: const Text('GOOD'),
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
                                    child: const Text('BAD'),
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
                                    'pastikan anda tetap melakukan cek setiap list P2H',
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
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
                child: ExpansionPanelList(
                  elevation: 0,
                  materialGapSize: 0,
                  expansionCallback: (int index, bool isExpanded) {
                    setState(() {
                      _typeList[index]['isExpanded'] = isExpanded ? 1 : 0;
                    });
                  },
                  children: _typeList.map<ExpansionPanel>((dynamic type) {
                    return ExpansionPanel(
                      canTapOnHeader: true,
                      headerBuilder: (BuildContext context, bool isExpanded) {
                        return ListTile(
                          title: Text(
                            type['name'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        );
                      },
                      body: listItems(context, type),
                      isExpanded: (type['isExpanded'] as int == 1),
                    );
                  }).toList(),
                ),
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
                            i.yesno == null || (i.yesno == 0 && i.remark == ''))
                        .isNotEmpty)
                ? null
                : () {
                    widget.p2hTrnModel?.createdAt = DateTime.now().toString();
                    widget.p2hTrnModel?.updatedAt = DateTime.now().toString();
                    try {
                      _db
                          .insert('p2h_trans', widget.p2hTrnModel!.toJson())
                          .then((tranId) {
                        if (tranId > 0) {
                          syncTran(_db, _api, 'p2h', tranId).then((sync) {
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
                            _db
                                .insert('p2h_details', row.toJson())
                                .then((itemId) {
                              _db.saveFiles(
                                  'P2HDetail', row.pointId!, tranId, itemId);
                            });
                          }
                          alertSuccess(context, Module.p2h, lastId: tranId);
                        } else {
                          alertFailed(context, Module.p2h);
                        }
                      });
                    } catch (e) {
                      debugPrint(e.toString());
                      alertFailed(context, Module.p2h);
                    }
                  },
          ),
        ),
      ),
    );
  }

  Widget listItems(BuildContext context, dynamic type) {
    return Column(
      children: [
        ..._rawData
            .where((e) =>
                e['ref_id'] != null && e['ref_id'] as int == type['id'] as int)
            .toList()
            .asMap()
            .entries
            .map(
              (item) => ListTile(
                title: Row(
                  children: [
                    SizedBox(width: 30, child: Text('${item.key + 1}.')),
                    Flexible(
                      child: Text(
                        item.value['name'] ?? '',
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 40,
                            child: Radio(
                              activeColor: Colors.green,
                              value: 1,
                              groupValue: _checkList[item.value['id']]?.yesno,
                              onChanged: (value) {
                                setState(() =>
                                    _checkList[item.value['id']]?.yesno = 1);
                              },
                            ),
                          ),
                          const Text('GOOD'),
                          const SizedBox(width: 50),
                          SizedBox(
                            width: 40,
                            child: Radio(
                              activeColor: Colors.red,
                              value: 0,
                              groupValue: _checkList[item.value['id']]?.yesno,
                              onChanged: (value) {
                                setState(() =>
                                    _checkList[item.value['id']]?.yesno = 0);
                              },
                            ),
                          ),
                          const Text('BAD'),
                        ],
                      ),
                      (_checkList[item.value['id']]?.yesno != null &&
                              _checkList[item.value['id']]?.yesno == 0)
                          ? TextFormField(
                              minLines: 2,
                              maxLines: 2,
                              style: const TextStyle(fontSize: 16),
                              initialValue:
                                  _checkList[item.value['id']]?.remark,
                              onChanged: (String val) => setState(() =>
                                  _checkList[item.value['id']]?.remark = val),
                            )
                          : Container(),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

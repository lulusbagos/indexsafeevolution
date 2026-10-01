import 'package:flutter/material.dart';

import '../../models/inspect_detail_model.dart';
import '../../models/inspect_tran_model.dart';
import '../../services/api.dart';
import '../../services/database.dart';
import '../../services/sync.dart';
import '../../utils/enums.dart';
import '../../utils/globals.dart' as globals;
import '../../utils/helpers.dart';
import '../../widgets/alert_app.dart';
import '../../widgets/button_app.dart';
import '../../widgets/snackbar_msg.dart';
import '../../widgets/top_bar.dart';
import 'daily_checkitem_page.dart';

class DailyChecklistPage extends StatefulWidget {
  const DailyChecklistPage(this.module, {this.inspectTrnModel, super.key});

  final Module module;
  final InspectTrnModel? inspectTrnModel;

  @override
  State<DailyChecklistPage> createState() => _DailyChecklistPageState();
}

class _DailyChecklistPageState extends State<DailyChecklistPage> {
  final _scrollCtrl = ScrollController();
  final _db = DatabaseService();
  final _api = ApiService();
  final List<dynamic> _rawData = [];
  final List<InspectDetailModel> _checkList = [];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _db.dropFiles('DailyCheckitem1');
      _db.dropFiles('DailyCheckitem2');

      _db.rawQuery('''select
        im.id id_list_pertanyaan,
        im."name" list_pertanyaan
      from inspection_masters im
      where im.deleted_at is null and code='DLYI'
      order by im.id''').then((val) {
        if (val.isNotEmpty) {
          setState(() {
            _rawData.addAll(val.toList());
            for (var row in _rawData) {
              _checkList.add(InspectDetailModel(
                pointId: row['id_list_pertanyaan'] as int,
                name: row['list_pertanyaan'] as String,
                image: '',
                remark: '',
                repair: 0,
                repairImage: '',
                repairRemark: '',
              ));
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
        appBar: TopBar(title: 'Checklist ${pageTitle(widget.module)}', back: 2),
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
                                    child: const Text('TIDAK'),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      for (var i = 0;
                                          i < _checkList.length;
                                          i++) {
                                        _checkList[i].yesno = 0;
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
                                    child: const Text('N/A'),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      for (var i = 0;
                                          i < _checkList.length;
                                          i++) {
                                        _checkList[i].yesno = 2;
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
                                      for (var i = 0;
                                          i < _checkList.length;
                                          i++) {
                                        _checkList[i].yesno = null;
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
                                    'pastikan anda tetap melakukan cek setiap list inspeksi',
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
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _rawData.length,
                itemBuilder: (context, index) {
                  return Card(
                    color: (_checkList[index].yesno == 0
                        ? Colors.green.shade50
                        : (_checkList[index].yesno == 1
                            ? Colors.red.shade50
                            : Colors.white)),
                    shadowColor: (_checkList[index].yesno == 0
                        ? Colors.green
                        : (_checkList[index].yesno == 1
                            ? Colors.red
                            : Colors.indigo)),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.indigo.shade400,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11),
                        ),
                      ),
                      title: Text(
                        _checkList[index].name ?? '',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.indigo,
                        ),
                      ),
                      subtitle: Text(
                        'Jawab: ${(_checkList[index].yesno == null ? '' : globals.yesNo[_checkList[index].yesno])}',
                        textAlign: TextAlign.left,
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.indigo.shade400,
                        size: 18,
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 10),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DailyCheckitemPage(
                              widget.module,
                              InspectDetailModel.fromJson(
                                  _checkList[index].toJson()),
                            ),
                          ),
                        ).then((value) {
                          if (value == false) {
                            Future.delayed(const Duration(milliseconds: 500),
                                () {
                              if (globals.checkList?.yesno != null) {
                                setState(() =>
                                    _checkList[index] = globals.checkList!);
                              }
                            });
                          }
                        });
                      },
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
                    _checkList.where((i) => i.yesno == null).isNotEmpty)
                ? null
                : () {
                    widget.inspectTrnModel?.createdAt =
                        DateTime.now().toString();
                    widget.inspectTrnModel?.updatedAt =
                        DateTime.now().toString();
                    try {
                      _db
                          .insert('inspection_trans',
                              widget.inspectTrnModel!.toJson())
                          .then((tranId) {
                        if (tranId > 0) {
                          syncTran(_db, _api, 'inspection', tranId)
                              .then((sync) {
                            if (sync == true) {
                              SnackBarMsg.success(context, 'Berhasil sinkron!');
                            } else {
                              SnackBarMsg.danger(context, 'Gagal sinkron!');
                            }
                          });
                          for (var row in _checkList) {
                            row.tranId = tranId;
                            row.status = (row.yesno == 1) ? 0 : 1;
                            _db
                                .insert('inspection_details', row.toJson())
                                .then((itemId) {
                              _db.saveFiles('DailyCheckitem1', row.pointId!,
                                  tranId, itemId);
                              _db.saveFiles('DailyCheckitem2', row.pointId!,
                                  tranId, itemId);
                            });
                          }
                          alertSuccess(context, widget.module, lastId: tranId);
                        } else {
                          alertFailed(context, widget.module);
                        }
                      });
                    } catch (e) {
                      debugPrint(e.toString());
                      alertFailed(context, widget.module);
                    }
                  },
          ),
        ),
      ),
    );
  }
}

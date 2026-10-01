import 'package:flutter/material.dart';

import '../../models/file_model.dart';
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
import 'simama_checkitem_page.dart';

class SimamaChecklistPage extends StatefulWidget {
  const SimamaChecklistPage(
    this.module, {
    this.inspectTrnModel,
    this.eventImages = const [],
    super.key,
  });

  final Module module;
  final InspectTrnModel? inspectTrnModel;
  final List<String> eventImages;

  @override
  State<SimamaChecklistPage> createState() => _SimamaChecklistPageState();
}

class _SimamaChecklistPageState extends State<SimamaChecklistPage> {
  final _scrollCtrl = ScrollController();
  final _db = DatabaseService();
  final _api = ApiService();
  final List<dynamic> _rawData = [];
  final List<MapEntry<int, dynamic>> _locationList = [];
  final List<InspectDetailModel> _checkList = [];
  final Map<int, bool> _expandList = {};

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _db.dropFiles('SimamaCheckitem1');
      _db.dropFiles('SimamaCheckitem2');

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
      and me.id = ${widget.inspectTrnModel?.areaId}
      order by me."name",me2.id,im.id''').then((val) {
        if (val.isNotEmpty) {
          setState(() {
            _rawData.addAll(val.toList());
            _locationList.addAll({
              for (var row in val.toList())
                row['id_lokasi'] as int: row['lokasi']
            }.entries.toList());
            _locationList.sort((a, b) => (a.value).compareTo(b.value));

            for (var row in _locationList) {
              _expandList[row.key] = false;
            }

            for (var row in _rawData) {
              _checkList.add(InspectDetailModel(
                pointId: row['id_list_pertanyaan'] as int,
                name: row['list_pertanyaan'] as String,
                type: '${row['id_lokasi']}',
                locationId: row['id_lokasi'] as int,
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
                                    child: const Text('YA'),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      for (var i = 0;
                                          i < _checkList.length;
                                          i++) {
                                        _checkList[i].yesno = 1;
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
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
                child: ExpansionPanelList(
                  elevation: 0,
                  materialGapSize: 0,
                  expansionCallback: (int index, bool isExpanded) {
                    setState(() {
                      _expandList[_locationList[index].key] = isExpanded;
                    });
                  },
                  children: _locationList
                      .map<ExpansionPanel>((MapEntry<int, dynamic> lokasi) {
                    return ExpansionPanel(
                      canTapOnHeader: true,
                      headerBuilder: (BuildContext context, bool isExpanded) {
                        return ListTile(
                          title: Text(
                            lokasi.value,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        );
                      },
                      body: listItems(context, lokasi),
                      isExpanded: _expandList[lokasi.key] as bool,
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
                    _checkList.where((i) => i.yesno == null).isNotEmpty)
                ? null
                : () {
                    widget.inspectTrnModel?.createdAt =
                        DateTime.now().toString();
                    widget.inspectTrnModel?.updatedAt =
                        DateTime.now().toString();
                    // if (_locationList.isNotEmpty) {
                    //   widget.inspectTrnModel?.locationId = _locationList[0].key;
                    // }
                    try {
                      _db
                          .insert('inspection_trans',
                              widget.inspectTrnModel!.toJson())
                          .then((tranId) {
                        if (tranId > 0) {
                          syncTran(_db, _api, 'inspection', tranId)
                              .then((sync) {
                            if (!mounted) return;
                            if (sync == true) {
                              SnackBarMsg.success(
                                  this.context, 'Berhasil sinkron!');
                            } else {
                              SnackBarMsg.danger(
                                  this.context, 'Gagal sinkron!');
                            }
                          });
                          for (final path in widget.eventImages.skip(1)) {
                            _db.insert(
                              'files',
                              FileModel(
                                name: path,
                                type: 'SimamaForm',
                                pointId: 0,
                                tranId: tranId,
                              ).toJson(),
                            );
                          }
                          for (var row in _checkList) {
                            row.tranId = tranId;
                            row.status = (row.yesno == 0) ? 0 : 1;
                            _db
                                .insert('inspection_details', row.toJson())
                                .then((itemId) {
                              _db.saveFiles('SimamaCheckitem1', row.pointId!,
                                  tranId, itemId);
                              _db.saveFiles('SimamaCheckitem2', row.pointId!,
                                  tranId, itemId);
                            });
                          }
                          if (!mounted) return;
                          alertSuccess(this.context, widget.module,
                              lastId: tranId);
                        } else {
                          if (!mounted) return;
                          alertFailed(this.context, widget.module);
                        }
                      });
                    } catch (e) {
                      debugPrint(e.toString());
                      if (!mounted) return;
                      alertFailed(this.context, widget.module);
                    }
                  },
          ),
        ),
      ),
    );
  }

  Widget listItems(BuildContext context, MapEntry<int, dynamic> lokasi) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _checkList.length,
      itemBuilder: (context, index) {
        if (_checkList[index].locationId != lokasi.key) {
          return Container();
        }
        return Card(
          color: (_checkList[index].yesno == 1
              ? Colors.green.shade50
              : (_checkList[index].yesno == 0
                  ? Colors.red.shade50
                  : Colors.white)),
          shadowColor: (_checkList[index].yesno == 1
              ? Colors.green
              : (_checkList[index].yesno == 0 ? Colors.red : Colors.indigo)),
          margin: const EdgeInsets.only(bottom: 10, left: 15, right: 15),
          child: ListTile(
            leading: CircleAvatar(
              radius: 12,
              backgroundColor: Colors.indigo.shade400,
              child: Text(
                '${index + 1}',
                style: const TextStyle(color: Colors.white, fontSize: 11),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SimamaCheckitemPage(
                    widget.module,
                    InspectDetailModel.fromJson(_checkList[index].toJson()),
                  ),
                ),
              ).then((value) {
                if (value == false) {
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (globals.checkList?.yesno != null) {
                      setState(() => _checkList[index] = globals.checkList!);
                    }
                  });
                }
              });
            },
          ),
        );
      },
    );
  }
}

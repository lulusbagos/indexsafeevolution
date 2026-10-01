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
import 'inspeksi_checkitem_page.dart';

class InspeksiChecklistPage extends StatefulWidget {
  const InspeksiChecklistPage(
    this.module, {
    this.idx,
    this.inspectTrnModel,
    super.key,
  });

  final Module module;
  final int? idx;
  final InspectTrnModel? inspectTrnModel;

  @override
  State<InspeksiChecklistPage> createState() => _InspeksiChecklistPageState();
}

class _InspeksiChecklistPageState extends State<InspeksiChecklistPage> {
  final _scrollCtrl = ScrollController();
  final _db = DatabaseService();
  final _api = ApiService();
  final List<dynamic> _rawData = [];
  final List<InspectDetailModel> _checkList = [];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _db.dropFiles('InspeksiCheckitem1');
      _db.dropFiles('InspeksiCheckitem2');

      _db.rawQuery('''select
          im.id id_jenis_inspeksi,
          im."name" jenis_inspeksi,
          im2.id id_list_pertanyaan,
          im2.name list_pertanyaan
        from inspection_masters im
          left join inspection_masters im2 on im2.ref_id =im.id and im2.deleted_at is null
        where im.deleted_at is null and
          im.ref_id is null and
          im."name" like 'Inspeksi%' and 
          im.id = ${widget.inspectTrnModel?.inspectionId}
        order by im.name,im2.id''').then((val) {
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

          // _getHistory();
        }
      });
    });
  }

  @override
  void dispose() {
    /** */

    super.dispose();
  }

  Future<void> _addCustomQuestion() async {
    final questionCtrl = TextEditingController();
    final optionsCtrl =
        TextEditingController(text: 'Baik, Perlu Perbaikan, N/A');
    var answerType = 'yesno';

    final item = await showDialog<InspectDetailModel>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Tambah Pertanyaan Inspeksi'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Buat checkpoint sendiri jika list inspeksi belum mengakomodir kondisi lapangan.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: questionCtrl,
                      minLines: 2,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Pertanyaan / Checkpoint',
                        hintText:
                            'Contoh: Apakah akses kerja mitra sudah aman?',
                        prefixIcon: Icon(Icons.help_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: answerType,
                      decoration: const InputDecoration(
                        labelText: 'Jenis Jawaban',
                        prefixIcon: Icon(Icons.tune_rounded),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'yesno',
                          child: Text('YA / TIDAK / N/A'),
                        ),
                        DropdownMenuItem(
                          value: 'text',
                          child: Text('Free Text'),
                        ),
                        DropdownMenuItem(
                          value: 'radio_custom',
                          child: Text('Radio Custom'),
                        ),
                      ],
                      onChanged: (value) => setDialogState(
                        () => answerType = value ?? answerType,
                      ),
                    ),
                    if (answerType == 'radio_custom') ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: optionsCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Pilihan Jawaban',
                          hintText: 'Pisahkan dengan koma',
                          prefixIcon: Icon(Icons.format_list_bulleted_rounded),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () {
                    final question = questionCtrl.text.trim();
                    if (question.isEmpty) return;
                    Navigator.pop(
                      dialogContext,
                      InspectDetailModel(
                        pointId: -DateTime.now().millisecondsSinceEpoch,
                        name: question,
                        type: answerType,
                        flag: answerType == 'radio_custom'
                            ? optionsCtrl.text.trim()
                            : 'custom-mobile',
                        image: '',
                        remark: '',
                        repair: 0,
                        repairImage: '',
                        repairRemark: '',
                      ),
                    );
                  },
                  child: const Text('Tambah'),
                ),
              ],
            );
          },
        );
      },
    );

    if (item == null) return;
    setState(() => _checkList.add(item));
  }

  String _answerSummary(InspectDetailModel item) {
    if (item.type == 'text') {
      final answer = (item.remark ?? '').trim();
      return answer.isEmpty ? 'Jawab: belum diisi' : 'Jawab: $answer';
    }

    if (item.type == 'radio_custom') {
      final answer = (item.remark ?? '').trim();
      return answer.isEmpty ? 'Jawab: belum dipilih' : 'Jawab: $answer';
    }

    return 'Jawab: ${item.yesno == null ? '' : globals.yesNo[item.yesno]}';
  }

  // void _getHistory() {
  //   if (widget.idx == null) return;
  //   _db.rawQuery(
  //       '''select * from inspection_details where transaction_id=${widget.idx}''').then((val) {
  //     if (val.isNotEmpty) {
  //       // var map = Map.of(val[0] as Map<String, dynamic>);
  //       // var mod = InspectTrnModel.fromJson(map);
  //
  //       setState(() {
  //         //////////
  //       });
  //     }
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: TopBar(title: 'Checklist ${pageTitle(widget.module)}', back: 2),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
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
                                  textStyle:
                                      Theme.of(context).textTheme.labelLarge,
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
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _addCustomQuestion,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    label: const Text('Tambah Pertanyaan Custom'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollCtrl,
                shrinkWrap: true,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _checkList.length,
                itemBuilder: (context, index) {
                  return Card(
                    color: (_checkList[index].yesno == 1
                        ? Colors.green.shade50
                        : (_checkList[index].yesno == 0
                            ? Colors.red.shade50
                            : Colors.white)),
                    shadowColor: (_checkList[index].yesno == 1
                        ? Colors.green
                        : (_checkList[index].yesno == 0
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
                        _answerSummary(_checkList[index]),
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
                            builder: (context) => InspeksiCheckitemPage(
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
                            if (!mounted) return;
                            if (sync == true) {
                              SnackBarMsg.success(
                                  this.context, 'Berhasil sinkron!');
                            } else {
                              SnackBarMsg.danger(
                                  this.context, 'Gagal sinkron!');
                            }
                          });
                          for (var row in _checkList) {
                            row.tranId = tranId;
                            row.status =
                                (row.yesno == 0 && row.repair == 0) ? 0 : 1;
                            _db
                                .insert('inspection_details', row.toJson())
                                .then((itemId) {
                              _db.saveFiles('InspeksiCheckitem1', row.pointId!,
                                  tranId, itemId);
                              _db.saveFiles('InspeksiCheckitem2', row.pointId!,
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
}

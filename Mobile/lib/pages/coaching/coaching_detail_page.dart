import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';

import '../../models/coaching_detail_model.dart';
import '../../models/coaching_tran_model.dart';
import '../../services/api.dart';
import '../../services/database.dart';
import '../../services/sync.dart';
import '../../utils/enums.dart';
import '../../widgets/alert_app.dart';
import '../../widgets/button_app.dart';
import '../../widgets/snackbar_msg.dart';
import '../../widgets/top_bar.dart';

class CoachingDetailPage extends StatefulWidget {
  const CoachingDetailPage({this.coachingTrnModel, super.key});

  final CoachingTrnModel? coachingTrnModel;

  @override
  State<CoachingDetailPage> createState() => _CoachingDetailPageState();
}

class _CoachingDetailPageState extends State<CoachingDetailPage>
    with TickerProviderStateMixin {
  final _scrollCtrl = ScrollController();
  final _db = DatabaseService();
  final _api = ApiService();
  final _remark = TextEditingController();
  final List<CoachingDetailModel> _itemList = [];
  final List<MapEntry<int, dynamic>> _pesertaList = [];
  int? _pesertaId;
  MapEntry<int, dynamic>? _pesertaItem;
  String? _image;
  late final TabController _tabCtrl = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _db.dropFiles('CoachingForm');

      _db.rawQuery('''select
        e.id id_custodee,
        e.no_nik nik_custodee,
        e.nama_lengkap nama_custodee,
        e.posisi jabatan_custodee
      from employees e
      where e.deleted_at is null
      order by e.no_nik''').then((val) {
        if (val.isNotEmpty) {
          setState(() {
            _pesertaList.addAll({
              for (var row in val.toList())
                row['id_custodee'] as int:
                    '${row['nik_custodee']} - ${row['nama_custodee']}'
            }.entries.toList());
            _pesertaList.sort((a, b) => (a.value).compareTo(b.value));
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
                0.35 + (MediaQuery.of(context).viewInsets.bottom / 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TabBar(
                  controller: _tabCtrl,
                  tabs: const [
                    Tab(text: 'Daftar Peserta'),
                    Tab(text: 'Input Peserta (Manual)'),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  height: 100,
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      DropdownSearch<MapEntry<int, dynamic>>(
                        selectedItem: _pesertaItem,
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
                        items: _pesertaList.toList(),
                        itemAsString: (MapEntry<int, dynamic>? e) => e?.value,
                        popupProps: const PopupProps.menu(
                          fit: FlexFit.loose,
                          showSearchBox: true,
                        ),
                        onChanged: (val) {
                          setState_(() {
                            _pesertaId = val!.key;
                            _pesertaItem = val;
                          });
                        },
                      ),
                      TextFormField(
                        controller: _remark,
                        decoration: InputDecoration(
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 10),
                            child: Icon(
                              Icons.account_circle_outlined,
                              size: 24,
                              color: Colors.indigo.shade400,
                            ),
                          ),
                        ),
                        style: const TextStyle(fontSize: 16),
                        onChanged: (String val) => setState_(() {}),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  alignment: Alignment.centerRight,
                  child: buttonApp(
                    label: 'Tambah',
                    onPressed: ((_pesertaId == null || _pesertaItem == null) &&
                            _remark.text == '')
                        ? null
                        : () {
                            var peserta = _remark.text;
                            if (_tabCtrl.index == 0 && _pesertaId != null) {
                              peserta = _pesertaList
                                  .where((i) => i.key == _pesertaId)
                                  .first
                                  .value;
                            }

                            setState(() {
                              _itemList.add(CoachingDetailModel(
                                name: peserta,
                                remark: peserta,
                                image: _image,
                              ));
                              _pesertaId = null;
                              _pesertaItem = null;
                              _image = null;
                              _remark.text = '';
                              Navigator.pop(context);
                            });
                          },
                  ),
                ),
              ],
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
        appBar: const TopBar(title: 'Peserta Coaching', back: 2),
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
                  label: 'Tambah Peserta',
                  bgColor: Colors.green,
                  onPressed: () => _showBottomSheet(),
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
                          widget.coachingTrnModel?.createdAt =
                              DateTime.now().toString();
                          widget.coachingTrnModel?.updatedAt =
                              DateTime.now().toString();
                          try {
                            _db
                                .insert('coaching_trans',
                                    widget.coachingTrnModel!.toJson())
                                .then((tranId) {
                              if (tranId > 0) {
                                syncTran(_db, _api, 'coaching', tranId)
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
                                      .insert('coaching_details', row.toJson())
                                      .then((itemId) {
                                    _db.saveFiles('CoachingForm', row.pointId!,
                                        tranId, itemId);
                                  });
                                }
                                alertSuccess(context, Module.coaching,
                                    lastId: tranId);
                              } else {
                                alertFailed(context, Module.coaching);
                              }
                            });
                          } catch (e) {
                            debugPrint(e.toString());
                            alertFailed(context, Module.coaching);
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

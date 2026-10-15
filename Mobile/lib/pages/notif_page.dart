import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api.dart';
import '../services/database.dart';
import '../services/notification.dart';
import '../services/preference.dart';
import '../services/sync.dart';
import '../utils/enums.dart';
import '../utils/globals.dart' as globals;
import '../utils/helpers.dart';
import 'history/history_detail_page.dart';

class NotifPage extends StatefulWidget {
  const NotifPage({super.key});

  @override
  State<NotifPage> createState() => _NotifPageState();
}

class _NotifPageState extends State<NotifPage> {
  final _scrollCtrl = ScrollController();
  final _db = DatabaseService();
  final _api = ApiService();
  final _profile = PreferenceService.getProfile();
  List<dynamic> _rawData = [];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getData();

      Future.delayed(const Duration(milliseconds: 1000), () async {
        /* get actions */
        for (var name in ['inspection', 'hazard'].toList()) {
          debugPrint('--- get action: $name ---');
          _api.getAction(name).then((res) {
            res.fold((error) {
              debugPrint(error['message'].toString());
            }, (response) async {
              for (var item in (response['data'] as List).toList()) {
                var row = <String, dynamic>{};
                for (var e in (item as Map<String, dynamic>).entries) {
                  if (e.value != null) {
                    row[e.key] = e.value;
                  }
                }
                row.remove('created_by');
                row.remove('updated_by');
                row.remove('deleted_by');
                _db.get('action_plans', row['id'] as int).then((get) {
                  if (get == null) {
                    _db.insert('action_plans', row).then((insertId) {
                      debugPrint('--- insert action_plans: $insertId ---');
                      var profileId = _profile?.id;
                      var status = '';
                      if (row['employee_id'] != null &&
                          (row['employee_id'] as int) == profileId) {
                        status = 'Terkirim';
                      }
                      if (row['pja_id'] != null &&
                          (row['pja_id'] as int) == profileId) {
                        status = 'Masuk';
                      }
                      if (row['pic_id'] != null &&
                          (row['pic_id'] as int) == profileId) {
                        status = 'Masuk';
                      }
                      if (status != '') {
                        NotificationService.display(
                          title: titleCase('${row['category']} $status'),
                          body: titleCase(row['title'] ?? ''),
                        );
                        _getData();
                      }
                    });
                  } else {
                    if ((row['status'] ?? 0) > (get['status'] ?? 0)) {
                      _db
                          .update('action_plans', row, row['id'] as int)
                          .then((tot) {
                        if (tot > 0) {
                          debugPrint(
                              '--- update action_plans: ${row['id']} ---');
                          var profileId = _profile?.id;
                          var status = '';
                          if (row['status'] as int == 1) {
                            if (row['employee_id'] != null &&
                                (row['employee_id'] as int) == profileId) {
                              status = 'Diproses PJA';
                            }
                          }
                          if (row['status'] as int == 2) {
                            if (row['employee_id'] != null &&
                                (row['employee_id'] as int) == profileId) {
                              status = 'Diproses PIC';
                            }
                            if (row['pja_id'] != null &&
                                (row['pja_id'] as int) == profileId) {
                              status = 'Diproses PIC';
                            }
                          }
                          if (status != '') {
                            NotificationService.display(
                              title: titleCase('${row['category']} $status'),
                              body: titleCase(row['title'] ?? ''),
                            );
                            _getData();
                          }
                        }
                      });
                    }
                  }
                });
              }
            });
          });
          await Future.delayed(const Duration(seconds: 2));
        }

        /* post actions */
        debugPrint('--- post action plans ---');
        _db.rawQuery('''select id, `table` from action_plans where deleted_at is null and updated_at is null and status > 0''').then(
            (val) async {
          if (val.isNotEmpty) {
            for (var row in val.toList()) {
              syncAction(_db, _api, row['table'], row['id'] as int);
              await Future.delayed(const Duration(seconds: 2));
            }
          }
        });
      });
    });
  }

  @override
  void dispose() {
    /** */

    super.dispose();
  }

  void _getData() {
    _db.rawQuery(
        '''select tr.*, me1.name as area_name, me2.name as location_name, 1 as sync_id,
          (select e.nama_lengkap from employees e where e.id=tr.pja_id) as pja_name,
          (select e.nama_lengkap from employees e where e.id=tr.pic_id) as pic_name
          from action_plans tr
          left join enum_masters me1 on me1.type='area' and me1.id=tr.area_id and me1.deleted_at is null
          left join enum_masters me2 on me2.type='location' and me2.id=tr.location_id and me2.deleted_at is null
          where tr.deleted_at is null and ((tr.pja_id=${_profile?.id} and tr.status<1) or (tr.pic_id=${_profile?.id} and tr.status<2))
          order by tr.id desc''').then((val) async {
      await PreferenceService.setNotif(val.length);
      if (val.isNotEmpty) {
        if (!mounted) return;
        setState(() => _rawData = val.toList());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification'),
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: (_rawData.isNotEmpty)
            ? ListView.builder(
                controller: _scrollCtrl,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _rawData.length,
                itemBuilder: (context, index) {
                  var date = DateTime.parse(_rawData[index]['date']);
                  return Card(
                    color: Colors.white,
                    shadowColor: Colors.green,
                    child: ListTile(
                      title: Text(
                        titleCase(_rawData[index]['title'] ?? ''),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.indigo,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              'Note: ${titleCase(_rawData[index]['remark'] ?? '')}'),
                          Text(
                              'Area: ${titleCase(_rawData[index]['area_name'] ?? '')}'),
                          Text(
                              'Lokasi: ${titleCase(_rawData[index]['location_name'] ?? '')}'),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Text(
                                  '${DateFormat('dd/MM/yyyy').format(date)} ${_rawData[index]['time']}'),
                              Expanded(
                                child: Container(),
                              ),
                              Text(
                                  '${globals.status[_rawData[index]['status'] as int]}',
                                  style: TextStyle(
                                    color: globals.statusColor[
                                        _rawData[index]['status'] as int],
                                    fontWeight: FontWeight.bold,
                                  )),
                            ],
                          ),
                        ],
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.indigo.shade400,
                        size: 18,
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 10),
                      onTap: () {
                        Module module;
                        switch (_rawData[index]['category']) {
                          case 'inspection':
                            module = Module.inspection;
                            break;
                          case 'inspectionDaily':
                            module = Module.inspectionDaily;
                            break;
                          case 'inspectionWeekly':
                            module = Module.inspectionWeekly;
                            break;
                          case 'simama':
                            module = Module.simama;
                            break;
                          default:
                            module = Module.hazard;
                            break;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HistoryDetailPage(
                              module,
                              History.action,
                              _rawData[index] as Map<String, dynamic>,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              )
            : Container(
                margin: const EdgeInsets.only(top: 100),
                width: MediaQuery.of(context).size.width,
                child: const Column(
                  children: [
                    Image(
                      image: AssetImage('assets/images/no-data.png'),
                      width: 180,
                    ),
                    SizedBox(height: 30),
                    Text(
                      'Data Notification Tidak Ditemukan!',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

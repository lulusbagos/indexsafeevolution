import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/helpers.dart';
import 'api.dart';
import 'database.dart';
import 'notification.dart';
import 'preference.dart';
import 'sync.dart';

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  final db = DatabaseService();
  final api = ApiService();
  final prefs = await SharedPreferences.getInstance();

  service.on('stop').listen((event) {
    service.stopSelf();
    debugPrint('background process is now stopped');
  });

  service.on('start').listen((event) {});

  Timer.periodic(const Duration(minutes: 30), (timer) async {
    try {
      prefs.reload();

      /* post details */
      if ((prefs.getString('bgToken') ?? '') != '') {
        api.setToken = prefs.getString('bgToken') ?? '';
        for (var name in [
          'inspection',
          'coaching',
          'k3',
          'observation',
          'p2h',
          'p5m'
        ].toList()) {
          debugPrint('--- post detail: $name ---');
          db.rawQuery(
              '''select dt.id from ${name}_details dt inner join ${name}_trans tr on dt.tran_id = tr.id 
          where dt.sync_id is null and tr.sync_id is not null''').then((val) async {
            if (val.isNotEmpty) {
              for (var row in val.toList()) {
                syncDetail(db, api, name, row['id'] as int);
                await Future.delayed(const Duration(seconds: 2));
              }
            }
          });
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  });

  Timer.periodic(const Duration(minutes: 50), (timer) async {
    try {
      prefs.reload();

      /* post files */
      if ((prefs.getString('bgToken') ?? '') != '') {
        api.setToken = prefs.getString('bgToken') ?? '';
        for (var name in ['inspection', 'hazard'].toList()) {
          debugPrint('--- post file: $name ---');
          db.rawQuery('''select id from files where sync_id is null and tran_id is not null''').then(
              (val) async {
            if (val.isNotEmpty) {
              for (var row in val.toList()) {
                syncFiles(db, api, name, row['id'] as int);
                await Future.delayed(const Duration(seconds: 2));
              }
            }
          });
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  });

  Timer.periodic(const Duration(minutes: 70), (timer) async {
    try {
      prefs.reload();

      /* get actions */
      if ((prefs.getString('bgToken') ?? '') != '') {
        api.setToken = prefs.getString('bgToken') ?? '';
        for (var name in ['inspection', 'hazard'].toList()) {
          debugPrint('--- get action: $name ---');
          api.getAction(name).then((res) {
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
                db.get('action_plans', row['id'] as int).then((get) {
                  if (get == null) {
                    db.insert('action_plans', row).then((insertId) {
                      debugPrint('--- insert action_plans: $insertId ---');
                      var profileId = prefs.getInt('bgProfile') ?? 0;
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
                      }
                    });
                  } else {
                    if ((row['status'] ?? 0) > (get['status'] ?? 0)) {
                      db
                          .update('action_plans', row, row['id'] as int)
                          .then((tot) {
                        if (tot > 0) {
                          debugPrint(
                              '--- update action_plans: ${row['id']} ---');
                          var profileId = prefs.getInt('bgProfile') ?? 0;
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
      }

      /* post actions */
      if ((prefs.getString('bgToken') ?? '') != '') {
        api.setToken = prefs.getString('bgToken') ?? '';
        debugPrint('--- post action plans ---');
        db.rawQuery('''select id, `table` from action_plans where deleted_at is null and updated_at is null and status > 0''').then(
            (val) async {
          if (val.isNotEmpty) {
            for (var row in val.toList()) {
              syncAction(db, api, row['table'], row['id'] as int);
              await Future.delayed(const Duration(seconds: 2));
            }
          }
        });
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  });

  Timer.periodic(const Duration(minutes: 90), (timer) async {
    try {
      prefs.reload();

      /* get masters */
      if ((prefs.getString('bgToken') ?? '') != '') {
        api.setToken = prefs.getString('bgToken') ?? '';
        for (var name in [
          'employee',
          'enum',
          'bridges',
          'inspection',
          'hazard',
          'coaching',
          'k3',
          'observation',
          'p2h',
          'p5m',
          'safety',
          'vehicle'
        ].toList()) {
          debugPrint('--- get master: $name ---');

          var table = '';
          switch (name) {
            case 'employee':
              table = 'employees';
              break;
            case 'bridges':
              table = 'enum_bridges';
              break;
            default:
              table = '${name}_masters';
              break;
          }

          if (table == '') continue;
          var row1 = await db.rawQuery(
              'select updated_at from $table where updated_at is not null order by updated_at desc limit 1');
          var row2 = await db.rawQuery(
              'select created_at from $table where created_at is not null order by created_at desc limit 1');
          var lastUpdated = (row1.isNotEmpty) ? row1[0]['updated_at'] : null;
          var lastCreated = (row2.isNotEmpty) ? row2[0]['created_at'] : null;

          api.getMaster(name).then((res) {
            res.fold((error) {
              debugPrint(error['message'].toString());
            }, (response) async {
              for (var item in (response['data'] as List).toList()) {
                if (item['updated_at'] != null &&
                    lastUpdated != null &&
                    DateTime.parse(item['updated_at'])
                            .compareTo(DateTime.parse(lastUpdated)) <=
                        0) {
                  continue;
                } else if (item['updated_at'] == null &&
                    item['created_at'] != null &&
                    lastCreated != null &&
                    DateTime.parse(item['created_at'])
                            .compareTo(DateTime.parse(lastCreated)) <=
                        0) {
                  continue;
                }
                var row = <String, dynamic>{};
                for (var e in (item as Map<String, dynamic>).entries) {
                  if (e.value != null) {
                    row[e.key] = e.value;
                  }
                }
                row.remove('created_by');
                row.remove('updated_by');
                row.remove('deleted_by');
                db.update(table, row, row['id'] as int).then((tot) {
                  if (tot == 0) {
                    db.insert(table, row).then((insertId) {
                      debugPrint('--- insert $table: $insertId ---');
                    });
                  } else {
                    debugPrint('--- update $table: ${row['id']} ---');
                  }
                });
              }
            });
          });
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  });
}

class BackgroundService {
  static final BackgroundService instance = BackgroundService._internal();
  factory BackgroundService() {
    return instance;
  }
  BackgroundService._internal();

  void start() {
    final service = FlutterBackgroundService();
    service.startService();
  }

  void stop() {
    final service = FlutterBackgroundService();
    service.invoke('stop');
  }

  Future<bool> isRunning() async {
    final service = FlutterBackgroundService();
    return await service.isRunning();
  }

  Future<void> init() async {
    final service = FlutterBackgroundService();
    final isEnabled = PreferenceService.isBackgroundSyncEnabled();
    await service.configure(
      iosConfiguration: IosConfiguration(
        autoStart: isEnabled,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
      androidConfiguration: AndroidConfiguration(
        autoStart: isEnabled,
        onStart: onStart,
        isForegroundMode: false, // Hilangkan notifikasi persisten background service di status bar
        autoStartOnBoot: isEnabled,
      ),
    );
  }
}

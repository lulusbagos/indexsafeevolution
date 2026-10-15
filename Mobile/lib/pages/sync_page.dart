import 'package:flutter/material.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';

import '../models/profile_model.dart';
import '../services/api.dart';
import '../services/database.dart';
import '../services/preference.dart';
import '../utils/globals.dart' as globals;
import '../utils/helpers.dart';
import '../widgets/snackbar_msg.dart';
import 'home_page.dart';
import 'login_page.dart';

class SyncPage extends StatefulWidget {
  const SyncPage(this.profile, {super.key});

  final ProfileModel? profile;

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  final _progress = ValueNotifier(0);
  final _db = DatabaseService();
  final _api = ApiService();
  final _dataSync = PreferenceService.getDataSync();
  final _masters = [
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
    'employee',
    'vehicle'
  ];
  String _name = '';
  String _table = '...';

  @override
  void initState() {
    super.initState();

    globals.currentPage = 0;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      setState(
          () => _name = (widget.profile?.namaLengkap?.split(' ')[0] ?? ''));
      try {
        var master = <String, int>{};
        var x = 1;
        for (var name in _masters.toList()) {
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

          if (_dataSync != null && (_dataSync![name] ?? 0) == 1) {
            x++;
            master[name] = 1;
            PreferenceService.setDataSync(master);
            continue;
          }

          _progress.value = 0;
          _api.getMaster(name).then((res) {
            res.fold((error) async {
              debugPrint(error['message'].toString());
              SnackBarMsg.danger(context, titleCase('Sync Data $name Error!'));
              x++;
            }, (response) async {
              var i = 1;
              var n = (response['data'] as List).length;
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
                _db.insert(table, row).then((insertId) {
                  debugPrint('--- insert $table: $insertId ---');
                  _progress.value = (i / n * 100).floor();
                  if (i == 1) {
                    x++;
                    setState(() => _table = name);
                  }
                  if (i >= n && x >= _masters.length) {
                    Future.delayed(const Duration(milliseconds: 3000), () {
                      _complete();
                    });
                  }
                  i++;
                });
              }
              master[name] = 1;
              PreferenceService.setDataSync(master);
            });
          });
          await Future.delayed(const Duration(seconds: 2));
        }
      } catch (e) {
        debugPrint(e.toString());
      }
    });
  }

  @override
  void dispose() {
    /** */

    super.dispose();
  }

  void _complete() async {
    globals.reSync = false;
    var dataSync = PreferenceService.getDataSync();
    if (dataSync != null && dataSync.length >= _masters.length) {
      if (!mounted) return;
      await Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
        (route) => false,
      );
    } else {
      if (!mounted) return;
      await Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Expanded(
              child: Center(
                child: Image(
                  image: AssetImage('assets/images/data-sync.gif'),
                  width: 300,
                ),
              ),
            ),
            Card.filled(
              color: Colors.blueGrey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    Text(
                      'Halo ${titleCase(_name)}, Semangat Pagi!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18),
                    ),
                    Text(
                      (globals.reSync == true)
                          ? 'Kami sedang melakukan sinkronisasi ulang master data, mohon menunggu sebentar'
                          : (_dataSync != null &&
                                  _dataSync!.length < _masters.length)
                              ? 'Masih terdapat master data yang belum sinkron, mohon menunggu sebentar'
                              : 'Selamat datang di aplikasi MBS SAP, kami sedang melakukan sinkronisasi master data, mohon menunggu sebentar',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            ValueListenableBuilder(
              valueListenable: _progress,
              builder: (context, value, snapshot) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '${_progress.value}%',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      'Sync Data $_table'.toUpperCase(),
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 15),
                    LinearPercentIndicator(
                      barRadius: const Radius.circular(10),
                      lineHeight: 15,
                      percent: _progress.value / 100,
                      backgroundColor: Colors.grey.shade300,
                      progressColor: Colors.green,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

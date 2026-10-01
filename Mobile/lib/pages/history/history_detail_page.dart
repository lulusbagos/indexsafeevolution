import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/profile_model.dart';
import '../../services/api.dart';
import '../../services/database.dart';
import '../../services/preference.dart';
import '../../services/sync.dart';
import '../../utils/enums.dart';
import '../../utils/globals.dart' as globals;
import '../../utils/helpers.dart';
import '../../widgets/button_app.dart';
import '../../widgets/top_bar.dart';
import '../action/action_plan_page.dart';

class HistoryDetailPage extends StatefulWidget {
  const HistoryDetailPage(this.module, this.history, this.data, {super.key});

  final Module module;
  final History history;
  final Map<String, dynamic> data;

  @override
  State<HistoryDetailPage> createState() => _HistoryDetailPageState();
}

class _HistoryDetailPageState extends State<HistoryDetailPage> {
  final _db = DatabaseService();
  final _api = ApiService();
  Map<String, pw.Widget> _imgTemuan = {};
  Map<String, pw.Widget> _imgPerbaikan = {};
  ProfileModel? _profile;
  List<dynamic> _rawData = [];
  List<dynamic> _rawType = [];
  List<dynamic> _rawFile1 = [];
  List<dynamic> _rawFile2 = [];
  bool? _isPJA;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.history == History.action) {
        var profile = PreferenceService.getProfile();
        if ((widget.data['pja_id'] ?? 0) == profile?.id) {
          setState(() => _isPJA = true);
        } else if ((widget.data['pic_id'] ?? 0) == profile?.id) {
          setState(() => _isPJA = false);
        }
      }

      if (widget.history == History.action ||
          widget.history == History.monitoring) {
        _getTemuan();
        _getPerbaikan();
      } else {
        _getDetail();
      }
    });
  }

  @override
  void dispose() {
    /** */

    super.dispose();
  }

  void _getDetail() {
    String table = '';

    switch (widget.module) {
      case Module.inspection:
      case Module.inspectionDaily:
      case Module.inspectionWeekly:
        table = 'inspection_details';
        break;
      case Module.simama:
        table = 'inspection_details';
        _db.rawQuery(
            '''select id, name from enum_masters where deleted_at is null and ref_id=${widget.data['area_id'] as int} order by id asc''').then((val) {
          if (val.isNotEmpty) {
            setState(() => _rawType = val.toList());
          }
        });
        break;
      case Module.coaching:
        table = 'coaching_details';
        break;
      case Module.observation:
        table = 'observation_details';
        break;
      case Module.p2h:
        table = 'p2h_details';
        _db.rawQuery(
            '''select id, code, name from p2h_masters where deleted_at is null and "type"='header' order by code asc''').then((val) {
          if (val.isNotEmpty) {
            setState(() => _rawType = val.toList());
          }
        });
        break;
      case Module.p5m:
        table = 'p5m_details';
        break;
      case Module.induction:
        table = 'k3_details';
        break;
      default:
        break;
    }

    if (table != '') {
      _db.rawQuery(
          '''select * from $table where tran_id=${widget.data['id'] as int}''').then((val) {
        if (val.isNotEmpty) {
          setState(() => _rawData = val.toList());
        }
      });

      _syncDetail(table, widget.data['id'] as int);
    }

    _db.get('employees', widget.data['employee_id']).then((val) {
      if (val.isNotEmpty) {
        setState(() =>
            _profile = ProfileModel.fromJson(val as Map<String, dynamic>));
      }
    });

    var type1 = 'XYZ';
    var type2 = 'XYZ';
    if (widget.module == Module.inspection) {
      type1 = 'InspeksiCheckitem1';
      type2 = 'InspeksiCheckitem2';
    }
    if (widget.module == Module.inspectionWeekly) {
      type1 = 'InspeksiCheckitem1';
      type2 = 'InspeksiCheckitem2';
    }
    if (widget.module == Module.inspectionDaily) {
      type1 = 'DailyCheckitem1';
      type2 = 'DailyCheckitem2';
    }
    if (widget.module == Module.simama) {
      type1 = 'SimamaCheckitem1';
      type2 = 'SimamaCheckitem2';
    }
    if (widget.module == Module.hazard) {
      type1 = 'HazardDetail1';
      type2 = 'HazardDetail2';
    }
    if (widget.module == Module.observation) {
      type1 = 'ObservationDetail';
    }
    _db.rawQuery(
        '''select * from files where type='$type1' and tran_id=${widget.data['id'] as int}''').then((val) {
      if (val.isNotEmpty) {
        setState(() => _rawFile1 = val.toList());
      }
    });
    _db.rawQuery(
        '''select * from files where type='$type2' and tran_id=${widget.data['id'] as int}''').then((val) {
      if (val.isNotEmpty) {
        setState(() => _rawFile2 = val.toList());
      }
    });
  }

  void _getTemuan() async {
    try {
      var temp = '${(await getTemporaryDirectory()).path}/';

      _imgTemuan = {};
      if (widget.data['image'] != null) {
        if (File(widget.data['image']).existsSync()) {
          setState(() => _imgTemuan[widget.data['image']] = pw.Image(
                pw.MemoryImage(File(widget.data['image']).readAsBytesSync()),
                height: 500,
                fit: pw.BoxFit.fitHeight,
              ));
        } else if (File(temp + widget.data['image']).existsSync()) {
          setState(() => _imgTemuan[temp + widget.data['image']] = pw.Image(
                pw.MemoryImage(
                    File(temp + widget.data['image']).readAsBytesSync()),
                height: 500,
                fit: pw.BoxFit.fitHeight,
              ));
        } else {
          await _api.dio.download(
            '${_api.baseUrl}/image/${widget.data['image']}',
            temp + widget.data['image'],
          );
          networkImage('${_api.baseUrl}/image/${widget.data['image']}')
              .then((val) {
            setState(() => _imgTemuan[widget.data['image']] = pw.Image(
                  val,
                  height: 500,
                  fit: pw.BoxFit.fitHeight,
                ));
          });
        }
      }

      var type = 'XYZ';
      var cat = widget.data['category'];
      if (cat == Module.inspection.name) type = 'InspeksiCheckitem1';
      if (cat == Module.inspectionWeekly.name) type = 'InspeksiCheckitem1';
      if (cat == Module.inspectionDaily.name) type = 'DailyCheckitem1';
      if (cat == Module.simama.name) type = 'SimamaCheckitem1';
      if (cat == Module.hazard.name) type = 'HazardDetail1';
      if (cat == Module.observation.name) type = 'ObservationDetail';

      var sql = (widget.data['detail_id'] == null)
          ? '''select * from files where type='$type' and tran_id=${widget.data['tran_id'] as int}'''
          : '''select * from files where type='$type' and tran_id=${widget.data['tran_id'] as int} and detail_id=${widget.data['detail_id'] as int}''';
      _db.rawQuery(sql).then((val) async {
        if (val.isNotEmpty) {
          for (var row in val.toList()) {
            if (row['name'] != null) {
              if (File(row['name']).existsSync()) {
                setState(() => _imgTemuan[row['name']] = pw.Image(
                      pw.MemoryImage(File(row['name']).readAsBytesSync()),
                      height: 500,
                      fit: pw.BoxFit.fitHeight,
                    ));
              } else if (File(temp + row['name']).existsSync()) {
                setState(() => _imgTemuan[temp + row['name']] = pw.Image(
                      pw.MemoryImage(
                          File(temp + row['name']).readAsBytesSync()),
                      height: 500,
                      fit: pw.BoxFit.fitHeight,
                    ));
              } else {
                await _api.dio.download(
                  '${_api.baseUrl}/image/${row['name']}',
                  temp + row['name'],
                );
                networkImage('${_api.baseUrl}/image/${row['name']}')
                    .then((val) {
                  setState(() => _imgTemuan[row['name']] = pw.Image(
                        val,
                        height: 500,
                        fit: pw.BoxFit.fitHeight,
                      ));
                });
              }
            }
          }
        }
      });
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void _getPerbaikan() async {
    try {
      var temp = '${(await getTemporaryDirectory()).path}/';

      _imgPerbaikan = {};
      if (widget.data['action_image'] != null) {
        if (File(widget.data['action_image']).existsSync()) {
          setState(() => _imgPerbaikan[widget.data['action_image']] = pw.Image(
                pw.MemoryImage(
                    File(widget.data['action_image']).readAsBytesSync()),
                height: 500,
                fit: pw.BoxFit.fitHeight,
              ));
        } else if (File(temp + widget.data['action_image']).existsSync()) {
          setState(() =>
              _imgPerbaikan[temp + widget.data['action_image']] = pw.Image(
                pw.MemoryImage(
                    File(temp + widget.data['action_image']).readAsBytesSync()),
                height: 500,
                fit: pw.BoxFit.fitHeight,
              ));
        } else {
          await _api.dio.download(
            '${_api.baseUrl}/image/${widget.data['action_image']}',
            temp + widget.data['action_image'],
          );
          networkImage('${_api.baseUrl}/image/${widget.data['action_image']}')
              .then((val) {
            setState(
                () => _imgPerbaikan[widget.data['action_image']] = pw.Image(
                      val,
                      height: 500,
                      fit: pw.BoxFit.fitHeight,
                    ));
          });
        }
      }

      var type = 'XYZ';
      var cat = widget.data['category'];
      if (cat == Module.inspection.name) type = 'InspeksiCheckite2';
      if (cat == Module.inspectionWeekly.name) type = 'InspeksiCheckitem2';
      if (cat == Module.inspectionDaily.name) type = 'DailyCheckitem2';
      if (cat == Module.simama.name) type = 'SimamaCheckitem2';
      if (cat == Module.hazard.name) type = 'HazardDetail2';

      var sql = (widget.data['detail_id'] == null)
          ? '''select * from files where type='$type' and tran_id=${widget.data['tran_id'] as int}'''
          : '''select * from files where type='$type' and tran_id=${widget.data['tran_id'] as int} and detail_id=${widget.data['detail_id'] as int}''';
      _db.rawQuery(sql).then((val) async {
        if (val.isNotEmpty) {
          for (var row in val.toList()) {
            if (row['name'] != null) {
              if (File(row['name']).existsSync()) {
                setState(() => _imgPerbaikan[row['name']] = pw.Image(
                      pw.MemoryImage(File(row['name']).readAsBytesSync()),
                      height: 500,
                      fit: pw.BoxFit.fitHeight,
                    ));
              } else if (File(temp + row['name']).existsSync()) {
                setState(() => _imgPerbaikan[temp + row['name']] = pw.Image(
                      pw.MemoryImage(
                          File(temp + row['name']).readAsBytesSync()),
                      height: 500,
                      fit: pw.BoxFit.fitHeight,
                    ));
              } else {
                await _api.dio.download(
                  '${_api.baseUrl}/image/${row['name']}',
                  temp + row['name'],
                );
                networkImage('${_api.baseUrl}/image/${row['name']}')
                    .then((val) {
                  setState(() => _imgPerbaikan[row['name']] = pw.Image(
                        val,
                        height: 500,
                        fit: pw.BoxFit.fitHeight,
                      ));
                });
              }
            }
          }
        }
      });
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void _syncDetail(table, tranId) {
    var name = table.replaceAll('_details', '');
    debugPrint('--- post detail: $name ---');
    _db.rawQuery(
        '''select dt.id from ${name}_details dt inner join ${name}_trans tr on dt.tran_id = tr.id 
          where dt.tran_id = $tranId and dt.sync_id is null and tr.sync_id is not null''').then((val) async {
      if (val.isNotEmpty) {
        for (var row in val.toList()) {
          syncDetail(_db, _api, name, row['id'] as int);
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    });

    debugPrint('--- post file: $name ---');
    _db.rawQuery('''select id from files where tran_id = $tranId and sync_id is null and tran_id is not null''').then(
        (val) async {
      if (val.isNotEmpty) {
        for (var row in val.toList()) {
          syncFiles(_db, _api, name, row['id'] as int);
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    });
  }

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    var tanggal = '${widget.data['date']} ${widget.data['time']}';
    var area = widget.data['area_name'] ?? '';
    var lokasi = widget.data['location_name'] ?? '';
    var lokasiDetail = widget.data['location_detail'] ?? '';

    final logo = await rootBundle.load('assets/images/indexsafe-logo-text.png');
    final logoBytes = logo.buffer.asUint8List();

    var pdf = pw.Document(
      version: PdfVersion.pdf_1_5,
      compress: true,
      title: pageTitle(widget.module),
      pageMode: PdfPageMode.fullscreen,
    );

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(30),
        header: (context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 20),
            child: pw.Image(pw.MemoryImage(logoBytes), width: 150),
          );
        },
        footer: (context) {
          return pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('${context.pageNumber}'),
          );
        },
        build: (context) {
          var fs1 = pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold);
          var fs2 = const pw.TextStyle(fontSize: 14);
          var fs3 = const pw.TextStyle(
              fontSize: 14, color: PdfColor.fromInt(0xFF1B4F72));
          var fs4 = pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            decoration: pw.TextDecoration.underline,
          );
          return [
            pw.Center(
              child:
                  pw.Text(pageTitle(widget.module).toUpperCase(), style: fs1),
            ),
            pw.Divider(height: 30, thickness: 1),
            if (_profile?.noNik != null) ...[
              pw.Text('NIK\t\t\t\t\t\t\t: ${_profile?.noNik}', style: fs2),
              pw.SizedBox(height: 5),
              pw.Text('Nama\t\t\t: ${_profile?.namaLengkap}', style: fs2),
              pw.Divider(height: 30, thickness: 1),
            ],
            pw.Text('Tanggal / Jam\t\t: $tanggal', style: fs2),
            if (widget.module != Module.p2h) ...[
              pw.SizedBox(height: 5),
              pw.Text(
                  'Area\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t: ${titleCase(area)}',
                  style: fs2),
              pw.SizedBox(height: 5),
              pw.Text(
                  'Lokasi\t\t\t\t\t\t\t\t\t\t\t\t\t\t: ${titleCase(lokasi)}',
                  style: fs2),
              pw.SizedBox(height: 5),
              pw.Text('Lokasi Detail\t\t\t\t: ${titleCase(lokasiDetail)}',
                  style: fs2),
            ],
            pw.Divider(height: 30, thickness: 1),
            if (widget.history == History.summary &&
                widget.module == Module.hazard) ...[
              pw.Text('Kategori Bahaya :', style: fs2),
              pw.SizedBox(height: 5),
              pw.Text(titleCase(widget.data['kategori_bahaya'] ?? ''),
                  style: fs3),
              pw.SizedBox(height: 5),
              pw.Text('Jenis Bahaya :', style: fs2),
              pw.SizedBox(height: 5),
              pw.Text(titleCase(widget.data['jenis_bahaya'] ?? ''), style: fs3),
              pw.SizedBox(height: 5),
              pw.Text('Jenis Ketidaksesuaian :', style: fs2),
              pw.SizedBox(height: 5),
              pw.Text(titleCase(widget.data['jenis_ketidaksesuaian'] ?? ''),
                  style: fs3),
              pw.SizedBox(height: 5),
              pw.Text('Tingkat Risiko :', style: fs2),
              pw.SizedBox(height: 5),
              pw.Text(titleCase(widget.data['tingkat_resiko'] ?? ''),
                  style: fs3),
              pw.SizedBox(height: 5),
              pw.Text('PJA :', style: fs2),
              pw.SizedBox(height: 5),
              pw.Text(titleCase(widget.data['pja_name'] ?? ''), style: fs3),
              pw.SizedBox(height: 5),
              pw.Divider(height: 30, thickness: 1),
              pw.Center(
                child: pw.Text(
                    'DETAIL ${pageTitle(widget.module).toUpperCase()}',
                    style: fs1),
              ),
              pw.SizedBox(height: 5),
              pw.Text('Foto Temuan :', style: fs2),
              pw.SizedBox(height: 5),
              boxImages(widget.data['image'], 0, _rawFile1),
              pw.SizedBox(height: 5),
              pw.Text('Keterangan Temuan :', style: fs2),
              pw.SizedBox(height: 5),
              pw.Text(titleCase(widget.data['remark'] ?? ''), style: fs3),
              pw.SizedBox(height: 5),
              pw.Text('Temuan dapat diselesaikan saat ini :', style: fs2),
              pw.SizedBox(height: 5),
              if (widget.data['repair'] != null)
                pw.Text(((widget.data['repair'] ?? 0) == 1 ? 'YA' : 'TIDAK'),
                    style: fs3),
              pw.SizedBox(height: 5),
              pw.Text('Foto Perbaikan :', style: fs2),
              pw.SizedBox(height: 5),
              boxImages(widget.data['repair_image'], 0, _rawFile2),
              pw.SizedBox(height: 5),
              pw.Text('Keterangan Perbaikan :', style: fs2),
              pw.SizedBox(height: 5),
              pw.Text(titleCase(widget.data['repair_remark'] ?? ''),
                  style: fs3),
              pw.SizedBox(height: 5),
            ],
            if (widget.history == History.summary &&
                widget.module == Module.observation) ...[
              pw.Text('Kegiatan yang Diamati :', style: fs2),
              pw.SizedBox(height: 5),
              pw.Text(titleCase(widget.data['subject'] ?? ''), style: fs3),
              pw.SizedBox(height: 5),
              pw.Text('Departemen Pekerjaan yang Diamati :', style: fs2),
              pw.SizedBox(height: 5),
              pw.Text(
                  titleCase(
                      widget.data['departemen_pekerja_yang_diamati'] ?? ''),
                  style: fs3),
              pw.SizedBox(height: 5),
              pw.Text('Dokumen Pendukung :', style: fs2),
              pw.SizedBox(height: 5),
              pw.Text(titleCase(widget.data['dokumen_pendukung'] ?? ''),
                  style: fs3),
              pw.SizedBox(height: 5),
              pw.Text('Risiko Kritis :', style: fs2),
              pw.SizedBox(height: 5),
              pw.Text(titleCase(widget.data['resiko_kritis'] ?? ''),
                  style: fs3),
              pw.SizedBox(height: 5),
              pw.Text('Penilaian Risiko :', style: fs2),
              pw.SizedBox(height: 5),
              pw.Text(titleCase(widget.data['activity'] ?? ''), style: fs3),
              pw.SizedBox(height: 5),
              pw.Divider(height: 30, thickness: 1),
              pw.Center(
                child: pw.Text(
                    'DETAIL ${pageTitle(widget.module).toUpperCase()}',
                    style: fs1),
              ),
              pw.SizedBox(height: 5),
              ..._rawData.map((val) {
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.start,
                  children: [
                    pw.Text('Perihal yang Diobservasi :', style: fs2),
                    pw.SizedBox(height: 5),
                    pw.Text(titleCase(val['point'] ?? ''), style: fs3),
                    pw.SizedBox(height: 5),
                    pw.Text('Hasil Observasi :', style: fs2),
                    pw.SizedBox(height: 5),
                    pw.Text(titleCase(val['type'] ?? ''), style: fs3),
                    pw.SizedBox(height: 5),
                    pw.Text('Keterangan :', style: fs2),
                    pw.SizedBox(height: 5),
                    pw.Text(titleCase(val['remark'] ?? ''), style: fs3),
                    pw.SizedBox(height: 5),
                    pw.Text('Foto :', style: fs2),
                    pw.SizedBox(height: 5),
                    boxImages(val['image'], val['id'], _rawFile1),
                    pw.SizedBox(height: 5),
                    pw.Divider(height: 30, thickness: 1),
                  ],
                );
              }),
            ],
            if (widget.history == History.summary &&
                widget.module == Module.coaching) ...[
              pw.Text('Tema Coaching :', style: fs2),
              pw.SizedBox(height: 5),
              pw.Text(titleCase(widget.data['remark'] ?? ''), style: fs3),
              pw.SizedBox(height: 5),
              pw.Text('Judul Coaching :', style: fs2),
              pw.SizedBox(height: 5),
              pw.Text(titleCase(widget.data['title'] ?? ''), style: fs3),
              pw.SizedBox(height: 5),
              pw.Text('Feedback dan Komitmen :', style: fs2),
              pw.SizedBox(height: 5),
              pw.Text(titleCase(widget.data['feedback'] ?? ''), style: fs3),
              pw.SizedBox(height: 5),
              pw.Text('Foto :', style: fs2),
              pw.SizedBox(height: 5),
              boxImages(widget.data['image'], 0, _rawFile1),
              pw.Divider(height: 30, thickness: 1),
              pw.Center(
                child: pw.Text('DAFTAR PESERTA', style: fs1),
              ),
              pw.SizedBox(height: 5),
              ..._rawData.asMap().entries.map((entry) {
                int idx = entry.key;
                var val = entry.value;
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.start,
                  children: [
                    pw.Text('${idx + 1}. ${titleCase(val['name'] ?? '')}',
                        style: fs3),
                    pw.SizedBox(height: 5),
                  ],
                );
              }),
            ],
            if (widget.history == History.summary &&
                widget.module == Module.p5m) ...[
              pw.Text('Topik P5M :', style: fs2),
              pw.SizedBox(height: 5),
              pw.Text(titleCase(widget.data['topic_name'] ?? ''), style: fs3),
              pw.SizedBox(height: 5),
              pw.Text('Judul P5M :', style: fs2),
              pw.SizedBox(height: 5),
              pw.Text(titleCase(widget.data['title'] ?? ''), style: fs3),
              pw.SizedBox(height: 5),
              pw.Text('Keterangan :', style: fs2),
              pw.SizedBox(height: 5),
              pw.Text(titleCase(widget.data['remark'] ?? ''), style: fs3),
              pw.SizedBox(height: 5),
              pw.Text('Foto :', style: fs2),
              pw.SizedBox(height: 5),
              boxImages(widget.data['image'], 0, _rawFile1),
              pw.SizedBox(height: 5),
              pw.Divider(height: 30, thickness: 1),
              pw.Center(
                child: pw.Text(
                    'DETAIL ${pageTitle(widget.module).toUpperCase()}',
                    style: fs1),
              ),
              pw.SizedBox(height: 5),
              ..._rawData.asMap().entries.map((entry) {
                int idx = entry.key;
                var val = entry.value;
                if ((val['name'] ?? '').toLowerCase().contains('umur anda')) {
                  return pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisAlignment: pw.MainAxisAlignment.start,
                    children: [
                      pw.Text('${idx + 1}. ${titleCase(val['name'] ?? '')}',
                          style: fs2),
                      pw.SizedBox(height: 5),
                      pw.Text(titleCase(val['remark'] ?? ''), style: fs3),
                      pw.SizedBox(height: 10),
                    ],
                  );
                }
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.start,
                  children: [
                    pw.Text('${idx + 1}. ${titleCase(val['name'] ?? '')}',
                        style: fs2),
                    pw.SizedBox(height: 5),
                    if (val['yesno'] != null) ...[
                      pw.Text(globals.yesNo[val['yesno'] ?? 0]!, style: fs3),
                      pw.SizedBox(height: 5),
                    ],
                    if (val['remark'] != null && val['remark'] != '') ...[
                      pw.Text(titleCase(val['remark'] ?? ''), style: fs3),
                      pw.SizedBox(height: 5),
                    ],
                    pw.SizedBox(height: 5),
                  ],
                );
              }),
            ],
            if (widget.history == History.summary &&
                widget.module == Module.p2h) ...[
              pw.Text('Jenis Kendaraan :', style: fs2),
              pw.SizedBox(height: 5),
              pw.Text(titleCase(widget.data['jenis_kendaraan'] ?? ''),
                  style: fs3),
              pw.SizedBox(height: 5),
              pw.Text('No Lambung Kendaraan :', style: fs2),
              pw.SizedBox(height: 5),
              pw.Text(titleCase(widget.data['no_lambung_kendaraan'] ?? ''),
                  style: fs3),
              pw.SizedBox(height: 5),
              pw.Text('Kilometer :', style: fs2),
              pw.SizedBox(height: 5),
              pw.Text('${(widget.data['km'] ?? 0)}', style: fs3),
              pw.SizedBox(height: 5),
              pw.Text('Merek Kendaraan :', style: fs2),
              pw.SizedBox(height: 5),
              pw.Text(titleCase(widget.data['merek_kendaraan'] ?? ''),
                  style: fs3),
              pw.SizedBox(height: 5),
              pw.Text('Memiliki SIMPER / KIMPER :', style: fs2),
              pw.SizedBox(height: 5),
              if (widget.data['simper'] != null)
                pw.Text(((widget.data['simper'] ?? 0) == 1 ? 'YA' : 'TIDAK'),
                    style: fs3),
              pw.SizedBox(height: 5),
              pw.Divider(height: 30, thickness: 1),
              pw.Center(
                child: pw.Text(
                    'DETAIL ${pageTitle(widget.module).toUpperCase()}',
                    style: fs1),
              ),
              pw.SizedBox(height: 5),
              ..._rawType.map((type) {
                int idx = 0;
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.start,
                  children: [
                    pw.Text((type['name'] ?? '').toUpperCase(), style: fs4),
                    pw.SizedBox(height: 5),
                    ..._rawData.asMap().entries.map((entry) {
                      var val = entry.value;
                      if (int.parse(val['type'] ?? 0) == type['id']) {
                        idx++;
                        return pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          mainAxisAlignment: pw.MainAxisAlignment.start,
                          children: [
                            pw.Text('$idx. ${titleCase(val['name'] ?? '')}',
                                style: fs2),
                            pw.SizedBox(height: 5),
                            if (val['yesno'] != null) ...[
                              pw.Text(globals.goodBad[val['yesno'] ?? 0]!,
                                  style: fs3),
                              pw.SizedBox(height: 5),
                            ],
                            if (val['yesno'] != null &&
                                (val['yesno'] ?? 0) == 0 &&
                                val['remark'] != null &&
                                val['remark'] != '') ...[
                              pw.Text(titleCase(val['remark'] ?? ''),
                                  style: fs3),
                              pw.SizedBox(height: 5),
                            ],
                            pw.SizedBox(height: 5),
                          ],
                        );
                      }
                      return pw.SizedBox(height: 0);
                    }),
                    pw.SizedBox(height: 10),
                  ],
                );
              }),
            ],
            if (widget.history == History.summary &&
                widget.module == Module.safety) ...[
              pw.Text('Judul Safety Talk :', style: fs2),
              pw.SizedBox(height: 5),
              pw.Text(titleCase(widget.data['title'] ?? ''), style: fs3),
              pw.SizedBox(height: 5),
              pw.Text('Keterangan :', style: fs2),
              pw.SizedBox(height: 5),
              pw.Text(titleCase(widget.data['remark'] ?? ''), style: fs3),
              pw.SizedBox(height: 5),
              pw.Text('Foto Selfie :', style: fs2),
              pw.SizedBox(height: 5),
              if (widget.data['self_image'] != null &&
                  widget.data['self_image'] != '')
                pw.Image(
                  pw.MemoryImage(
                      File(widget.data['self_image']).readAsBytesSync()),
                  height: 150,
                ),
              pw.SizedBox(height: 5),
              pw.Text('Foto Acara :', style: fs2),
              pw.SizedBox(height: 5),
              if (widget.data['event_image'] != null &&
                  widget.data['event_image'] != '')
                pw.Image(
                  pw.MemoryImage(
                      File(widget.data['event_image']).readAsBytesSync()),
                  height: 150,
                ),
            ],
            if (widget.history == History.summary &&
                    widget.module == Module.inspection ||
                widget.history == History.summary &&
                    widget.module == Module.inspectionDaily ||
                widget.history == History.summary &&
                    widget.module == Module.inspectionWeekly) ...[
              pw.Text('Jenis Inspeksi :', style: fs2),
              pw.SizedBox(height: 5),
              pw.Text(titleCase(widget.data['jenis_inspeksi'] ?? ''),
                  style: fs3),
              pw.SizedBox(height: 5),
              if (widget.module == Module.inspectionDaily) ...[
                pw.Text('Shift :', style: fs2),
                pw.SizedBox(height: 5),
                pw.Text(titleCase(widget.data['shift_name'] ?? ''), style: fs3),
                pw.SizedBox(height: 5),
              ],
              pw.Text('PJA :', style: fs2),
              pw.SizedBox(height: 5),
              pw.Text(titleCase(widget.data['pja_name'] ?? ''), style: fs3),
              pw.SizedBox(height: 5),
              if (widget.module == Module.inspectionWeekly) ...[
                pw.Text('Inspektor 1 :', style: fs2),
                pw.SizedBox(height: 5),
                pw.Text(titleCase(widget.data['inspektor1_name'] ?? ''),
                    style: fs3),
                pw.SizedBox(height: 5),
                pw.Text('Inspektor 2 :', style: fs2),
                pw.SizedBox(height: 5),
                pw.Text(titleCase(widget.data['inspektor2_name'] ?? ''),
                    style: fs3),
                pw.SizedBox(height: 5),
                pw.Text('Inspektor 3 :', style: fs2),
                pw.SizedBox(height: 5),
                pw.Text(titleCase(widget.data['inspektor3_name'] ?? ''),
                    style: fs3),
                pw.SizedBox(height: 5),
                pw.Text('Inspektor 4 :', style: fs2),
                pw.SizedBox(height: 5),
                pw.Text(titleCase(widget.data['inspektor4_name'] ?? ''),
                    style: fs3),
                pw.SizedBox(height: 5),
                pw.Text('Inspektor 5 :', style: fs2),
                pw.SizedBox(height: 5),
                pw.Text(titleCase(widget.data['inspektor5_name'] ?? ''),
                    style: fs3),
                pw.SizedBox(height: 5),
              ],
              pw.Divider(height: 30, thickness: 1),
              pw.Center(
                child: pw.Text(
                    'DETAIL ${pageTitle(widget.module).toUpperCase()}',
                    style: fs1),
              ),
              pw.SizedBox(height: 5),
              ..._rawData.asMap().entries.map((entry) {
                int idx = entry.key;
                var val = entry.value;
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.start,
                  children: [
                    pw.Text('${idx + 1}. ${titleCase(val['name'] ?? '')}',
                        style: fs2),
                    pw.SizedBox(height: 5),
                    if (val['yesno'] != null) ...[
                      pw.Text(globals.yesNo[val['yesno'] ?? 0]!, style: fs3),
                      pw.SizedBox(height: 5),
                    ],
                    if (val['image'] != null &&
                        val['image'] != '' &&
                        val['remark'] != null &&
                        val['remark'] != '') ...[
                      pw.Text(titleCase(val['remark'] ?? ''), style: fs3),
                      pw.SizedBox(height: 5),
                      pw.Text('Foto Temuan :', style: fs2),
                      pw.SizedBox(height: 5),
                      boxImages(val['image'], val['id'], _rawFile1),
                      pw.SizedBox(height: 5),
                      pw.Text('Keterangan Temuan :', style: fs2),
                      pw.SizedBox(height: 5),
                      pw.Text(titleCase(val['remark'] ?? ''), style: fs3),
                      pw.SizedBox(height: 5),
                      if (widget.module != Module.inspectionDaily) ...[
                        pw.Text('Temuan dapat diselesaikan saat ini :',
                            style: fs2),
                        pw.SizedBox(height: 5),
                        if (val['repair'] != null)
                          pw.Text(((val['repair'] ?? 0) == 1 ? 'YA' : 'TIDAK'),
                              style: fs3),
                        pw.SizedBox(height: 5),
                        pw.Text('Foto Perbaikan :', style: fs2),
                        pw.SizedBox(height: 5),
                        boxImages(val['repair_image'], val['id'], _rawFile2),
                        pw.SizedBox(height: 5),
                        pw.Text('Keterangan Perbaikan :', style: fs2),
                        pw.SizedBox(height: 5),
                        pw.Text(titleCase(val['repair_remark'] ?? ''),
                            style: fs3),
                        pw.SizedBox(height: 5),
                      ],
                    ],
                  ],
                );
              }),
            ],
            if (widget.history == History.summary &&
                widget.module == Module.simama) ...[
              pw.Text('Inspektor 1 :', style: fs2),
              pw.SizedBox(height: 5),
              pw.Text(titleCase(widget.data['inspektor1_name'] ?? ''),
                  style: fs3),
              pw.SizedBox(height: 5),
              pw.Text('Inspektor 2 :', style: fs2),
              pw.SizedBox(height: 5),
              pw.Text(titleCase(widget.data['inspektor2_name'] ?? ''),
                  style: fs3),
              pw.SizedBox(height: 5),
              pw.Text('Inspektor 3 :', style: fs2),
              pw.SizedBox(height: 5),
              pw.Text(titleCase(widget.data['inspektor3_name'] ?? ''),
                  style: fs3),
              pw.SizedBox(height: 5),
              pw.Text('Inspektor 4 :', style: fs2),
              pw.SizedBox(height: 5),
              pw.Text(titleCase(widget.data['inspektor4_name'] ?? ''),
                  style: fs3),
              pw.SizedBox(height: 5),
              pw.Text('Inspektor 5 :', style: fs2),
              pw.SizedBox(height: 5),
              pw.Text(titleCase(widget.data['inspektor5_name'] ?? ''),
                  style: fs3),
              pw.SizedBox(height: 5),
              pw.Text('Foto Kegiatan :', style: fs2),
              pw.SizedBox(height: 5),
              if (widget.data['image'] != null && widget.data['image'] != '')
                pw.Image(
                  pw.MemoryImage(File(widget.data['image']).readAsBytesSync()),
                  height: 150,
                ),
              pw.Divider(height: 30, thickness: 1),
              pw.Center(
                child: pw.Text(
                    'DETAIL ${pageTitle(widget.module).toUpperCase()}',
                    style: fs1),
              ),
              pw.SizedBox(height: 5),
              ..._rawType.map((type) {
                int idx = 0;
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.start,
                  children: [
                    pw.Text((type['name'] ?? '').toUpperCase(), style: fs4),
                    pw.SizedBox(height: 5),
                    ..._rawData.asMap().entries.map((entry) {
                      var val = entry.value;
                      if ((val['location_id'] ?? 0) == type['id']) {
                        idx++;
                        return pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          mainAxisAlignment: pw.MainAxisAlignment.start,
                          children: [
                            pw.Text('$idx. ${titleCase(val['name'] ?? '')}',
                                style: fs2),
                            pw.SizedBox(height: 5),
                            if (val['yesno'] != null) ...[
                              pw.Text(globals.yesNo[val['yesno'] ?? 0]!,
                                  style: fs3),
                              pw.SizedBox(height: 5),
                            ],
                            if (val['image'] != null &&
                                val['image'] != '' &&
                                val['remark'] != null &&
                                val['remark'] != '') ...[
                              pw.Text(titleCase(val['remark'] ?? ''),
                                  style: fs3),
                              pw.SizedBox(height: 5),
                              pw.Text('Foto Temuan :', style: fs2),
                              pw.SizedBox(height: 5),
                              boxImages(val['image'], val['id'], _rawFile1),
                              pw.SizedBox(height: 5),
                              pw.Text('Keterangan Temuan :', style: fs2),
                              pw.SizedBox(height: 5),
                              pw.Text(titleCase(val['remark'] ?? ''),
                                  style: fs3),
                              pw.SizedBox(height: 5),
                            ],
                          ],
                        );
                      }
                      return pw.SizedBox(height: 0);
                    }),
                    pw.SizedBox(height: 10),
                  ],
                );
              }),
            ],
            if (widget.history == History.action ||
                widget.history == History.monitoring) ...[
              pw.Center(child: pw.Text('PERBAIKAN', style: fs1)),
              pw.SizedBox(height: 5),
              pw.Text('Nama PJA :', style: fs2),
              pw.SizedBox(height: 5),
              pw.Text(titleCase(widget.data['pja_name'] ?? ''), style: fs3),
              pw.SizedBox(height: 5),
              pw.Text('Nama PIC :', style: fs2),
              pw.SizedBox(height: 5),
              pw.Text(titleCase(widget.data['pic_name'] ?? ''), style: fs3),
              pw.SizedBox(height: 5),
              pw.Text('Rencana Perbaikan :', style: fs2),
              pw.SizedBox(height: 5),
              pw.Text(titleCase(widget.data['plan'] ?? ''), style: fs3),
              pw.SizedBox(height: 5),
              pw.Text('Due Date Perbaikan :', style: fs2),
              pw.SizedBox(height: 5),
              pw.Text(titleCase(widget.data['plan_date'] ?? ''), style: fs3),
              pw.SizedBox(height: 5),
              pw.Text('Over Due :', style: fs2),
              pw.SizedBox(height: 5),
              pw.Text('${(widget.data['overdue'] ?? '')}', style: fs3),
              pw.SizedBox(height: 5),
              pw.Text('Alasan Over Due :', style: fs2),
              pw.SizedBox(height: 5),
              pw.Text(titleCase(widget.data['reason'] ?? ''), style: fs3),
              pw.SizedBox(height: 5),
              pw.Text('Tindakan Perbaikan :', style: fs2),
              pw.SizedBox(height: 5),
              pw.Text(titleCase(widget.data['action'] ?? ''), style: fs3),
              pw.SizedBox(height: 5),
              pw.Text('Tanggal Perbaikan :', style: fs2),
              pw.SizedBox(height: 5),
              pw.Text(titleCase(widget.data['action_date'] ?? ''), style: fs3),
              pw.SizedBox(height: 5),
              pw.Text('Foto Perbaikan :', style: fs2),
              pw.SizedBox(height: 5),
              ..._imgPerbaikan.values.map((img) {
                return img;
              }),
              pw.SizedBox(height: 5),
              pw.Divider(height: 30, thickness: 1),
              pw.Center(child: pw.Text('TEMUAN', style: fs1)),
              pw.SizedBox(height: 5),
              pw.Text('Keterangan :', style: fs2),
              pw.SizedBox(height: 5),
              pw.Text(titleCase(widget.data['title'] ?? ''), style: fs3),
              pw.SizedBox(height: 5),
              pw.Text(titleCase(widget.data['remark'] ?? ''), style: fs3),
              pw.SizedBox(height: 5),
              pw.Text('Foto Temuan :', style: fs2),
              pw.SizedBox(height: 5),
              ..._imgTemuan.values.map((img) {
                return img;
              }),
              pw.SizedBox(height: 5),
            ],
          ];
        },
      ),
    );

    return pdf.save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TopBar(title: 'Detail ${pageTitle(widget.module)}'),
      body: PdfPreview(
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        padding: const EdgeInsets.all(0),
        initialPageFormat: PdfPageFormat.legal,
        scrollViewDecoration: const BoxDecoration(
          color: Colors.white,
        ),
        pdfPreviewPageDecoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey),
          boxShadow: const [BoxShadow(color: Colors.transparent)],
        ),
        pdfFileName:
            '${pageTitle(widget.module).replaceAll(' ', '-')}-${widget.data['code']}.pdf',
        build: (format) => _generatePdf(format),
      ),
      bottomNavigationBar: (widget.history == History.action && _isPJA != null)
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: buttonApp(
                label: (_isPJA == true) ? 'Tentukan PIC' : 'Perbaikan',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ActionPlanPage(
                        widget.module,
                        widget.data,
                        _isPJA!,
                      ),
                    ),
                  );
                },
              ),
            )
          : null,
    );
  }

  pw.Widget boxImages(String? image, int id, List<dynamic> files) {
    if (image != null && image != '') {
      List<dynamic> others = [
        {'id': id, 'name': image}
      ];
      others.addAll(files
          .where((e) => e['detail_id'] != null && e['detail_id'] as int == id)
          .toList());

      List<List> ranges = [];
      if (others.isNotEmpty) {
        var to = others.length > 3 ? 3 : others.length;
        ranges.add([0, to]);
      }
      if (others.length > 3) {
        var to = others.length > 6 ? 6 : others.length;
        ranges.add([3, to]);
      }
      if (others.length > 6) {
        var to = others.length > 9 ? 9 : others.length;
        ranges.add([6, to]);
      }
      if (others.length > 9) {
        var to = others.length > 12 ? 12 : others.length;
        ranges.add([9, to]);
      }
      if (others.length > 12) {
        var to = others.length > 15 ? 15 : others.length;
        ranges.add([12, to]);
      }

      return pw.SizedBox(
        height: (ranges.length * 160),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.start,
          children: [
            for (var range in ranges)
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.start,
                children: [
                  for (var other in others.getRange(range[0], range[1]))
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(right: 10, bottom: 10),
                      child: pw.Image(
                        pw.MemoryImage(File(other['name']).readAsBytesSync()),
                        height: 150,
                      ),
                    ),
                ],
              )
          ],
        ),
      );
    }

    return pw.SizedBox(height: 0);
  }
}

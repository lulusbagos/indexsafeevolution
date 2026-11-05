import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/api.dart';
import '../../services/database.dart';
import '../../services/offline_sync_service.dart';
import '../../services/preference.dart';
import '../../services/sync.dart';
import '../../utils/enums.dart';
import '../../utils/globals.dart' as globals;
import '../../utils/helpers.dart';
import '../../widgets/sap_module_ui.dart';
import '../../widgets/snackbar_msg.dart';
import '../../widgets/top_bar.dart';
import '../../services/p2h_pdf_service.dart';
import '../../services/p5m_share_service.dart';
import '../../services/hazard_pdf_service.dart';
import '../hazard/hazard_create_page.dart';
import '../../models/hazard_hub_model.dart';
import '../simama/simama_form_page.dart';
import '../p5m/p5m_form_page.dart';
import 'history_detail_page.dart';
import '../observation/observation_form_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage(this.module, this.history, {this.lastId, super.key});

  final Module module;
  final History history;
  final int? lastId;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _scrollCtrl = ScrollController();
  final _db = DatabaseService();
  final _api = ApiService();
  final _profile = PreferenceService.getProfile();
  List<dynamic> _rawData = [];
  String _table = '';
  String _searchQuery = '';

  List<dynamic> get _displayData {
    if (_searchQuery.trim().isEmpty) return _rawData;
    final q = _searchQuery.toLowerCase().trim();
    return _rawData.where((item) {
      if (item is! Map) return false;
      final title = '${item['title'] ?? ''}'.toLowerCase();
      final remark = '${item['remark'] ?? item['detil_temuan'] ?? ''}'.toLowerCase();
      final location = '${item['location_name'] ?? item['location_detail'] ?? item['lokasi'] ?? ''}'.toLowerCase();
      final area = '${item['area_name'] ?? item['area'] ?? ''}'.toLowerCase();
      final pja = '${item['pja_name'] ?? item['pja'] ?? ''}'.toLowerCase();
      final pic = '${item['pic_name'] ?? item['pic'] ?? ''}'.toLowerCase();
      final code = '${item['code'] ?? ''}'.toLowerCase();
      final company = '${item['company'] ?? item['perusahaan'] ?? ''}'.toLowerCase();
      return title.contains(q) ||
          remark.contains(q) ||
          location.contains(q) ||
          area.contains(q) ||
          pja.contains(q) ||
          pic.contains(q) ||
          code.contains(q) ||
          company.contains(q);
    }).toList();
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getData();
      _fetchAndRefresh();
      if (widget.lastId == null) {
        Future.delayed(const Duration(seconds: 2), () => _getData());
        Future.delayed(const Duration(seconds: 4), () => _getData());
        Future.delayed(const Duration(seconds: 6), () => _getData());
        Future.delayed(const Duration(seconds: 8), () => _getData());
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _fetchAndRefresh() async {
    final isOnline = OfflineSyncService.instance.state.value.isOnline;
    if (isOnline) {
      final userNik = _profile?.noNik?.trim() ?? '';
      final profileId = _profile?.id ?? 0;
      final myName = (_profile?.namaLengkap ?? '').trim().toUpperCase();

      if (widget.history == History.summary && widget.module == Module.hazard) {
        try {
          final tranRes = await _api.getTran('hazard?nik=$userNik&limit=2500');
          await tranRes.fold((_) async {}, (res) async {
            if (res['data'] is List) {
              for (var raw in (res['data'] as List)) {
                if (raw is Map) {
                  final item = Map<String, dynamic>.from(raw);
                  final id = item['id'];
                  if (id is int) {
                    final remark = (item['remark'] ?? item['title'] ?? '').toString().toLowerCase();
                    if (remark.contains('ceceran oli & solar tebal') || id == 8207491 || id == 8207463 || id == 8205037) {
                      continue;
                    }
                    final itemNik = (item['nik'] ?? '').toString().trim();
                    final itemNama = (item['nama'] ?? '').toString().trim().toUpperCase();
                    final isReporter = (userNik.isNotEmpty && itemNik == userNik) ||
                                       (myName.isNotEmpty && itemNama.isNotEmpty && itemNama == myName);
                    final isPja = (userNik.isNotEmpty && (item['nik_pja'] ?? '').toString().trim() == userNik);
                    if (userNik.isNotEmpty && !isReporter && !isPja) continue;

                    final row = <String, dynamic>{
                      'id': id,
                      'code': item['code'] ?? 'HZ-$id',
                      'title': item['title'] ?? item['remark'] ?? 'Laporan Bahaya',
                      'location_detail': item['location_detail'] ?? item['lokasi'] ?? '',
                      'date': item['date'] ?? '',
                      'time': item['time'] ?? '',
                      'remark': item['remark'] ?? '',
                      'image': item['image'] ?? item['foto_temuan'],
                      'status': item['status'] is int ? item['status'] : 0,
                      'repair': item['repair'] is int ? item['repair'] : 0,
                      'repair_remark': item['repair_remark'] ?? item['perbaikan'],
                      'repair_image': item['repair_image'] ?? item['foto_perbaikan'],
                      'pja_id': isPja ? profileId : (item['pja_id'] ?? 0),
                      'employee_id': isReporter ? profileId : (item['employee_id'] ?? profileId),
                      'nik': item['nik'] ?? userNik,
                      'nama': item['nama'] ?? _profile?.namaLengkap ?? '',
                      'nik_pja': item['nik_pja'] ?? '',
                      'pja': item['pja'] ?? '',
                      'area': item['area'] ?? '',
                      'lokasi': item['lokasi'] ?? '',
                      'area_name': item['area_name'] ?? item['area'] ?? '-',
                      'location_name': item['location_name'] ?? item['lokasi'] ?? '-',
                      'kategori_bahaya': item['kategori_bahaya'] ?? '',
                      'jenis_bahaya': item['jenis_bahaya'] ?? '',
                      'tingkat_resiko': item['tingkat_resiko'] ?? '',
                      'sync_id': id,
                      'created_at': item['created_at'] ?? DateTime.now().toString(),
                    };
                    final existing = await _db.get('hazard_trans', id);
                    if (existing == null) {
                      await _db.insert('hazard_trans', row);
                    } else {
                      await _db.update('hazard_trans', row, id);
                    }
                  }
                }
              }
            }
          });
        } catch (_) {}
      } else if (widget.history == History.summary && widget.module == Module.p2h) {
        try {
          final tranRes = await _api.getTran('p2h?nik=$userNik&limit=2500');
          await tranRes.fold((_) async {}, (res) async {
            if (res['data'] is List) {
              for (var raw in (res['data'] as List)) {
                if (raw is Map) {
                  final item = Map<String, dynamic>.from(raw);
                  final id = item['id'];
                  if (id is int) {
                    final itemNik = (item['nik'] ?? '').toString().trim();
                    if (userNik.isNotEmpty && itemNik.isNotEmpty && itemNik != userNik) continue;

                    final row = <String, dynamic>{
                      'id': id,
                      'code': item['code'] ?? 'P2H-$id',
                      'title': 'P2H Unit ${item['noLambung'] ?? item['no_lambung'] ?? ''}',
                      'date': item['tanggal'] ?? item['date'] ?? '',
                      'time': item['waktu'] ?? item['time'] ?? '',
                      'no_lambung': item['noLambung'] ?? item['no_lambung'] ?? '',
                      'jenis_kendaraan': item['jenisKendaraan'] ?? item['jenis_kendaraan'] ?? '',
                      'merek': item['merek'] ?? '',
                      'km': item['kilometer'] ?? item['km'] ?? 0,
                      'simper_kimper': item['simperKimper'] ?? item['simper_kimper'] ?? 'YA',
                      'simper': (item['simperKimper'] == 'YA' || item['simper_kimper'] == 'YA') ? 1 : 0,
                      'image': item['fotoSpeedometer'] ?? item['image'],
                      'foto_speedometer': item['fotoSpeedometer'] ?? item['foto_speedometer'] ?? item['image'],
                      'gol_a_json': item['golA'] ?? item['gol_a_json'],
                      'gol_b_json': item['golB'] ?? item['gol_b_json'],
                      'gol_c_json': item['golC'] ?? item['gol_c_json'],
                      'sync_id': id,
                      'employee_id': profileId,
                      'nik': item['nik'] ?? userNik,
                      'nama': item['nama'] ?? _profile?.namaLengkap ?? '',
                      'created_at': item['createdAt'] ?? item['created_at'] ?? DateTime.now().toString(),
                    };
                    final existing = await _db.rawQuery('SELECT id FROM p2h_trans WHERE sync_id = $id OR id = $id LIMIT 1');
                    if (existing.isEmpty) {
                      await _db.insert('p2h_trans', row);
                    } else {
                      final localId = existing.first['id'] as int;
                      await _db.update('p2h_trans', row, localId);
                    }
                  }
                }
              }
            }
          });
        } catch (_) {}
      } else if (widget.history == History.summary &&
          widget.module == Module.observation) {
        try {
          final tranRes = await _api.getTran('observation?nik=$userNik&limit=2500');
          await tranRes.fold((_) async {}, (res) async {
            if (res['data'] is List) {
              for (final raw in (res['data'] as List)) {
                if (raw is! Map) continue;
                final item = Map<String, dynamic>.from(raw);
                final serverId = int.tryParse(item['id'].toString());
                if (serverId == null) continue;

                final itemNik = (item['nik'] ?? '').toString().trim();
                final itemNama = (item['nama'] ?? '').toString().trim().toUpperCase();

                final isMine = (userNik.isNotEmpty && itemNik == userNik) ||
                               (myName.isNotEmpty && itemNama.isNotEmpty && itemNama == myName);
                if (userNik.isNotEmpty && !isMine) continue;

                final row = <String, dynamic>{
                  'id': serverId,
                  'code': 'OBS-$serverId',
                  'title': item['kegiatanYangDiamati'] ?? item['title'] ?? item['activity'] ?? 'Observasi Lapangan',
                  'date': item['date']?.toString().split('T').first ?? item['tanggal']?.toString().split('T').first ?? '',
                  'time': item['time'] ?? item['waktu'] ?? '',
                  'area': item['area'] ?? '',
                  'lokasi': item['lokasi'] ?? '',
                  'location_detail': item['detilLokasi'] ?? item['location_detail'] ?? item['detil_lokasi'] ?? '',
                  'area_name': item['area'] ?? '-',
                  'location_name': item['lokasi'] ?? '-',
                  'company_id': item['perusahaanId'] ?? item['company_id'],
                  'company_name': item['perusahaanYangDiamati'] ?? item['company_name'] ?? '',
                  'dept_name': item['departemenYangDiamati'] ?? item['dept_name'] ?? '',
                  'doc_name': item['dokumenPendukung'] ?? item['doc_name'] ?? '',
                  'risk_name': item['resikoKritis'] ?? item['risk_name'] ?? '',
                  'risk_level': item['tingkatResiko'] ?? item['risk_level'] ?? '',
                  'remark': item['keterangan'] ?? item['remark'] ?? '',
                  'perihal': item['perihalYangDiamati'] ?? item['perihal'] ?? '',
                  'hasil': item['hasilObservasi'] ?? item['hasil'] ?? '',
                  'photo_url': item['fotoUrl'] ?? item['photo_url'] ?? item['image'] ?? '',
                  'image': item['fotoUrl'] ?? item['photo_url'] ?? item['image'] ?? '',
                  'employee_id': profileId,
                  'sync_id': serverId,
                  'nik': itemNik.isNotEmpty ? itemNik : userNik,
                  'nama': itemNama.isNotEmpty ? itemNama : (_profile?.namaLengkap ?? ''),
                  'created_at': item['createdAt'] ?? item['created_at'] ?? DateTime.now().toString(),
                };
                final existing = await _db.rawQuery(
                    'SELECT id FROM observation_trans WHERE sync_id = ? OR id = ? LIMIT 1',
                    [serverId, serverId]);
                int localId;
                if (existing.isEmpty) {
                  await _db.insert('observation_trans', row);
                  localId = serverId;
                } else {
                  localId = existing.first['id'] as int;
                  await _db.update('observation_trans', row, localId);
                }
                final found = await _db.rawQuery(
                    'select id from observation_details where tran_id=? and (ref_id=? or sync_id=?)',
                    [localId, serverId, serverId]);
                if (found.isEmpty) {
                  await _db.insert('observation_details', {
                    'name': item['perihalYangDiamati'] ?? item['perihal'] ?? '',
                    'point': item['perihalYangDiamati'] ?? item['perihal'] ?? '',
                    'type': item['hasilObservasi'] ?? item['hasil'] ?? '',
                    'remark': item['keterangan'] ?? item['remark'] ?? '',
                    'image': item['fotoUrl'] ?? item['image'] ?? '',
                    'tran_id': localId,
                    'ref_id': serverId,
                    'sync_id': serverId,
                  });
                }
              }
            }
          });
        } catch (_) {}
      } else if (widget.history == History.summary && widget.module == Module.p5m) {
        try {
          final tranRes = await _api.getTran('p5m?nik=$userNik&limit=2500');
          await tranRes.fold((_) async {}, (res) async {
            if (res['data'] is List) {
              for (var raw in (res['data'] as List)) {
                if (raw is Map) {
                  final item = Map<String, dynamic>.from(raw);
                  final id = item['id'];
                  if (id is int) {
                    final itemNik = (item['nik'] ?? '').toString().trim();
                    if (userNik.isNotEmpty && itemNik.isNotEmpty && itemNik != userNik) continue;

                    final row = <String, dynamic>{
                      'id': id,
                      'code': item['code'] ?? 'P5M-$id',
                      'title': item['title'] ?? item['judul'] ?? 'P5M & Fit to Work',
                      'date': item['date'] ?? item['tanggal'] ?? '',
                      'time': item['time'] ?? item['waktu'] ?? '',
                      'area': item['area'] ?? '',
                      'lokasi': item['lokasi'] ?? '',
                      'detil_lokasi': item['detil_lokasi'] ?? item['location_detail'] ?? '',
                      'area_name': item['area'] ?? '-',
                      'location_name': item['lokasi'] ?? '-',
                      'topik': item['topik'] ?? '',
                      'judul': item['judul'] ?? item['title'] ?? '',
                      'catatan': item['catatan'] ?? item['remark'] ?? '',
                      'remark': item['catatan'] ?? item['remark'] ?? '',
                      'foto_kegiatan': item['foto_kegiatan'] ?? item['image'],
                      'image': item['foto_kegiatan'] ?? item['image'],
                      'fit_status': item['fit_status'] ?? 'FIT TO WORK',
                      'questions_json': (item['checklist'] != null) ? jsonEncode((item['checklist'] as List).map((e) => e['question']).toList()) : null,
                      'answers_json': (item['checklist'] != null) ? jsonEncode((item['checklist'] as List).map((e) => e['answer']).toList()) : null,
                      'sync_id': id,
                      'employee_id': profileId,
                      'nik': item['nik'] ?? userNik,
                      'nama': item['nama'] ?? _profile?.namaLengkap ?? '',
                      'created_at': item['created_at'] ?? DateTime.now().toString(),
                    };
                    final existing = await _db.rawQuery('SELECT id FROM p5m_trans WHERE sync_id = $id OR id = $id LIMIT 1');
                    if (existing.isEmpty) {
                      await _db.insert('p5m_trans', row);
                    } else {
                      final localId = existing.first['id'] as int;
                      await _db.update('p5m_trans', row, localId);
                    }
                  }
                }
              }
            }
          });
        } catch (_) {}
      } else if (widget.history == History.summary && widget.module == Module.coaching) {
        try {
          final tranRes = await _api.getTran('coaching?nik=$userNik&limit=2500');
          await tranRes.fold((_) async {}, (res) async {
            if (res['data'] is List) {
              for (var raw in (res['data'] as List)) {
                if (raw is Map) {
                  final item = Map<String, dynamic>.from(raw);
                  final id = item['id'];
                  if (id is int) {
                    final itemNik = (item['nik'] ?? item['coach_nik'] ?? '').toString().trim();
                    if (userNik.isNotEmpty && itemNik.isNotEmpty && itemNik != userNik) continue;

                    final row = <String, dynamic>{
                      'id': id,
                      'sync_id': id,
                      'code': item['code'] ?? 'COACH-$id',
                      'title': item['title'] ?? item['tema'] ?? 'Safety Coaching',
                      'tema': item['tema'] ?? item['title'] ?? 'Safety Coaching',
                      'purpose': item['purpose'] ?? item['tema'] ?? '',
                      'feedback': item['feedback'] ?? item['remark'] ?? '',
                      'komitmen': item['komitmen'] ?? '',
                      'date': item['date'] ?? item['tanggal'] ?? '',
                      'time': item['time'] ?? item['waktu'] ?? '',
                      'area': item['area'] ?? '',
                      'lokasi': item['lokasi'] ?? '',
                      'location_detail': item['location_detail'] ?? item['detil_lokasi'] ?? '',
                      'area_name': item['area_name'] ?? item['area'] ?? '-',
                      'location_name': item['location_name'] ?? item['lokasi'] ?? '-',
                      'nik': item['nik'] ?? userNik,
                      'nama': item['nama'] ?? _profile?.namaLengkap ?? '',
                      'foto': item['foto'] ?? item['image'] ?? '',
                      'image': item['foto'] ?? item['image'] ?? '',
                      'employee_id': profileId,
                      'created_at': item['created_at'] ?? DateTime.now().toString(),
                    };
                    final existing = await _db.rawQuery('SELECT id FROM coaching_trans WHERE sync_id = $id OR id = $id LIMIT 1');
                    if (existing.isEmpty) {
                      await _db.insert('coaching_trans', row);
                    } else {
                      final localId = existing.first['id'] as int;
                      await _db.update('coaching_trans', row, localId);
                    }
                  }
                }
              }
            }
          });
        } catch (_) {}
      } else if (widget.history == History.summary && (widget.module == Module.simama || widget.module == Module.inspection || widget.module == Module.inspectionDaily || widget.module == Module.inspectionWeekly)) {
        try {
          final ep = widget.module == Module.simama ? 'simama' : 'inspection';
          final tranRes = await _api.getTran('$ep?nik=$userNik&limit=2500');
          await tranRes.fold((_) async {}, (res) async {
            if (res['data'] is List) {
              for (var raw in (res['data'] as List)) {
                if (raw is Map) {
                  final item = Map<String, dynamic>.from(raw);
                  final id = item['id'];
                  if (id is int) {
                    final itemNik = (item['nik'] ?? item['Nik'] ?? '').toString().trim();
                    final itemPjaNik = (item['nik_pja'] ?? item['nikPja'] ?? item['NikPja'] ?? '').toString().trim();
                    if (userNik.isNotEmpty && itemNik.isNotEmpty && itemNik != userNik && itemPjaNik != userNik) continue;

                    final row = <String, dynamic>{
                      'id': id,
                      'sync_id': id,
                      'code': item['code'] ?? 'INSP-$id',
                      'category': widget.module.name,
                      'title': item['jenisInspeksi'] ?? item['jenis_inspeksi'] ?? item['catatan'] ?? item['remark'] ?? 'Inspeksi K3',
                      'date': item['tanggal']?.toString().split('T').first ?? item['date']?.toString().split('T').first ?? '',
                      'time': item['waktu']?.toString() ?? item['time']?.toString() ?? '',
                      'nama': item['nama'] ?? _profile?.namaLengkap ?? '',
                      'nik': itemNik.isNotEmpty ? itemNik : userNik,
                      'area': item['area'] ?? '',
                      'lokasi': item['lokasi'] ?? '',
                      'location_detail': item['detilLokasi'] ?? item['detil_lokasi'] ?? item['location_detail'] ?? '',
                      'area_name': item['area_name'] ?? item['area'] ?? '-',
                      'location_name': item['location_name'] ?? item['lokasi'] ?? '-',
                      'jenis_inspeksi': item['jenisInspeksi'] ?? item['jenis_inspeksi'] ?? 'Rutin',
                      'pja': item['pja'] ?? '',
                      'nik_pja': itemPjaNik,
                      'departemen_pja': item['departemenPja'] ?? item['departemen_pja'] ?? '',
                      'employee_id': (itemNik == userNik) ? profileId : 0,
                      'pja_id': (itemPjaNik == userNik) ? profileId : 0,
                      'catatan': item['catatan'] ?? item['remark'] ?? '',
                      'image': (item['image'] ?? item['lampiran_json'] ?? item['lampiranJson'])?.toString(),
                    };
                    final existing = await _db.rawQuery('SELECT id FROM inspection_trans WHERE sync_id = $id OR id = $id LIMIT 1');
                    if (existing.isEmpty) {
                      await _db.insert('inspection_trans', row);
                    } else {
                      final localId = existing.first['id'] as int;
                      await _db.update('inspection_trans', row, localId);
                    }
                  }
                }
              }
            }
          });
        } catch (_) {}
      } else if (widget.history == History.summary && widget.module == Module.safety) {
        try {
          final tranRes = await _api.getTran('safety?nik=$userNik&limit=2500');
          await tranRes.fold((_) async {}, (res) async {
            if (res['data'] is List) {
              for (var raw in (res['data'] as List)) {
                if (raw is Map) {
                  final item = Map<String, dynamic>.from(raw);
                  final id = item['id'];
                  if (id is int) {
                    final itemNik = (item['nik'] ?? '').toString().trim();
                    if (userNik.isNotEmpty && itemNik.isNotEmpty && itemNik != userNik) continue;

                    final row = <String, dynamic>{
                      'id': id,
                      'sync_id': id,
                      'code': item['code'] ?? 'ST-$id',
                      'judul': item['judul'] ?? item['title'] ?? 'Safety Talk',
                      'title': item['judul'] ?? item['title'] ?? 'Safety Talk',
                      'date': item['tanggal']?.toString().split('T').first ?? item['date']?.toString().split('T').first ?? '',
                      'tanggal': item['tanggal']?.toString().split('T').first ?? item['date']?.toString().split('T').first ?? '',
                      'time': item['waktu']?.toString() ?? item['time']?.toString() ?? '',
                      'waktu': item['waktu']?.toString() ?? item['time']?.toString() ?? '',
                      'area': item['area'] ?? '',
                      'lokasi': item['lokasi'] ?? '',
                      'detil_lokasi': item['detilLokasi'] ?? item['detil_lokasi'] ?? '',
                      'area_name': item['area'] ?? '-',
                      'location_name': item['lokasi'] ?? '-',
                      'keterangan': item['keterangan'] ?? item['remark'] ?? '',
                      'remark': item['keterangan'] ?? item['remark'] ?? '',
                      'foto_diri': item['fotoDiri'] ?? item['foto_diri'],
                      'foto_kegiatan': item['fotoKegiatan'] ?? item['foto_kegiatan'],
                      'nik': item['nik'] ?? userNik,
                      'nama': item['nama'] ?? _profile?.namaLengkap ?? '',
                      'status': 1,
                      'employee_id': profileId,
                      'created_at': item['createdAt'] ?? item['created_at'] ?? DateTime.now().toString(),
                    };
                    final existing = await _db.rawQuery('SELECT id FROM safety_trans WHERE sync_id = $id OR id = $id LIMIT 1');
                    if (existing.isEmpty) {
                      await _db.insert('safety_trans', row);
                    } else {
                      final localId = existing.first['id'] as int;
                      await _db.update('safety_trans', row, localId);
                    }
                  }
                }
              }
            }
          });
        } catch (_) {}
      } else if (widget.history == History.action || widget.history == History.monitoring) {
        try {
          final actionRes = await _api.getAction(widget.module.name);
          await actionRes.fold((_) async {}, (response) async {
            final list = response['data'];
            if (list is List) {
              for (var raw in list) {
                if (raw is Map) {
                  final item = Map<String, dynamic>.from(raw);
                  final id = item['id'];
                  if (id is int) {
                    final row = <String, dynamic>{
                      'id': id,
                      'code': item['code'] ?? 'AP-$id',
                      'title': item['title'] ?? item['detilTemuan'] ?? item['kategoriTemuan'] ?? 'Action',
                      'location_detail': item['location_detail'] ?? item['detilLokasi'] ?? item['lokasi'] ?? '',
                      'date': item['date'] ?? item['tanggal'] ?? '',
                      'time': item['time'] ?? item['waktu'] ?? '',
                      'remark': item['remark'] ?? item['detilTemuan'] ?? '',
                      'image': item['image'] ?? item['fotoTemuan'],
                      'status': item['status'] is int ? item['status'] : 0,
                      'pja_id': (item['nik_pja'] == userNik || item['nikPja'] == userNik) ? profileId : (item['pja_id'] ?? 0),
                      'pic_id': (item['nik_pic'] == userNik || item['nikPic'] == userNik) ? profileId : (item['pic_id'] ?? 0),
                      'employee_id': (item['nik'] == userNik) ? profileId : (item['employee_id'] ?? 0),
                      'nik': item['nik'] ?? userNik,
                      'nik_pja': item['nik_pja'] ?? item['nikPja'] ?? '',
                      'nik_pic': item['nik_pic'] ?? item['nikPic'] ?? '',
                      'plan': item['plan'] ?? item['rencanaPerbaikan'],
                      'plan_date': item['plan_date'] ?? item['tanggalRencanaPerbaikan'],
                      'action': item['action'] ?? item['perbaikan'],
                      'action_date': item['action_date'] ?? item['tanggalPerbaikan'],
                      'action_image': item['action_image'] ?? item['fotoPerbaikan'],
                      'table': widget.module.name,
                      'category': widget.module.name,
                      'created_at': item['created_at'] ?? DateTime.now().toString(),
                      'updated_at': DateTime.now().toString(),
                    };
                    final existing = await _db.get('action_plans', id);
                    if (existing == null) {
                      await _db.insert('action_plans', row);
                    } else {
                      await _db.update('action_plans', row, id);
                    }
                  }
                }
              }
            }
          });
        } catch (_) {}
      }
    }
    _getData();
  }


  void _getData() {
    final profileId = _profile?.id ?? 0;
    final userNik = _profile?.noNik ?? '';
    var qry = '';
    var select =
        '''select tr.*, me1.name as area_name, me2.name as location_name''';
    var joinArea =
        '''left join enum_masters me1 on me1.type='area' and me1.id=tr.area_id and me1.deleted_at is null
        left join enum_masters me2 on me2.type='location' and me2.id=tr.location_id and me2.deleted_at is null''';

    switch (widget.module) {
      case Module.inspection:
      case Module.inspectionDaily:
      case Module.inspectionWeekly:
      case Module.simama:
        qry = '''$select, im."name" as jenis_inspeksi,
        (select e.nama_lengkap from employees e where e.id=tr.pja_id) as pja_name,
        (select e.nama_lengkap from employees e where e.id=tr.inspektor1_id) as inspektor1_name,
        (select e.nama_lengkap from employees e where e.id=tr.inspektor2_id) as inspektor2_name,
        (select e.nama_lengkap from employees e where e.id=tr.inspektor3_id) as inspektor3_name,
        (select e.nama_lengkap from employees e where e.id=tr.inspektor4_id) as inspektor4_name,
        (select e.nama_lengkap from employees e where e.id=tr.inspektor5_id) as inspektor5_name,
        (select em."name" from enum_masters em where em."type"='shift' and em.id=tr.shift_id) as shift_name
        from inspection_trans tr $joinArea
        left join inspection_masters im on im.id=tr.inspection_id and im.deleted_at is null and im.ref_id is null
        where tr.deleted_at is null and (tr.employee_id=$profileId or tr.employee_id=0 or tr.employee_id is null or tr.nik='$userNik') and (tr.category='${widget.module.name}' or tr.category is null or tr.category='') order by tr.id desc''';
        _table = 'inspection_trans';
        break;
      case Module.hazard:
        qry = '''$select,
        (select hm."name" from hazard_masters hm where hm."type"='status' and hm.id=tr.hazard_id) as kategori_bahaya,
        (select hm."name" from hazard_masters hm where hm."type"='danger' and hm.id=tr.hazard_danger_id) as tingkat_resiko,
        (select hm."name" from hazard_masters hm where hm."type"='type' and hm.id=tr.hazard_type_id) as jenis_bahaya,
        (select hm."name" from hazard_masters hm where hm."type"='subtype' and hm.id=tr.hazard_subtype_id) as jenis_ketidaksesuaian,
        (select e.nama_lengkap from employees e where e.id=tr.pja_id) as pja_name
        from hazard_trans tr $joinArea
        where tr.deleted_at is null and (tr.employee_id=$profileId or tr.nik='$userNik' or (tr.sync_id is null and (tr.employee_id=0 or tr.employee_id is null))) order by tr.id desc''';
        _table = 'hazard_trans';
        break;
      case Module.coaching:
        qry = '''$select from coaching_trans tr $joinArea
        where tr.deleted_at is null and (tr.employee_id=$profileId or tr.nik='$userNik' or (tr.sync_id is null and (tr.employee_id=0 or tr.employee_id is null))) order by tr.id desc''';
        _table = 'coaching_trans';
        break;
      case Module.observation:
        qry = '''$select,
        (select me."name" from enum_masters me where me."type"='dept' and me.id=tr.dept_id) as departemen_pekerja_yang_diamati,
        (select om."name" from observation_masters om where om."type"='document' and om.id=tr.doc_id) as dokumen_pendukung,
        (select om."name" from observation_masters om where om."type"='risk' and om.id=tr.risk_id) as resiko_kritis
        from observation_trans tr $joinArea
        where tr.deleted_at is null and (tr.employee_id=$profileId or tr.nik='$userNik' or (tr.sync_id is null and (tr.employee_id=0 or tr.employee_id is null))) order by tr.id desc''';
        _table = 'observation_trans';
        break;
      case Module.p2h:
        qry = '''select tr.*, 
        COALESCE(tr.no_lambung, mv.code, '') as no_lambung_kendaraan,
        COALESCE(tr.jenis_kendaraan, mv.type, '') as jenis_kendaraan,
        COALESCE(tr.merek, mv."name", '') as merek_kendaraan,
        COALESCE(tr.no_lambung, mv.code, '') as area_name,
        COALESCE(tr.jenis_kendaraan, mv.type, '') as location_name
        from p2h_trans tr
        left join vehicle_masters mv on mv.id=tr.vehicle_id and mv.deleted_at is null
        where tr.deleted_at is null and (tr.employee_id=$profileId or tr.employee_id=0 or tr.employee_id is null or tr.nik='$userNik') order by tr.id desc''';
        _table = 'p2h_trans';
        break;
      case Module.p5m:
        qry = '''select tr.*,
        COALESCE(tr.area, me1.name, '-') as area_name,
        COALESCE(tr.lokasi, me2.name, '-') as location_name,
        COALESCE(tr.topik, tr.judul, (select pm."name" from p5m_masters pm where pm."type"='topic-p5m' and pm.id=tr.topic_id), 'P5M & Fit to Work') as topic_name
        from p5m_trans tr $joinArea
        where tr.deleted_at is null and (tr.employee_id=$profileId or tr.employee_id=0 or tr.employee_id is null or tr.nik='$userNik') order by tr.id desc''';
        _table = 'p5m_trans';
        break;
      case Module.safety:
        qry = '''$select from safety_trans tr $joinArea
        where tr.deleted_at is null and (tr.employee_id=$profileId or tr.nik='$userNik' or (tr.sync_id is null and (tr.employee_id=0 or tr.employee_id is null))) order by tr.id desc''';
        _table = 'safety_trans';
        break;
      case Module.induction:
        qry = '''$select from k3_trans tr $joinArea
        where tr.deleted_at is null and (tr.employee_id=$profileId or (tr.sync_id is null and (tr.employee_id=0 or tr.employee_id is null))) order by tr.id desc''';
        _table = 'k3_trans';
        break;
    }

    if (widget.history == History.action) {
      qry = '''$select, 
      (case when tr.updated_at is null then null else 1 end) as sync_id,
      (select e.nama_lengkap from employees e where e.id=tr.pja_id) as pja_name,
      (select e.nama_lengkap from employees e where e.id=tr.pic_id) as pic_name
      from action_plans tr $joinArea
      where tr.deleted_at is null 
        and ((tr.pja_id=$profileId and tr.status<1) or (tr.pic_id=$profileId and tr.status<2) or tr.nik_pja='$userNik' or tr.nik_pic='$userNik' or tr.employee_id=$profileId or tr.nik='$userNik')
        and (tr.category='${widget.module.name}' or tr.table='${widget.module.name}' or tr.category is null or tr.category='')
        and tr.status < 2
      order by tr.id desc''';
      _table = 'action_plans';
    }

    if (widget.history == History.monitoring) {
      qry = '''$select, 
      (case when tr.updated_at is null then null else 1 end) as sync_id,
      (select e.nama_lengkap from employees e where e.id=tr.pja_id) as pja_name,
      (select e.nama_lengkap from employees e where e.id=tr.pic_id) as pic_name
      from action_plans tr $joinArea
      where tr.deleted_at is null 
        and ((tr.pja_id=$profileId and tr.status>0) or (tr.pic_id=$profileId and tr.status>1) or tr.employee_id=$profileId or tr.nik_pja='$userNik' or tr.nik_pic='$userNik' or tr.nik='$userNik')
        and (tr.category='${widget.module.name}' or tr.table='${widget.module.name}' or tr.category is null or tr.category='')
        and tr.status < 2
      order by tr.id desc''';
      _table = 'action_plans';
    }

    if (qry != '') {
      () async {

        final val = await _db.rawQuery(qry);
        if (!mounted) return;
        if (val.isNotEmpty) {
          debugPrint('--- $_table : ${val.length} ---');

          if (widget.lastId != null) {
            var lastData =
                val.where((e) => e['id'] as int == widget.lastId).toList();
            if (lastData.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HistoryDetailPage(
                    widget.module,
                    widget.history,
                    lastData[0] as Map<String, dynamic>,
                  ),
                ),
              );
              return;
            }
          }
          setState(() => _rawData = val.toList());
        } else {
          setState(() => _rawData = []);
        }
      }();
    }
  }

  void _feedBack(bool val) {
    if (val == true) {
      _getData();
      SnackBarMsg.success(context, 'Berhasil sinkron!');
    } else {
      SnackBarMsg.danger(context, 'Gagal sinkron!');
    }
  }

  Future<void> _editObservation(Map<String, dynamic> row) async {
    if (!mounted) return;
    final editData = Map<String, dynamic>.from(row);
    // Navigation is intentionally immediate; an absent local detail cache
    // must never prevent opening the edit form for a server report.
    if (!mounted) return;
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ObservationFormPage(editData: editData)));
    _fetchAndRefresh();
  }

  Future<dynamic> _showBottomSheet(int index) {
    var sync = (_rawData[index]['sync_id'] == null) ? false : true;
    return showModalBottomSheet(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(
        maxHeight: 560,
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              ListTile(
                title: const Text(
                  'Tampilkan',
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: Icon(
                  Icons.remove_red_eye,
                  color: Colors.indigo.shade400,
                ),
                contentPadding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
                shape:
                    Border(bottom: BorderSide(color: Colors.indigo.shade100)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HistoryDetailPage(
                        widget.module,
                        widget.history,
                        _rawData[index] as Map<String, dynamic>,
                      ),
                    ),
                  );
                },
              ),
              if (widget.module == Module.simama)
                ListTile(
                  title: const Text(
                    'Edit Laporan',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.edit_note_rounded,
                    color: Color(0xFF7C3AED),
                  ),
                  contentPadding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
                  shape: Border(bottom: BorderSide(color: Colors.indigo.shade100)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SimamaFormPage(
                          widget.module,
                          editData: _rawData[index] as Map<String, dynamic>,
                        ),
                      ),
                    ).then((_) => _getData());
                  },
                ),
              if (widget.module == Module.p2h)
                ListTile(
                  title: const Text(
                    'Bagikan Laporan (Share PDF / WA)',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.share_rounded,
                    color: Color(0xFF0284C7),
                  ),
                  contentPadding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
                  shape: Border(bottom: BorderSide(color: Colors.indigo.shade100)),
                  onTap: () {
                    Navigator.pop(context);
                    P2hShareService.showShareModal(context, _rawData[index] as Map<String, dynamic>);
                  },
                ),
              if (widget.module == Module.p5m)
                ListTile(
                  title: const Text(
                    'Edit Laporan P5M',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.edit_note_rounded,
                    color: Color(0xFF0D9488),
                  ),
                  contentPadding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
                  shape: Border(bottom: BorderSide(color: Colors.indigo.shade100)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => P5MFormPage(
                          editData: _rawData[index] as Map<String, dynamic>,
                        ),
                      ),
                    ).then((_) => _getData());
                  },
                ),
              if (widget.module == Module.p5m)
                ListTile(
                  title: const Text(
                    'Bagikan Laporan Fit to Work (PDF / WA)',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.share_rounded,
                    color: Color(0xFF0D9488),
                  ),
                  contentPadding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
                  shape: Border(bottom: BorderSide(color: Colors.indigo.shade100)),
                  onTap: () {
                    Navigator.pop(context);
                    P5mShareService.showShareModal(context, _rawData[index] as Map<String, dynamic>);
                  },
                ),
              if (widget.module == Module.hazard)
                ListTile(
                  title: const Text(
                    'Edit Laporan Hazard',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.edit_note_rounded,
                    color: Color(0xFFEA580C),
                  ),
                  contentPadding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
                  shape: Border(bottom: BorderSide(color: Colors.indigo.shade100)),
                  onTap: () {
                    Navigator.pop(context);
                    final raw = _rawData[index] as Map<String, dynamic>;
                    final hazardItem = HazardReportItem.fromJson(raw);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HazardCreatePage(
                          editItem: hazardItem,
                        ),
                      ),
                    ).then((_) => _getData());
                  },
                ),
              if (widget.module == Module.hazard)
                ListTile(
                  title: const Text(
                    'Bagikan Laporan (Share PDF / WA)',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.share_rounded,
                    color: Color(0xFFEA580C),
                  ),
                  contentPadding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
                  shape: Border(bottom: BorderSide(color: Colors.indigo.shade100)),
                  onTap: () {
                    Navigator.pop(context);
                    HazardPdfService.showShareModalFromMap(context, _rawData[index] as Map<String, dynamic>);
                  },
                ),
              if (widget.module == Module.hazard)
                ListTile(
                  title: const Text(
                    'Cetak PDF',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: Color(0xFFEA580C),
                  ),
                  contentPadding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
                  shape: Border(bottom: BorderSide(color: Colors.indigo.shade100)),
                  onTap: () {
                    Navigator.pop(context);
                    HazardPdfService.printHazardPdfFromMap(_rawData[index] as Map<String, dynamic>);
                  },
                ),
              ListTile(
                title: Text(
                  'Sinkron',
                  style: TextStyle(
                    color: (sync) ? Colors.black45 : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: Icon(
                  Icons.cloud_sync,
                  color: (sync) ? Colors.indigo.shade200 : Colors.indigo,
                ),
                contentPadding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
                shape:
                    Border(bottom: BorderSide(color: Colors.indigo.shade100)),
                onTap: (sync)
                    ? null
                    : () {
                        switch (widget.module) {
                          case Module.simama:
                            syncTran(_db, _api, 'simama',
                                    _rawData[index]['id'] as int)
                                .then((val) => _feedBack(val));
                            break;
                          case Module.inspection:
                          case Module.inspectionDaily:
                          case Module.inspectionWeekly:
                            syncTran(_db, _api, 'inspection',
                                    _rawData[index]['id'] as int)
                                .then((val) => _feedBack(val));
                            break;
                          default:
                            syncTran(_db, _api, widget.module.name,
                                    _rawData[index]['id'] as int)
                                .then((val) => _feedBack(val));
                            break;
                        }
                        Navigator.pop(context);
                      },
              ),
                if (widget.module == Module.observation && sync)
                  ListTile(
                    title: const Text('Edit Observasi',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.edit_outlined),
                    contentPadding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
                    shape: Border(
                        bottom: BorderSide(color: Colors.indigo.shade100)),
                    onTap: () {
                      Navigator.pop(context);
                      _editObservation(_rawData[index] as Map<String, dynamic>);
                    },
                  ),
              ListTile(
                title: Text(
                  'Hapus Data',
                  style: TextStyle(
                    color: (sync) ? Colors.black45 : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: Icon(
                  Icons.delete_forever,
                  color: (sync) ? Colors.indigo.shade200 : Colors.indigo,
                ),
                contentPadding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('Delete Data'),
                        content: const Text(
                          'Apakah anda akan menghapus data ini?',
                        ),
                        actions: [
                          TextButton(
                            style: TextButton.styleFrom(
                              textStyle: Theme.of(context).textTheme.labelLarge,
                            ),
                            child: const Text('Cancel'),
                            onPressed: () => Navigator.pop(context),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              textStyle: Theme.of(context).textTheme.labelLarge,
                            ),
                            child: const Text('Ok'),
                            onPressed: () {
                              Navigator.pop(context);
                              final rowItem = _rawData[index];
                              final id = rowItem['id'] as int;
                              final syncId = rowItem['sync_id'];
                              () async {
                                var canDelete = true;
                                if (widget.module == Module.observation && sync && syncId != null) {
                                    canDelete = await _api.deleteObservation(syncId as int);
                                  } else if (widget.module == Module.hazard && sync && syncId != null) {
                                    final res = await _api.deleteHazardDirect(syncId as int);
                                    canDelete = res.isRight();
                                  }
                                if (!canDelete) {
                                  if (mounted) SnackBarMsg.danger(this.context, 'Gagal menghapus laporan server.');
                                  return;
                                }
                                final val = await _db.delete(_table, id);
                                if (!mounted) return;
                                if (val > 0) {
                                  _db.execute(
                                      '''delete from ${_table.replaceAll('_trans', '')}_details 
                                      where tran_id=$id''');
                                  setState(() => _rawData.removeAt(index));
                                  SnackBarMsg.success(this.context, 'Data berhasil dihapus!');
                                  OfflineSyncService.instance.refresh();
                                  if (syncId != null && widget.module != Module.observation) {
                                    final modName = (widget.module == Module.simama) ? 'simama' : widget.module.name;
                                    _api.dio.delete('/tran/$modName/$syncId').then((_) {}, onError: (_) {});
                                  }
                                } else {
                                  SnackBarMsg.danger(this.context, 'Data gagal dihapus!');
                                }
                              }();
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = moduleAccentColor(widget.module);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: TopBar(
        title: '${titleCase(widget.history.name)} ${pageTitle(widget.module)}',
      ),
      body: RefreshIndicator(
        onRefresh: () async => _fetchAndRefresh(),
        child: SingleChildScrollView(
          controller: _scrollCtrl,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SapModuleHeader(
                module: widget.module,
                trailing: SapStatusPill(
                  label: '${_displayData.length} Data',
                  color: Colors.white,
                  icon: Icons.dataset_rounded,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Cari laporan, lokasi, PJA, atau PIC...',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _historyTitle(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              if (_displayData.isNotEmpty)
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _displayData.length,
                  itemBuilder: (context, index) {
                    final row = _displayData[index] as Map<String, dynamic>;
                    return _HistoryRecordCard(
                      row: row,
                      module: widget.module,
                      history: widget.history,
                      accent: accent,
                      onTap: () {
                        if (widget.history == History.summary) {
                          _showBottomSheet(index);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HistoryDetailPage(
                                widget.module,
                                widget.history,
                                row,
                              ),
                            ),
                          ).then((_) => _getData());
                        }
                      },
                    );
                  },
                )
              else
                _EmptyHistoryState(module: widget.module),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        onPressed: () {
          openPage(context, widget.module);
          Future.delayed(const Duration(seconds: 1), () => _fetchAndRefresh());
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Buat Baru'),
      ),
    );
  }

  String _historyTitle() {
    switch (widget.history) {
      case History.summary:
        return 'Riwayat Laporan';
      case History.action:
        return 'Action yang Perlu Ditindaklanjuti';
      case History.monitoring:
        return 'Monitoring Progress Action';
    }
  }
}

class _HistoryRecordCard extends StatelessWidget {
  const _HistoryRecordCard({
    required this.row,
    required this.module,
    required this.history,
    required this.accent,
    required this.onTap,
  });

  final Map<String, dynamic> row;
  final Module module;
  final History history;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse('${row['date']}');
    final sync = row['sync_id'] != null;
    final title = titleCase('${row['title'] ?? pageTitle(module)}');
    final remark = titleCase('${row['remark'] ?? row['detil_temuan'] ?? '-'}');
    final area = titleCase('${row['area_name'] ?? row['area'] ?? '-'}');
    final location = titleCase('${row['location_name'] ?? row['location_detail'] ?? row['lokasi'] ?? '-'}');
    final pjaName = row['pja_name'] ?? row['pja'];
    final picName = row['pic_name'] ?? row['pic'];
    final timeText = [
      if (date != null) DateFormat('dd MMM yyyy').format(date),
      if ((row['time'] ?? '').toString().isNotEmpty) row['time'],
    ].join(' • ');

    return SapSoftCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(moduleIcon(module), color: accent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (history == History.summary)
                          sync
                              ? const SapStatusPill(
                                  label: 'Sudah Sinkron',
                                  color: Color(0xFF16A34A),
                                  icon: Icons.cloud_done_rounded,
                                )
                              : const SapStatusPill(
                                  label: 'Belum Sinkron',
                                  color: Color(0xFFEF4444),
                                  icon: Icons.cloud_off_rounded,
                                )
                        else ...[
                          SapStatusPill(
                            label: _actionStatusLabel(row),
                            color: _actionStatusColor(row),
                            icon: Icons.flag_rounded,
                          ),
                          if (!sync)
                            const SapStatusPill(
                              label: 'Belum Sinkron',
                              color: Color(0xFFEF4444),
                              icon: Icons.cloud_off_rounded,
                            ),
                        ],
                        if (timeText.isNotEmpty)
                          SapStatusPill(
                            label: timeText,
                            color: const Color(0xFF64748B),
                            icon: Icons.schedule_rounded,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: Colors.blueGrey.shade300),
            ],
          ),
          const SizedBox(height: 10),
          if (module == Module.p2h) ...[
            SapInfoLine(
              icon: Icons.directions_car_rounded,
              text: 'Unit: ${row['no_lambung_kendaraan'] ?? row['no_lambung'] ?? '-'} • ${row['merek_kendaraan'] ?? row['merek'] ?? '-'}',
            ),
            SapInfoLine(
              icon: Icons.category_rounded,
              text: 'Jenis: ${row['jenis_kendaraan'] ?? '-'}',
            ),
            SapInfoLine(
              icon: Icons.speed_rounded,
              text: 'Odometer: ${NumberFormat("#,##0", "id_ID").format(row['km'] ?? 0)} KM',
            ),
            SapInfoLine(
              icon: Icons.badge_rounded,
              text: 'SIMPER: ${(row['simper'] == 1 || row['simper_kimper'] == 'YA') ? 'Aktif' : 'Tidak Aktif'}',
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildP2hConditionBadge(row),
                InkWell(
                  onTap: () => P2hShareService.showShareModal(context, row),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.share_rounded, size: 14, color: Color(0xFF0284C7)),
                        SizedBox(width: 4),
                        Text(
                          'Bagikan',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ] else if (module == Module.p5m) ...[
            SapInfoLine(
              icon: Icons.topic_rounded,
              text: 'Topik: ${row['topic_name'] ?? row['topik'] ?? row['topic'] ?? row['judul'] ?? 'K3 Operasional'}',
            ),
            SapInfoLine(
              icon: Icons.map_rounded,
              text: 'Area: ${row['area_name'] ?? row['area'] ?? '-'}',
            ),
            SapInfoLine(
              icon: Icons.place_rounded,
              text: 'Detail Lokasi: ${row['location_name'] ?? row['lokasi'] ?? row['detil_lokasi'] ?? '-'}',
            ),
            if ((row['catatan'] ?? row['remark'] ?? '').toString().isNotEmpty && row['catatan'] != '-')
              SapInfoLine(
                icon: Icons.notes_rounded,
                text: 'Catatan: ${row['catatan'] ?? row['remark']}',
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildP5mConditionBadge(row),
                InkWell(
                  onTap: () => P5mShareService.showShareModal(context, row),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.share_rounded, size: 14, color: Color(0xFF0D9488)),
                        SizedBox(width: 4),
                        Text(
                          'Bagikan',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0D9488)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            SapInfoLine(icon: Icons.notes_rounded, text: 'Note: $remark'),
            SapInfoLine(icon: Icons.map_rounded, text: 'Area: $area'),
            SapInfoLine(icon: Icons.place_rounded, text: 'Lokasi: $location'),
            if (pjaName != null && pjaName.toString().isNotEmpty && pjaName != '-')
              SapInfoLine(icon: Icons.person_outline_rounded, text: 'PJA: $pjaName'),
            if (picName != null && picName.toString().isNotEmpty && picName != '-')
              SapInfoLine(icon: Icons.assignment_ind_outlined, text: 'PIC: $picName'),
          ],
        ],
      ),
    );
  }

  Widget _buildP2hConditionBadge(Map<String, dynamic> row) {
    final eval = P2hShareService.evaluateVehicleCondition(row);
    final isStop = eval['defectsA'].isNotEmpty;
    final isWarning = eval['totalDefects'] > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isStop ? const Color(0xFFFEF2F2) : (isWarning ? const Color(0xFFFFFBEB) : const Color(0xFFF0FDF4)),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isStop ? const Color(0xFFFCA5A5) : (isWarning ? const Color(0xFFFDE68A) : const Color(0xFF86EFAC)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isStop ? Icons.cancel_rounded : (isWarning ? Icons.warning_amber_rounded : Icons.check_circle_rounded),
            size: 13,
            color: isStop ? const Color(0xFFDC2626) : (isWarning ? const Color(0xFFD97706) : const Color(0xFF16A34A)),
          ),
          const SizedBox(width: 4),
          Text(
            eval['statusText'] as String,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: isStop ? const Color(0xFFB91C1C) : (isWarning ? const Color(0xFFB45309) : const Color(0xFF15803D)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildP5mConditionBadge(Map<String, dynamic> row) {
    final eval = P5mShareService.evaluateFitStatus(row);
    final isFit = eval['isFit'] as bool;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isFit ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isFit ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isFit ? Icons.check_circle_rounded : Icons.warning_rounded,
            size: 13,
            color: isFit ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
          ),
          const SizedBox(width: 4),
          Text(
            isFit ? 'FIT TO WORK' : 'UNFIT',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: isFit ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
            ),
          ),
        ],
      ),
    );
  }

  String _actionStatusLabel(Map<String, dynamic> row) {
    final status = row['status'];
    if (status == 0) return 'Open (Menunggu PJA)';
    if (status == 1) return 'In Progress (Tindak Lanjut)';
    if (status == 2) return 'Closed (Selesai)';
    if (status is int && globals.status.containsKey(status)) {
      return '${globals.status[status]}';
    }
    return '${row['statusName'] ?? 'Open'}';
  }

  Color _actionStatusColor(Map<String, dynamic> row) {
    final status = row['status'];
    if (status == 0) return const Color(0xFFEF4444);
    if (status == 1) return const Color(0xFFF59E0B);
    if (status == 2) return const Color(0xFF16A34A);
    return const Color(0xFFF59E0B);
  }
}

class _EmptyHistoryState extends StatelessWidget {
  const _EmptyHistoryState({required this.module});

  final Module module;

  @override
  Widget build(BuildContext context) {
    final accent = moduleAccentColor(module);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.inbox_rounded, color: accent, size: 42),
          ),
          const SizedBox(height: 18),
          Text(
            'Data ${pageTitle(module)} belum ada',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Tekan tombol Buat Baru untuk mulai membuat laporan.',
            style: TextStyle(
              color: Colors.blueGrey.shade600,
              fontSize: 13,
              height: 1.35,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

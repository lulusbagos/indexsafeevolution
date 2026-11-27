import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:intl/intl.dart';



import '../services/api.dart';

import '../models/notification_item_model.dart';

import '../services/database.dart';

import '../services/notification.dart';

import '../services/preference.dart';

import '../services/sync.dart';

import '../utils/enums.dart';


import '../utils/helpers.dart';

import 'approval/approval_center_page.dart';

import 'violation_queue_page.dart';
import 'dart:convert';
import 'reinduction_approval_page.dart';
import 'roster_settings_page.dart';

import 'hazard/hazard_hub_page.dart';

import 'history/history_page.dart';
import 'history/history_detail_page.dart';

import 'inspeksi/inspection_hub_page.dart';

import 'performance/action_tracker_page.dart';


import 'special_permit/special_permit_followup_page.dart';

import 'special_permit/special_permit_list_page.dart';



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

  // Static in-memory cache agar saat halaman dibuka langsung muncul instan (0 detik)
  static List<dynamic> _cachedNotifs = [];

  List<dynamic> _rawData = [];

  bool _isLoading = true;

  bool _isSyncing = false;

  bool _isOfflineMode = false;

  DateTime? _lastSyncTime;

  String _selectedFilter = 'all'; // 'all', 'pending_takeup', 'unread', 'hazard', 'inspection'



  @override

  void initState() {

    super.initState();

    // 1. Tampilkan data dari memory cache jika sudah ada (0 ms latency, instan)
    if (_cachedNotifs.isNotEmpty) {
      _rawData = List<dynamic>.from(_cachedNotifs);
      _isLoading = false;
    } else {
      _isLoading = true;
    }

    // 2. Ambil data SQLite lokal langsung tanpa menunda
    _loadLocalData();

    // 3. Jalankan sync online dan actions di background
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncOnlineData();
      _fetchApiActions();
    });

  }



  void _fetchApiActions() {

    Future.delayed(const Duration(milliseconds: 800), () async {

      /* get actions */

      for (var name in ['inspection', 'hazard'].toList()) {

        debugPrint('--- get action: $name ---');

        _api.getAction(name).then((res) {

          res.fold((error) {

            debugPrint(error['message'].toString());

          }, (response) async {

            const validCols = {

              'id',

              'code',

              'title',

              'area_id',

              'location_id',

              'location_detail',

              'date',

              'time',

              'remark',

              'image',

              'video',

              'status',

              'pja_id',

              'pic_id',

              'plan',

              'plan_date',

              'overdue',

              'reason',

              'action',

              'action_date',

              'action_image',

              'action_video',

              'table',

              'category',

              'tran_id',

              'detail_id',

              'company_id',

              'employee_id',

              'created_at',

              'updated_at',

              'deleted_at'

            };

            for (var item in (response['data'] as List).toList()) {

              var row = <String, dynamic>{};

              for (var e in (item as Map<String, dynamic>).entries) {

                if (e.value != null && validCols.contains(e.key)) {

                  row[e.key] = e.value;

                }

              }

              row.remove('created_by');

              row.remove('updated_by');

              row.remove('deleted_by');

              if (row['id'] == null) continue;

              _db.get('action_plans', row['id'] as int).then((get) {

                if (get == null) {

                  _db.insert('action_plans', row).then((insertId) {

                    debugPrint('--- insert action_plans: $insertId ---');

                    var profileId = _profile?.id;

                    var userNik = _profile?.noNik?.trim() ?? '';

                    var status = '';

                    if (row['employee_id'] != null &&

                        (row['employee_id'] as int) == profileId) {

                      status = 'Terkirim';

                    }

                    if ((row['pja_id'] != null &&

                            (row['pja_id'] as int) == profileId) ||

                        (row['nik_pja'] != null &&

                            userNik.isNotEmpty &&

                            row['nik_pja'].toString().trim() == userNik)) {

                      status = 'Ditugaskan ke Anda (PJA)';

                    }

                    if ((row['pic_id'] != null &&

                            (row['pic_id'] as int) == profileId) ||

                        (row['nik_pic'] != null &&

                            userNik.isNotEmpty &&

                            row['nik_pic'].toString().trim() == userNik)) {

                      status = 'Ditugaskan ke Anda (PIC)';

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

                        debugPrint('--- update action_plans: ${row['id']} ---');

                        var profileId = _profile?.id;

                        var userNik = _profile?.noNik?.trim() ?? '';

                        var status = '';

                        if (row['status'] as int == 1) {

                          if (row['employee_id'] != null &&

                              (row['employee_id'] as int) == profileId) {

                            status = 'Diproses PJA';

                          }

                          if ((row['pic_id'] != null &&

                                  (row['pic_id'] as int) == profileId) ||

                              (row['nik_pic'] != null &&

                                  userNik.isNotEmpty &&

                                  row['nik_pic'].toString().trim() ==

                                      userNik)) {

                            status = 'Ditugaskan ke Anda (PIC)';

                          }

                        }

                        if (row['status'] as int == 2) {

                          if (row['employee_id'] != null &&

                              (row['employee_id'] as int) == profileId) {

                            status = 'Selesai Dikerjakan PIC';

                          }

                          if ((row['pja_id'] != null &&

                                  (row['pja_id'] as int) == profileId) ||

                              (row['nik_pja'] != null &&

                                  userNik.isNotEmpty &&

                                  row['nik_pja'].toString().trim() ==

                                      userNik)) {

                            status = 'Selesai Dikerjakan PIC';

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

  }



  @override

  void dispose() {

    _scrollCtrl.dispose();

    super.dispose();

  }



  void _processRawNotificationItems(

      List<NotificationItemModel> notifs, List<Map<String, dynamic>> combined) {

    for (var n in notifs) {

      if (n.isActioned ||

          n.notifType.toLowerCase().contains('completed') ||

          n.notifType.toLowerCase().contains('closed')) {

        continue;

      }



      final titleLower = (n.title).toLowerCase();

      final msgLower = (n.message).toLowerCase();

      final urlLower = (n.url ?? '').toLowerCase();

      final typeLower = (n.notifType).toLowerCase();



      final isCoaching = typeLower.contains('coaching') ||

          titleLower.contains('coaching') ||

          titleLower.contains('pembinaan') ||

          msgLower.contains('coaching') ||

          msgLower.contains('pembinaan') ||

          urlLower.contains('performance');



      final isRoster = typeLower.contains('roster') ||

          urlLower.contains('roster') ||

          titleLower.contains('roster') ||

          titleLower.contains('periode tugas');



      if (isCoaching && n.createdAt != null) {

        final diffDays = DateTime.now().difference(n.createdAt!).inDays;

        if (diffDays >= 7) continue;

      }



      final isViolation =

          typeLower.contains('violation') || titleLower.contains('pelanggaran');



      final isGateMovement = typeLower.contains('movement') ||

          titleLower.contains('gerbang') ||

          titleLower.contains('gate');



      final isHazard = !isCoaching &&

          !isRoster &&

          !isViolation &&

          !isGateMovement &&

          (typeLower.contains('hazard') || urlLower.contains('hazard'));

      final isInspect = !isCoaching &&

          !isRoster &&

          !isViolation &&

          !isGateMovement &&

          (typeLower.contains('inspect') || urlLower.contains('inspect'));



      final String category = isCoaching

          ? 'coaching'

          : (isRoster

              ? 'roster'

              : (isViolation

                  ? 'violation'

                  : (isGateMovement

                      ? 'movement'

                      : (isHazard

                          ? 'hazard'

                          : (isInspect ? 'inspection' : 'general')))));



      combined.add({

        'id': n.id,

        'is_server_notif': true,

        'title': n.title,

        'remark': n.message,

        'category': (n.category != null && n.category!.isNotEmpty)

            ? n.category

            : category,

        'notif_type': isCoaching ? 'coaching' : n.notifType,

        'url': n.url,

        'logo': n.logo,

        'sender_name': n.senderName,

        'priority': n.priority,

        'payload': n.payload,

        'action_text': n.actionText,

        'is_read': n.isRead,

        'is_actioned': n.isActioned,

        'is_action_required': (isCoaching || isRoster || isGateMovement)

            ? false

            : (isViolation ? true : n.isActionRequired),

        'date': n.createdAt != null

            ? DateFormat('yyyy-MM-dd').format(n.createdAt!)

            : '',

        'time':

            n.createdAt != null ? DateFormat('HH:mm').format(n.createdAt!) : '',

        'created_at_dt': n.createdAt ?? DateTime.now(),

        'status': isCoaching

            ? -1

            : (isRoster || isGateMovement

                ? (n.isRead ? 1 : 0)

                : (isViolation ? 0 : (n.isActioned ? 2 : (n.isRead ? 1 : 0)))),

        'area_name': isCoaching

            ? 'Kinerja & Pembinaan'

            : (isRoster

                ? 'Jadwal Kerja & SAP'

                : (isViolation

                    ? 'K3 Pelanggaran Permit'

                    : (isGateMovement

                        ? 'Security & Akses Gerbang'

                        : (isHazard ? 'K3 Temuan Lapangan' : 'Sistem SAP')))),

        'location_name': isRoster

            ? 'Pengaturan Roster'

            : (isViolation

                ? 'Area Operasional Tambang'

                : (isGateMovement ? 'Pos Security Tambang' : (n.url ?? ''))),

      });

    }
  }

  bool _isItemPendingTakeUp(Map<String, dynamic> item) {
    final status = (item['status'] as num?)?.toInt() ?? 0;
    final isActioned = item['is_actioned'] == true;
    if (isActioned || status >= 2) return false;

    final title = (item['title'] ?? '').toString().toLowerCase();
    final remark = (item['remark'] ?? '').toString().toLowerCase();

    // Bukan pending take up jika hanya konfirmasi pengajuan / dalam proses
    if (title.contains('dalam proses') ||
        title.contains('berhasil diajukan') ||
        title.contains('telah diajukan') ||
        remark.contains('sedang menunggu persetujuan dari')) {
      return false;
    }

    final isActionReq = item['is_action_required'] == true;
    final isApproval = item['is_approval_item'] == true;
    final isSpecialPermit = item['is_special_permit'] == true;
    final cat = (item['category'] ?? '').toString().toLowerCase();
    final notifType = (item['notif_type'] ?? '').toString().toLowerCase();
    final priority = (item['priority'] ?? '').toString().toLowerCase();

    // Pending take up jika:
    // 1. Approval item yang belum diapprove
    if (isApproval || cat.contains('approval') || notifType.contains('approval')) return true;
    // 2. Special permit observation high-risk yang belum diobservasi
    if (isSpecialPermit || cat.contains('special_permit')) return true;
    // 3. Penugasan PJA atau PIC yang statusnya masih 0 (belum di-take up / belum ditentukan PIC)
    if (title.contains('penugasan pja') ||
        title.contains('penugasan pic') ||
        remark.contains('take up') ||
        remark.contains('tentukan pic')) {
      return true;
    }
    // 4. Action required dengan status 0
    if (isActionReq && status < 1) return true;
    // 5. Urgent priority yang belum actioned
    if (priority == 'urgent' && status < 1) return true;

    return false;
  }

  bool _isItemUnread(Map<String, dynamic> item) {
    return item['is_read'] != true;
  }

  int _calcUnreadCount(List<dynamic> list) {
    return list.where((item) {
      if (item is! Map) return false;
      final isRead = item['is_read'] == true;
      final isActionReq = item['is_action_required'] == true;
      final status = (item['status'] as num?)?.toInt() ?? 0;
      if (!isRead) return true;
      if (isActionReq && status < 2) return true;
      return false;
    }).length;
  }

  /// 1. Ambil data lokal SQLite INSTAN (0 detik) agar data langsung tampil tanpa nunggu network
  Future<void> _loadLocalData() async {
    try {
      final List<Map<String, dynamic>> combined = [];

      // Notifikasi dari database lokal SQLite (3 bulan terakhir)
      final localNotifs = await _db.getLocalNotifications(months: 3);
      _processRawNotificationItems(localNotifs, combined);

      // Action plans lokal dari SQLite
      final profileId = _profile?.id ?? 0;
      if (profileId > 0) {
        try {
          final val = await _db.rawQuery(
              '''select tr.*, me1.name as area_name, me2.name as location_name, 1 as sync_id,
                (select e.nama_lengkap from employees e where e.id=tr.pja_id) as pja_name,
                (select e.nama_lengkap from employees e where e.id=tr.pic_id) as pic_name
                from action_plans tr
                left join enum_masters me1 on me1.type='area' and me1.id=tr.area_id and me1.deleted_at is null
                left join enum_masters me2 on me2.type='location' and me2.id=tr.location_id and me2.deleted_at is null
                where tr.deleted_at is null and ((tr.pja_id=$profileId and tr.status<1) or (tr.pic_id=$profileId and tr.status<2))
                order by tr.id desc''');

          for (var row in val) {
            final m = Map<String, dynamic>.from(row);
            m['is_server_notif'] = false;
            combined.add(m);
          }
        } catch (_) {}
      }

      // Pertahankan item online (approval & special permit) yang sudah ada di memori agar tidak hilang
      final existingOnlineItems = _rawData.where((item) {
        if (item is! Map) return false;
        return item['is_approval_item'] == true || item['is_special_permit'] == true;
      }).toList();

      for (var onlineItem in existingOnlineItems) {
        final onlineId = onlineItem['id'];
        final isAppr = onlineItem['is_approval_item'] == true;
        final exists = combined.any((c) =>
            c['id'] == onlineId &&
            (isAppr ? c['is_approval_item'] == true : c['is_special_permit'] == true));
        if (!exists) {
          combined.add(Map<String, dynamic>.from(onlineItem));
        }
      }

      // Urutkan berdasarkan waktu terbaru (created_at_dt descending)
      combined.sort((a, b) {
        final dtA = a['created_at_dt'] as DateTime? ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dtB = b['created_at_dt'] as DateTime? ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dtB.compareTo(dtA);
      });

      if (mounted) {
        setState(() {
          _rawData = combined;
          _cachedNotifs = List<dynamic>.from(combined);
          _isLoading = false;
        });
      }

      final unreadCount = _calcUnreadCount(combined);
      PreferenceService.setNotif(unreadCount);
      NotificationService.syncLauncherBadge(unreadCount);
    } catch (e) {
      debugPrint('[NotifPage] Error _loadLocalData: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }



  /// 2. Unduh dan perbarui data server di background (hemat kuota & jika offline tetap berjalan mulus)

  Future<void> _syncOnlineData({bool isManual = false}) async {

    if (_isSyncing) return;

    if (mounted) setState(() => _isSyncing = true);



    bool isSuccess = false;

    int downloadedCount = 0;



    try {

      final int maxLocalId = await _db.getMaxNotificationId();



      final serverRes = await _api.getNotifications(

        limit: maxLocalId == 0 ? 100 : 50,

        sinceId: maxLocalId > 0 ? maxLocalId : null,

        months: 3,

      );



      await serverRes.fold(

        (err) async {

          // Gagal sambung ke server -> Aktifkan flag Mode Offline

          if (mounted) setState(() => _isOfflineMode = true);

        },

        (newNotifs) async {

          isSuccess = true;

          downloadedCount = newNotifs.length;

          if (newNotifs.isNotEmpty) {

            await _db.saveLocalNotifications(newNotifs);

            await _db.purgeOldNotifications(months: 3);

          }

          if (mounted) {

            setState(() {

              _isOfflineMode = false;

              _lastSyncTime = DateTime.now();

            });

          }

        },

      );



      // Muat ulang data SQLite lokal setelah sync

      await _loadLocalData();



      // Jika online, tarik data approval dan special permit
      if (isSuccess) {
        try {
          final approvalRes = await _api.getPendingApprovals();
          approvalRes.fold(
            (_) {},
            (data) {
              final items = (data['data'] as List<dynamic>?) ?? [];
              _rawData.removeWhere((item) => item is Map && item['is_approval_item'] == true);
              for (var a in items) {
                final aMap = a as Map<String, dynamic>;
                final aId = aMap['approvalId'] as int? ?? 0;
                final mod = aMap['module']?.toString() ?? 'Persetujuan';
                final nomor = aMap['nomor']?.toString() ?? '-';
                final applicant =
                    aMap['applicantName']?.toString() ?? 'Pemohon';
                final comp = aMap['companyName']?.toString() ?? '-';
                final dept = aMap['department']?.toString() ?? '-';
                final roleTarget = aMap['roleName']?.toString() ?? 'Approver';
                final reqTimeStr = aMap['reqTime']?.toString();
                DateTime? reqDate;
                if (reqTimeStr != null) reqDate = DateTime.tryParse(reqTimeStr);

                _rawData.add({
                  'id': aId,
                  'is_server_notif': true,
                  'is_approval_item': true,
                  'title': 'Persetujuan $mod: $nomor',
                  'remark':
                      'Permohonan $mod oleh $applicant ($dept • $comp). Menunggu persetujuan Anda ($roleTarget).',
                  'category': 'approval',
                  'notif_type': 'approval_request',
                  'url': '/approval_center',
                  'sender_name': applicant,
                  'priority': 'urgent',
                  'payload': aId.toString(),
                  'action_text': 'Tinjau Persetujuan',
                  'is_read': false,
                  'is_actioned': false,
                  'is_action_required': true,
                  'date': reqDate != null
                      ? DateFormat('yyyy-MM-dd').format(reqDate)
                      : '',
                  'time': reqDate != null
                      ? DateFormat('HH:mm').format(reqDate)
                      : '',
                  'created_at_dt': reqDate ?? DateTime.now(),
                  'status': 0,
                  'area_name': 'Approval Center',
                  'location_name': mod,
                });
              }
            },
          );
        } catch (_) {}

        try {
          final spRes = await _api.getSpecialPermitAlerts();
          spRes.fold(
            (_) {},
            (spData) {
              final list = (spData['data'] as List<dynamic>?) ?? [];
              _rawData.removeWhere((item) => item is Map && item['is_special_permit'] == true);
              for (var sp in list) {
                final spMap = sp as Map<String, dynamic>;
                final reqId = spMap['reqId']?.toString() ?? '-';
                final actType =
                    (spMap['activityType']?.toString() ?? 'Pekerjaan Khusus')
                        .replaceAll('_', ' ');
                final loc = spMap['workLocation']?.toString() ??
                    'Area Operasional Tambang';
                final picName = spMap['applicantName']?.toString() ??
                    spMap['pjoName']?.toString() ??
                    'PIC Tim';
                final issueTime = spMap['issueTime']?.toString() ?? '';
                final issueDate = spMap['issueDate']?.toString() ?? '';

                _rawData.add({
                  'id': spMap['id'],
                  'is_server_notif': true,
                  'is_special_permit': true,
                  'raw_permit': spMap,
                  'title': '⚠️ Observasi High Risk: $reqId',
                  'remark':
                      'Kegiatan risiko tinggi $actType di $loc. Pengawas/PJO: $picName. Segera lakukan verifikasi & observasi lapangan!',
                  'category': 'special_permit',
                  'notif_type': 'special_permit_high_risk',
                  'url': 'special_permit_obs',
                  'sender_name': picName,
                  'priority': 'urgent',
                  'payload': spMap['id'],
                  'action_text': 'Observasi Sekarang',
                  'is_read': false,
                  'is_actioned': false,
                  'is_action_required': true,
                  'date': issueDate.isNotEmpty
                      ? issueDate.substring(0, 10.clamp(0, issueDate.length))
                      : '',
                  'time': issueTime,
                  'created_at_dt': DateTime.now(),
                  'status': 0,
                  'area_name': 'Special Permit',
                  'location_name': loc,
                });
              }
            },
          );
        } catch (_) {}

        // Urutkan kembali berdasarkan waktu terbaru
        _rawData.sort((a, b) {
          final dtA = (a is Map ? a['created_at_dt'] : null) as DateTime? ?? DateTime.fromMillisecondsSinceEpoch(0);
          final dtB = (b is Map ? b['created_at_dt'] : null) as DateTime? ?? DateTime.fromMillisecondsSinceEpoch(0);
          return dtB.compareTo(dtA);
        });
        _cachedNotifs = List<dynamic>.from(_rawData);

        if (mounted) setState(() {});
      }

      final syncUnread = _calcUnreadCount(_rawData);
      await PreferenceService.setNotif(syncUnread);
      await NotificationService.syncLauncherBadge(syncUnread);

      // Getaran fisik jika ada prioritas tinggi

      final hasPicAssignments = _rawData.any((item) {

        final isActionReq = item['is_action_required'] == true;

        final isRead = item['is_read'] == true;

        final status = (item['status'] as num?)?.toInt() ?? 0;

        final p = (item['priority'] ?? '').toString().toLowerCase();

        final isApproval = item['is_approval_item'] == true;

        final isSpecialPermit = item['is_special_permit'] == true;

        return (isActionReq && (!isRead || status < 2)) ||

            p == 'urgent' ||

            isApproval ||

            isSpecialPermit;

      });

      if (hasPicAssignments) {

        NotificationService.vibrateForPicAssignment();

      }

    } catch (e) {

      debugPrint('[NotifPage] Error _syncOnlineData: $e');

      if (mounted) setState(() => _isOfflineMode = true);

    } finally {

      if (mounted) setState(() => _isSyncing = false);

      if (isManual && mounted) {

        if (isSuccess) {

          ScaffoldMessenger.of(context).showSnackBar(

            SnackBar(

              content: Text(

                  'Berhasil menyinkronkan & mengunduh $downloadedCount notifikasi baru ke penyimpanan lokal HP (Mode Offline Siap).'),

              backgroundColor: const Color(0xFF009688),

              behavior: SnackBarBehavior.floating,

              duration: const Duration(seconds: 3),

            ),

          );

        } else {

          ScaffoldMessenger.of(context).showSnackBar(

            SnackBar(

              content: Text(

                  'Mode Offline: Menggunakan ${_rawData.length} notifikasi yang tersimpan di HP.'),

              backgroundColor: const Color(0xFFD97706),

              behavior: SnackBarBehavior.floating,

              duration: const Duration(seconds: 3),

            ),

          );

        }

      }

    }

  }



  Future<void> _getData() async {

    await _loadLocalData();

    await _syncOnlineData();

  }

  Future<void> _markAllAsRead() async {
    HapticFeedback.lightImpact();
    for (var item in _rawData) {
      item['is_read'] = true;
    }
    await _db.markAllLocalNotificationsRead();
    _api.markAllNotificationsRead();
    await PreferenceService.setNotif(0);
    await NotificationService.syncLauncherBadge(0);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Semua notifikasi telah ditandai sebagai dibaca.'),
          backgroundColor: Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }



  List<dynamic> get _filteredData {
    if (_selectedFilter == 'all') return _rawData;

    if (_selectedFilter == 'pending_takeup') {
      return _rawData.where((item) => item is Map<String, dynamic> && _isItemPendingTakeUp(item)).toList();
    }

    if (_selectedFilter == 'unread') {
      return _rawData.where((item) => item is Map<String, dynamic> && _isItemUnread(item)).toList();
    }

    if (_selectedFilter == 'violation_approval') {
      return _rawData.where((item) {
        final notifType = (item['notif_type'] ?? '').toString().toLowerCase();
        final title = (item['title'] ?? '').toString().toLowerCase();
        final cat = (item['category'] ?? '').toString().toLowerCase();
        return notifType == 'permit_violation_approval' ||
            (title.contains('persetujuan') && title.contains('pelanggaran')) ||
            (cat.contains('violation') && cat.contains('approval'));
      }).toList();
    }

    if (_selectedFilter == 'approval') {
      return _rawData.where((item) {
        final cat = (item['category'] ?? '').toString().toLowerCase();
        return cat.contains('approval') || item['is_approval_item'] == true;
      }).toList();
    }

    if (_selectedFilter == 'special_permit') {
      return _rawData.where((item) {
        final cat = (item['category'] ?? '').toString().toLowerCase();
        return cat.contains('special_permit') ||
            item['is_special_permit'] == true;
      }).toList();
    }

    if (_selectedFilter == 'hazard') {
      return _rawData.where((item) {
        final cat = (item['category'] ?? '').toString().toLowerCase();
        final notifType = (item['notif_type'] ?? '').toString().toLowerCase();
        return cat.contains('hazard') ||
            cat.contains('action') ||
            notifType.contains('hazard') ||
            notifType.contains('action');
      }).toList();
    }

    if (_selectedFilter == 'inspection') {
      return _rawData.where((item) {
        final cat = (item['category'] ?? '').toString().toLowerCase();
        final notifType = (item['notif_type'] ?? '').toString().toLowerCase();
        return cat.contains('inspect') ||
            cat.contains('simama') ||
            notifType.contains('inspect');
      }).toList();
    }

    if (_selectedFilter == 'coaching') {
      return _rawData.where((item) {
        final cat = (item['category'] ?? '').toString().toLowerCase();
        return cat.contains('coaching');
      }).toList();
    }

    return _rawData;
  }

  int _countFor(String type) {
    if (type == 'all') return _rawData.length;

    if (type == 'pending_takeup') {
      return _rawData.where((item) => item is Map<String, dynamic> && _isItemPendingTakeUp(item)).length;
    }

    if (type == 'unread') {
      return _rawData.where((item) => item is Map<String, dynamic> && _isItemUnread(item)).length;
    }

    if (type == 'violation_approval') {
      return _rawData.where((item) {
        final notifType = (item['notif_type'] ?? '').toString().toLowerCase();
        final title = (item['title'] ?? '').toString().toLowerCase();
        final cat = (item['category'] ?? '').toString().toLowerCase();
        return notifType == 'permit_violation_approval' ||
            (title.contains('persetujuan') && title.contains('pelanggaran')) ||
            (cat.contains('violation') && cat.contains('approval'));
      }).length;
    }

    if (type == 'approval') {

      return _rawData.where((item) {

        final cat = (item['category'] ?? '').toString().toLowerCase();

        return cat.contains('approval') || item['is_approval_item'] == true;

      }).length;

    }

    if (type == 'special_permit') {

      return _rawData.where((item) {

        final cat = (item['category'] ?? '').toString().toLowerCase();

        return cat.contains('special_permit') ||

            item['is_special_permit'] == true;

      }).length;

    }

    if (type == 'hazard') {

      return _rawData.where((item) {

        final cat = (item['category'] ?? '').toString().toLowerCase();

        final notifType = (item['notif_type'] ?? '').toString().toLowerCase();

        return cat.contains('hazard') ||

            cat.contains('action') ||

            notifType.contains('hazard') ||

            notifType.contains('action');

      }).length;

    }

    if (type == 'inspection') {

      return _rawData.where((item) {

        final cat = (item['category'] ?? '').toString().toLowerCase();

        final notifType = (item['notif_type'] ?? '').toString().toLowerCase();

        return cat.contains('inspect') ||

            cat.contains('simama') ||

            notifType.contains('inspect');

      }).length;

    }

    if (type == 'coaching') {

      return _rawData.where((item) {

        final cat = (item['category'] ?? '').toString().toLowerCase();

        return cat.contains('coaching');

      }).length;

    }

    return 0;

  }



  String _formatDisplayDate(String? rawDate, String? rawTime) {

    if (rawDate == null || rawDate.isEmpty) return rawTime ?? '-';

    try {

      final date = DateTime.parse(rawDate);

      final now = DateTime.now();

      final today = DateTime(now.year, now.month, now.day);

      final itemDate = DateTime(date.year, date.month, date.day);

      final difference = today.difference(itemDate).inDays;



      final timeStr =

          (rawTime != null && rawTime.isNotEmpty) ? ' $rawTime' : '';



      if (difference == 0) {

        return 'Hari ini$timeStr';

      } else if (difference == 1) {

        return 'Kemarin$timeStr';

      } else if (difference < 7) {

        return '$difference hari lalu';

      } else {

        return '${DateFormat('dd MMM yyyy').format(date)}$timeStr';

      }

    } catch (_) {

      return '$rawDate ${rawTime ?? ''}'.trim();

    }

  }



  void _showCoachingDialog(Map<String, dynamic> item) {

    showModalBottomSheet(

      context: context,

      isScrollControlled: true,

      backgroundColor: Colors.transparent,

      builder: (ctx) {

        final title = item['title']?.toString() ?? 'Coaching & Pembinaan';

        final remark = item['remark']?.toString() ?? '';

        final date = item['date']?.toString() ?? '';

        final time = item['time']?.toString() ?? '';

        final formattedDate = _formatDisplayDate(date, time);



        return Container(

          decoration: const BoxDecoration(

            color: Colors.white,

            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),

          ),

          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),

          child: Column(

            mainAxisSize: MainAxisSize.min,

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Center(

                child: Container(

                  width: 40,

                  height: 4,

                  margin: const EdgeInsets.only(bottom: 18),

                  decoration: BoxDecoration(

                    color: Colors.grey.shade300,

                    borderRadius: BorderRadius.circular(2),

                  ),

                ),

              ),

              Row(

                children: [

                  Container(

                    padding: const EdgeInsets.all(10),

                    decoration: BoxDecoration(

                      color: const Color(0xFFF5F3FF),

                      borderRadius: BorderRadius.circular(12),

                    ),

                    child: const Icon(

                      Icons.psychology_outlined,

                      color: Color(0xFF7C3AED),

                      size: 24,

                    ),

                  ),

                  const SizedBox(width: 12),

                  Expanded(

                    child: Column(

                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [

                        Container(

                          padding: const EdgeInsets.symmetric(

                              horizontal: 8, vertical: 2),

                          decoration: BoxDecoration(

                            color: const Color(0xFFEDE9FE),

                            borderRadius: BorderRadius.circular(6),

                          ),

                          child: const Text(

                            'COACHING & PEMBINAAN',

                            style: TextStyle(

                              fontSize: 10,

                              fontWeight: FontWeight.w800,

                              color: Color(0xFF7C3AED),

                              letterSpacing: 0.5,

                            ),

                          ),

                        ),

                        const SizedBox(height: 4),

                        Text(

                          title,

                          style: const TextStyle(

                            fontSize: 15,

                            fontWeight: FontWeight.w700,

                            color: Color(0xFF1E293B),

                          ),

                        ),

                      ],

                    ),

                  ),

                ],

              ),

              const SizedBox(height: 16),

              Container(

                width: double.infinity,

                padding: const EdgeInsets.all(14),

                decoration: BoxDecoration(

                  color: const Color(0xFFF8FAFC),

                  borderRadius: BorderRadius.circular(12),

                  border: Border.all(color: const Color(0xFFE2E8F0)),

                ),

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Row(

                      children: [

                        const Icon(Icons.info_outline,

                            size: 14, color: Color(0xFF64748B)),

                        const SizedBox(width: 6),

                        Text(

                          'Waktu: $formattedDate',

                          style: const TextStyle(

                            fontSize: 12,

                            fontWeight: FontWeight.w500,

                            color: Color(0xFF64748B),

                          ),

                        ),

                      ],

                    ),

                    const SizedBox(height: 10),

                    Text(

                      remark,

                      style: const TextStyle(

                        fontSize: 13.5,

                        fontWeight: FontWeight.w500,

                        color: Color(0xFF334155),

                        height: 1.5,

                      ),

                    ),

                  ],

                ),

              ),

              const SizedBox(height: 14),

              Container(

                padding:

                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),

                decoration: BoxDecoration(

                  color: const Color(0xFFF1F5F9),

                  borderRadius: BorderRadius.circular(8),

                ),

                child: Row(

                  children: [

                    const Icon(Icons.access_time_rounded,

                        size: 14, color: Color(0xFF64748B)),

                    const SizedBox(width: 6),

                    Expanded(

                      child: Text(

                        'Notifikasi pembinaan ini bersifat informasi dari PIC Anda dan akan otomatis hilang dalam 7 hari.',

                        style: TextStyle(

                          fontSize: 11.5,

                          color: Colors.grey.shade700,

                        ),

                      ),

                    ),

                  ],

                ),

              ),

              const SizedBox(height: 20),

              SizedBox(

                width: double.infinity,

                child: ElevatedButton(

                  style: ElevatedButton.styleFrom(

                    backgroundColor: const Color(0xFF7C3AED),

                    foregroundColor: Colors.white,

                    shape: RoundedRectangleBorder(

                      borderRadius: BorderRadius.circular(10),

                    ),

                    padding: const EdgeInsets.symmetric(vertical: 12),

                  ),

                  onPressed: () => Navigator.pop(ctx),

                  child: const Text(

                    'Mengerti',

                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),

                  ),

                ),

              ),

            ],

          ),

        );

      },

    );

  }

  void _showP5mDeviationDialog(Map<String, dynamic> item) {
    Map<String, dynamic> payload = {};
    if (item['payload'] != null) {
      try {
        final p = item['payload'];
        if (p is Map<String, dynamic>) {
          payload = p;
        } else if (p is String && p.isNotEmpty) {
          payload = jsonDecode(p) as Map<String, dynamic>;
        }
      } catch (_) {}
    }

    final title = item['title']?.toString() ?? 'Peringatan Deviasi Kesiapan Kerja (P5M)';
    final message = item['message']?.toString() ?? 'Karyawan terdeteksi deviasi kesiapan kerja / durasi tidur.';
    final empName = payload['nama']?.toString() ?? item['sender_name']?.toString() ?? 'Karyawan';
    final empNik = payload['nik']?.toString() ?? '-';
    final empDept = payload['departemen']?.toString() ?? 'Operasional';
    final area = payload['area']?.toString() ?? '-';
    final lokasi = payload['lokasi']?.toString() ?? '-';
    final durasiTidur = payload['durasiTidur']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFDC2626),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Pemberitahuan Resmi K3 untuk PJA & Atasan',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFFDC2626),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Detail Identitas Karyawan
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_pin_rounded, size: 16, color: Color(0xFF0D9488)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '$empName ($empNik)',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: const Text(
                            'UNFIT / DEVIASI',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '🏢 Departemen : $empDept',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '📍 Area / Lokasi : $area • $lokasi',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                    ),
                    if (durasiTidur.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '⏱️ Durasi Tidur 24h : $durasiTidur (Defisit K3)',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Kotak Pesan Arahan
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFD97706)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        message,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF92400E),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      child: const Text('Tutup', style: TextStyle(color: Color(0xFF475569))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const HistoryPage(
                              Module.p5m,
                              History.summary,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.list_alt_rounded, size: 18),
                      label: const Text('Buka Riwayat P5M'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _openDetail(Map<String, dynamic> item) {

    final cat = (item['category'] ?? '').toString().toLowerCase();

    final isCoaching = cat.contains('coaching') ||

        (item['title'] ?? '').toString().toLowerCase().contains('coaching') ||

        (item['title'] ?? '').toString().toLowerCase().contains('pembinaan') ||

        (item['remark'] ?? '').toString().toLowerCase().contains('coaching') ||

        (item['remark'] ?? '').toString().toLowerCase().contains('pembinaan');



    final bool wasUnread = item['is_read'] != true;
    item['is_read'] = true;

    final notifId = item['id'] as int? ?? 0;
    if (notifId > 0) {
      _db.updateLocalNotificationRead(notifId, true);
      if (item['is_server_notif'] == true) {
        _api.markNotificationRead(notifId);
      }
    }

    if (wasUnread) {
      final unread = _calcUnreadCount(_rawData);
      PreferenceService.setNotif(unread);
      NotificationService.syncLauncherBadge(unread);
      if (mounted) setState(() {});
    }

    if (item['is_server_notif'] == true) {



      // Jika Coaching, tampilkan detail modal informasi

      if (isCoaching) {

        _showCoachingDialog(item);

        return;

      }



      final url = (item['url'] ?? '').toString().toLowerCase();

      final notifType = (item['notif_type'] ?? '').toString().toLowerCase();

      final title = (item['title'] ?? '').toString().toLowerCase();



      // Notifikasi Deviasi Kesiapan Kerja / Fatigue P5M (PJA & Atasan)

      if (notifType == 'p5m_deviation' ||

          title.contains('deviasi kesiapan kerja') ||

          (title.contains('tidak siap bekerja') && title.contains('p5m')) ||

          (cat == 'urgent' && title.contains('deviasi'))) {

        _showP5mDeviationDialog(item);

        return;

      }



      // 1. Notifikasi Persetujuan Pelanggaran K3 (PJA Approval)

      if (notifType == 'permit_violation_approval' ||

          title.contains('persetujuan pelanggaran') ||

          url.contains('/permit/violationapproval') ||

          (cat.contains('violation') && cat.contains('approval')) ||

          (cat.contains('approval') && title.contains('pelanggaran'))) {

        Navigator.push(

          context,

          MaterialPageRoute(

            builder: (_) => const ViolationQueuePage(initialIndex: 1),

          ),

        ).then((_) => _getData());

        return;

      }

      // 1b. Notifikasi Persetujuan Re-Induksi & Roster (Pengawas Approval)
      if (notifType == 'reinduksi_approval' ||
          title.contains('persetujuan re-induksi') ||
          (title.contains('re-induksi') && title.contains('persetujuan')) ||
          url.contains('/reinduksi-approval')) {
        int? reinduksiId;
        try {
          if (item['payload'] != null) {
            final pStr = item['payload'].toString();
            final pJson = jsonDecode(pStr);
            reinduksiId = int.tryParse('${pJson['reinduksiId'] ?? pJson['id']}');
          }
        } catch (_) {}

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReinductionApprovalPage(reinduksiId: reinduksiId),
          ),
        ).then((_) => _getData());
        return;
      }

      // 1c. Notifikasi Status Re-Induksi & Roster Karyawan
      if (notifType.startsWith('reinduksi') ||
          notifType.startsWith('roster_reinduksi') ||
          title.contains('re-induksi') ||
          url.contains('/roster')) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const RosterSettingsPage(),
          ),
        ).then((_) => _getData());
        return;
      }



      // 2. Notifikasi Status / Catatan Pelanggaran K3

      if (notifType == 'permit_violation_status' ||

          notifType == 'permit_violation' ||

          url.contains('/permit/violation') ||

          title.contains('pelanggaran')) {

        Navigator.push(

          context,

          MaterialPageRoute(

            builder: (_) => const ViolationQueuePage(initialIndex: 0),

          ),

        ).then((_) => _getData());

        return;

      }



      if (item['is_approval_item'] == true ||

          cat.contains('approval') ||

          url.contains('approval')) {

        Navigator.push(

          context,

          MaterialPageRoute(builder: (_) => const ApprovalCenterPage()),

        ).then((_) => _getData());

        return;

      }



      if (item['is_special_permit'] == true ||

          cat.contains('special_permit') ||

          url.contains('special_permit') ||

          notifType.contains('special_permit') ||

          (item['payload'] ?? '').toString().contains('special_permit')) {

        if (item['raw_permit'] is Map<String, dynamic>) {

          Navigator.push(

            context,

            MaterialPageRoute(

              builder: (_) => SpecialPermitFollowupPage(

                  permit: item['raw_permit'] as Map<String, dynamic>),

            ),

          ).then((_) => _getData());

          return;

        }

        final permitId = item['payload']?.toString();

        if (permitId != null && permitId.isNotEmpty) {

          _api.getSpecialPermitDetail(permitId).then((res) {

            res.fold(

              (_) => Navigator.push(

                      context,

                      MaterialPageRoute(

                          builder: (_) => const SpecialPermitListPage()))

                  .then((_) => _getData()),

              (detailData) {

                final p = detailData['data'] as Map<String, dynamic>?;

                if (p != null) {

                  Navigator.push(

                          context,

                          MaterialPageRoute(

                              builder: (_) =>

                                  SpecialPermitFollowupPage(permit: p)))

                      .then((_) => _getData());

                } else {

                  Navigator.push(

                          context,

                          MaterialPageRoute(

                              builder: (_) => const SpecialPermitListPage()))

                      .then((_) => _getData());

                }

              },

            );

          });

          return;

        }

        Navigator.push(

          context,

          MaterialPageRoute(builder: (_) => const SpecialPermitListPage()),

        ).then((_) => _getData());

        return;

      }



      // Jika Notifikasi Roster / Periode Tugas, buka halaman Pengaturan Roster

      if (cat.contains('roster') ||

          url.contains('roster') ||

          notifType.contains('roster')) {

        Navigator.push(

          context,

          MaterialPageRoute(builder: (_) => const RosterSettingsPage()),

        ).then((_) => _getData());

        return;

      }



      if (cat.contains('hazard') || url.contains('hazard')) {

        HazardHubTab targetTab = HazardHubTab.action;

        final t = (item['notif_type'] ?? '').toString().toLowerCase();

        if (t.contains('completed') || t.contains('closed')) {

          targetTab = HazardHubTab.summary;

        } else if (t.contains('takeup') ||

            t.contains('progress') ||

            t.contains('info')) {

          targetTab = HazardHubTab.monitoring;

        } else {

          targetTab = HazardHubTab.action;

        }

        Navigator.push(

          context,

          MaterialPageRoute(

              builder: (_) => HazardHubPage(initialTab: targetTab)),

        ).then((_) => _getData());

        return;

      }



      if (cat.contains('inspect') ||

          url.contains('inspect') ||

          cat.contains('simama')) {

        Navigator.push(

          context,

          MaterialPageRoute(

              builder: (_) => const InspectionHubPage(

                  initialTab: InspectionHubTab.pjaArea)),

        ).then((_) => _getData());

        return;

      }



      if (cat.contains('action') ||

          url.contains('action') ||

          notifType.contains('action')) {

        Navigator.push(

          context,

          MaterialPageRoute(builder: (_) => const ActionTrackerPage()),

        ).then((_) => _getData());

        return;

      }



      if (!cat.contains('hazard') &&

          !cat.contains('inspect') &&

          !cat.contains('simama') &&

          !cat.contains('action') &&

          !cat.contains('approval') &&

          !cat.contains('special_permit') &&

          !url.contains('hazard') &&

          !url.contains('inspect') &&

          !url.contains('action') &&

          !url.contains('approval') &&

          !url.contains('special_permit')) {

        _showGeneralNotificationDialog(item);

        return;

      }

    } else if (isCoaching) {

      _showCoachingDialog(item);

      return;

    }



    Module module;

    switch (cat) {

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

          item,

        ),

      ),

    ).then((_) => _getData());

  }



  @override

  Widget build(BuildContext context) {

    final filtered = _filteredData;



    return Scaffold(

      backgroundColor: const Color(0xFFF7F9FC),

      appBar: AppBar(

        elevation: 0,

        backgroundColor: Colors.white,

        surfaceTintColor: Colors.transparent,

        title: Row(

          children: [

            Container(

              padding: const EdgeInsets.all(7),

              decoration: BoxDecoration(

                color: const Color(0xFFEAF2FF),

                borderRadius: BorderRadius.circular(12),

              ),

              child: const Icon(

                Icons.notifications_active_rounded,

                color: Color(0xFF2563EB),

                size: 20,

              ),

            ),

            const SizedBox(width: 12),

            const Expanded(

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                mainAxisSize: MainAxisSize.min,

                children: [

                  Text(

                    'Aktivitas',

                    maxLines: 1,

                    overflow: TextOverflow.ellipsis,

                    style: TextStyle(

                      fontSize: 16,

                      fontWeight: FontWeight.w800,

                      color: Color(0xFF0F172A),

                    ),

                  ),

                  Text(

                    'Pemberitahuan & tindak lanjut',

                    maxLines: 1,

                    overflow: TextOverflow.ellipsis,

                    style: TextStyle(

                      fontSize: 11,

                      fontWeight: FontWeight.w400,

                      color: Color(0xFF64748B),

                    ),

                  ),

                ],

              ),

            ),

          ],

        ),

        actions: [

          // Status Pill: Mode Offline vs Online

          Container(

            margin: const EdgeInsets.symmetric(vertical: 12),

            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),

            decoration: BoxDecoration(

              color: _isOfflineMode

                  ? const Color(0xFFFFF7E8)

                  : const Color(0xFFF0FDF4),

              borderRadius: BorderRadius.circular(20),

              border: Border.all(

                color: _isOfflineMode

                    ? const Color(0xFFF59E0B).withValues(alpha: 0.5)

                    : const Color(0xFF34A853).withValues(alpha: 0.3),

              ),

            ),

            child: Row(

              mainAxisSize: MainAxisSize.min,

              children: [

                Icon(

                  _isOfflineMode

                      ? Icons.cloud_off_rounded

                      : Icons.cloud_done_rounded,

                  size: 13,

                  color: _isOfflineMode

                      ? const Color(0xFFD97706)

                      : const Color(0xFF1E8E3E),

                ),

                const SizedBox(width: 4),

                Text(

                  _isOfflineMode ? 'Offline' : 'Online',

                  style: TextStyle(

                    fontSize: 10.5,

                    fontWeight: FontWeight.w700,

                    color: _isOfflineMode

                        ? const Color(0xFFB45309)

                        : const Color(0xFF1E8E3E),

                  ),

                ),

              ],

            ),

          ),

          IconButton(

            tooltip: 'Unduh Notifikasi untuk Mode Offline',

            icon: _isSyncing

                ? const SizedBox(

                    width: 18,

                    height: 18,

                    child: CircularProgressIndicator(

                      strokeWidth: 2,

                      color: Color(0xFF009688),

                    ),

                  )

                : const Icon(

                    Icons.sync_rounded,

                    color: Color(0xFF334155),

                  ),

            onPressed: () {
              _syncOnlineData(isManual: true);
              _fetchApiActions();
            },
          ),
          IconButton(
            tooltip: 'Tandai Semua Dibaca',
            icon: const Icon(
              Icons.done_all_rounded,
              color: Color(0xFF2563EB),
              size: 21,
            ),
            onPressed: _markAllAsRead,
          ),
          const SizedBox(width: 6),

        ],

        bottom: PreferredSize(

          preferredSize: const Size.fromHeight(54),

          child: Container(

            color: Colors.white,

            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),

            child: SingleChildScrollView(

              scrollDirection: Axis.horizontal,

              physics: const BouncingScrollPhysics(),

              child: Row(
                children: [
                  _buildFilterChip('all', 'Semua', _countFor('all')),
                  if (_countFor('pending_takeup') > 0) ...[
                    const SizedBox(width: 8),
                    _buildFilterChip('pending_takeup', 'Perlu Take Up',
                        _countFor('pending_takeup')),
                  ],
                  if (_countFor('unread') > 0) ...[
                    const SizedBox(width: 8),
                    _buildFilterChip('unread', 'Belum Dibaca',
                        _countFor('unread')),
                  ],
                  if (_countFor('violation_approval') > 0) ...[
                    const SizedBox(width: 8),
                    _buildFilterChip('violation_approval', 'Persetujuan PJA', _countFor('violation_approval')),
                  ],

                  const SizedBox(width: 8),

                  _buildFilterChip(

                      'approval', 'Approval Bima', _countFor('approval')),

                  const SizedBox(width: 8),

                  _buildFilterChip('special_permit', 'Special Permit',

                      _countFor('special_permit')),

                  const SizedBox(width: 8),

                  _buildFilterChip('hazard', 'Hazard', _countFor('hazard')),

                  const SizedBox(width: 8),

                  _buildFilterChip(

                      'inspection', 'Inspeksi', _countFor('inspection')),

                  const SizedBox(width: 8),

                  _buildFilterChip(

                      'coaching', 'Coaching', _countFor('coaching')),

                ],

              ),

            ),

          ),

        ),

      ),

      body: RefreshIndicator(

        color: const Color(0xFF009688),

        onRefresh: () async {

          await _syncOnlineData(isManual: true);

          _fetchApiActions();

        },

        child: Column(

          children: [

            _buildActivitySummary(filtered.length),

            // Banner Alert Khusus PJA jika ada pelanggaran yang belum diapprove

            Builder(

              builder: (context) {

                final pendingPjaViolations = _rawData.where((item) {

                  final notifType = (item['notif_type'] ?? '').toString().toLowerCase();

                  final title = (item['title'] ?? '').toString().toLowerCase();

                  final isActioned = item['is_actioned'] == true;

                  return !isActioned &&

                      (notifType == 'permit_violation_approval' ||

                          (title.contains('persetujuan') && title.contains('pelanggaran')));

                }).toList();



                if (pendingPjaViolations.isEmpty) return const SizedBox.shrink();



                return Container(

                  margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),

                  padding: const EdgeInsets.all(14),

                  decoration: BoxDecoration(

                    color: const Color(0xFFFEF2F2),

                    borderRadius: BorderRadius.circular(16),

                    border: Border.all(color: const Color(0xFFFECACA)),

                    boxShadow: [

                      BoxShadow(

                        color: const Color(0xFFDC2626).withValues(alpha: 0.08),

                        blurRadius: 10,

                        offset: const Offset(0, 3),

                      ),

                    ],

                  ),

                  child: Row(

                    children: [

                      Container(

                        padding: const EdgeInsets.all(9),

                        decoration: BoxDecoration(

                          color: const Color(0xFFDC2626).withValues(alpha: 0.12),

                          borderRadius: BorderRadius.circular(12),

                        ),

                        child: const Icon(Icons.gavel_rounded, color: Color(0xFFDC2626), size: 22),

                      ),

                      const SizedBox(width: 12),

                      Expanded(

                        child: Column(

                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [

                            Text(

                              '${pendingPjaViolations.length} Pelanggaran Menunggu Persetujuan Anda',

                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF991B1B)),

                            ),

                            const SizedBox(height: 2),

                            const Text(

                              'Anda ditunjuk sebagai PJA. Ketuk untuk memeriksa dan menyetujui.',

                              style: TextStyle(fontSize: 11, color: Color(0xFFB91C1C)),

                            ),

                          ],

                        ),

                      ),

                      const SizedBox(width: 8),

                      ElevatedButton(

                        onPressed: () {

                          Navigator.push(

                            context,

                            MaterialPageRoute(

                              builder: (_) => const ViolationQueuePage(initialIndex: 1),

                            ),

                          ).then((_) => _getData());

                        },

                        style: ElevatedButton.styleFrom(

                          backgroundColor: const Color(0xFFDC2626),

                          foregroundColor: Colors.white,

                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),

                          minimumSize: Size.zero,

                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,

                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),

                          elevation: 1,

                        ),

                        child: const Text('Review', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),

                      ),

                    ],

                  ),

                );

              },

            ),

            if (_isOfflineMode)

              Container(

                width: double.infinity,

                margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),

                padding:

                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),

                decoration: BoxDecoration(

                  color: const Color(0xFFFFFBEB),

                  borderRadius: BorderRadius.circular(10),

                  border: Border.all(color: const Color(0xFFFCD34D)),

                ),

                child: Row(

                  children: [

                    const Icon(Icons.offline_bolt_rounded,

                        size: 16, color: Color(0xFFD97706)),

                    const SizedBox(width: 8),

                    Expanded(

                      child: Text(

                        'Mode Offline Aktif • Menampilkan ${_rawData.length} notifikasi tersimpan di HP${_lastSyncTime != null ? ' (Sinkron ${DateFormat('HH:mm').format(_lastSyncTime!)})' : ''}',

                        style: const TextStyle(

                          fontSize: 11.5,

                          fontWeight: FontWeight.w600,

                          color: Color(0xFF92400E),

                        ),

                      ),

                    ),

                    InkWell(

                      onTap: () => _syncOnlineData(isManual: true),

                      child: const Text(

                        'Sinkron',

                        style: TextStyle(

                          fontSize: 11.5,

                          fontWeight: FontWeight.bold,

                          color: Color(0xFFB45309),

                          decoration: TextDecoration.underline,

                        ),

                      ),

                    ),

                  ],

                ),

              ),

            Expanded(
              child: _isLoading && _rawData.isEmpty
                  ? _buildLoadingSkeleton()
                  : (filtered.isNotEmpty
                      ? ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final item = filtered[index] as Map<String, dynamic>;
                            return _buildNotificationCard(item);
                          },
                        )
                      : _buildEmptyState()),
            ),

          ],

        ),

      ),

    );

  }



  Widget _buildFilterChip(String key, String label, int count) {

    final isSelected = _selectedFilter == key;

    return GestureDetector(

      onTap: () {

        setState(() => _selectedFilter = key);

      },

      child: AnimatedContainer(

        duration: const Duration(milliseconds: 200),

        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),

        decoration: BoxDecoration(

          color: isSelected ? const Color(0xFF0F3D6E) : Colors.white,

          borderRadius: BorderRadius.circular(18),

          border: Border.all(

            color:

                isSelected ? const Color(0xFF0F3D6E) : const Color(0xFFE2E8F0),

            width: 1,

          ),

        ),

        child: Row(

          mainAxisSize: MainAxisSize.min,

          children: [

            Text(

              label,

              style: TextStyle(

                fontSize: 12,

                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,

                color: isSelected ? Colors.white : const Color(0xFF475569),

              ),

            ),

            if (count > 0) ...[

              const SizedBox(width: 6),

              Container(

                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),

                decoration: BoxDecoration(

                  color: isSelected

                      ? Colors.white.withValues(alpha: 0.25)

                      : const Color(0xFFCBD5E1),

                  borderRadius: BorderRadius.circular(10),

                ),

                child: Text(

                  count.toString(),

                  style: TextStyle(

                    fontSize: 10,

                    fontWeight: FontWeight.w700,

                    color: isSelected ? Colors.white : const Color(0xFF1E293B),

                  ),

                ),

              ),

            ],

          ],

        ),

      ),

    );

  }



  Widget _buildActivitySummary(int visibleCount) {
    final pendingTakeUpCount = _rawData
        .where((item) => item is Map<String, dynamic> && _isItemPendingTakeUp(item))
        .length;
    final unreadCount = _rawData
        .where((item) => item is Map<String, dynamic> && _isItemUnread(item))
        .length;
    final urgentCount = _rawData.where((item) {
      if (item is! Map) return false;
      final priority = (item['priority'] ?? '').toString().toLowerCase();
      return priority == 'urgent' ||
          item['is_approval_item'] == true ||
          item['is_special_permit'] == true;
    }).length;

    final hasActionRequired = pendingTakeUpCount > 0 || urgentCount > 0;

    final syncLabel = _isOfflineMode
        ? 'Tersimpan di perangkat'
        : (_lastSyncTime == null
            ? 'Memperbarui aktivitas'
            : 'Diperbarui ${DateFormat('HH:mm').format(_lastSyncTime!)}');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EDF4)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A0F172A), blurRadius: 14, offset: Offset(0, 5)),
        ],
      ),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: hasActionRequired
                ? const Color(0xFFFFF7ED)
                : const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasActionRequired
                  ? const Color(0xFFFDBA74)
                  : const Color(0xFFBFDBFE),
              width: 1,
            ),
          ),
          child: Icon(
            hasActionRequired
                ? Icons.pending_actions_rounded
                : Icons.notifications_none_rounded,
            color: hasActionRequired
                ? const Color(0xFFEA580C)
                : const Color(0xFF2563EB),
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                visibleCount == 0
                    ? 'Tidak ada aktivitas baru'
                    : '$visibleCount aktivitas untuk Anda',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                syncLabel,
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pendingTakeUpCount > 0)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFED7AA), width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEA580C),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$pendingTakeUpCount perlu take up',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFC2410C),
                      ),
                    ),
                  ],
                ),
              ),
            if (unreadCount > 0 && _selectedFilter != 'unread')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE), width: 0.8),
                ),
                child: Text(
                  '$unreadCount belum dibaca',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ),
          ],
        ),
      ]),
    );
  }



  Widget _buildNotifLogo(String? logo, Color fallbackColor) {

    if (logo == null || logo.trim().isEmpty) return const SizedBox.shrink();

    final clean = logo.trim();

    if (clean.startsWith('http://') || clean.startsWith('https://')) {

      return Container(

        width: 32,

        height: 32,

        margin: const EdgeInsets.only(right: 8),

        decoration: BoxDecoration(

          color: Colors.white,

          borderRadius: BorderRadius.circular(8),

          border: Border.all(color: const Color(0xFFE2E8F0)),

          boxShadow: [

            BoxShadow(

              color: Colors.black.withValues(alpha: 0.04),

              blurRadius: 4,

            ),

          ],

        ),

        child: ClipRRect(

          borderRadius: BorderRadius.circular(7),

          child: Image.network(

            clean,

            fit: BoxFit.cover,

            errorBuilder: (_, __, ___) => Icon(

                Icons.notifications_active_rounded,

                size: 16,

                color: fallbackColor),

          ),

        ),

      );

    } else if (clean.startsWith('/') || clean.startsWith('uploads/')) {

      final fullUrl = clean.startsWith('/')

          ? '${_api.baseUrl}$clean'

          : '${_api.baseUrl}/$clean';

      return Container(

        width: 32,

        height: 32,

        margin: const EdgeInsets.only(right: 8),

        decoration: BoxDecoration(

          color: Colors.white,

          borderRadius: BorderRadius.circular(8),

          border: Border.all(color: const Color(0xFFE2E8F0)),

          boxShadow: [

            BoxShadow(

              color: Colors.black.withValues(alpha: 0.04),

              blurRadius: 4,

            ),

          ],

        ),

        child: ClipRRect(

          borderRadius: BorderRadius.circular(7),

          child: Image.network(

            fullUrl,

            fit: BoxFit.cover,

            errorBuilder: (_, __, ___) => Icon(

                Icons.notifications_active_rounded,

                size: 16,

                color: fallbackColor),

          ),

        ),

      );

    } else {

      IconData iconData = Icons.notifications_active_rounded;

      Color iconColor = fallbackColor;

      if (clean.contains('violation')) {

        iconData = Icons.gavel_rounded;

        iconColor = const Color(0xFFDC2626);

      } else if (clean.contains('movement') || clean.contains('gate')) {

        iconData = Icons.meeting_room_rounded;

        iconColor = const Color(0xFF0284C7);

      } else if (clean.contains('hazard')) {

        iconData = Icons.warning_amber_rounded;

        iconColor = const Color(0xFFEA580C);

      } else if (clean.contains('inspect') || clean.contains('simama')) {

        iconData = Icons.fact_check_outlined;

        iconColor = const Color(0xFF0284C7);

      } else if (clean.contains('p5m')) {

        iconData = Icons.groups_rounded;

        iconColor = const Color(0xFF0D9488);

      } else if (clean.contains('p2h')) {

        iconData = Icons.car_repair_rounded;

        iconColor = const Color(0xFF0284C7);

      } else if (clean.contains('trophy') || clean.contains('reward')) {

        iconData = Icons.emoji_events_rounded;

        iconColor = const Color(0xFFEAB308);

      } else if (clean.contains('broadcast') ||

          clean.contains('announcement') ||

          clean.contains('info')) {

        iconData = Icons.campaign_rounded;

        iconColor = const Color(0xFF6366F1);

      }



      return Container(

        width: 32,

        height: 32,

        margin: const EdgeInsets.only(right: 8),

        decoration: BoxDecoration(

          color: iconColor.withValues(alpha: 0.12),

          borderRadius: BorderRadius.circular(8),

        ),

        child: Icon(iconData, size: 16, color: iconColor),

      );

    }

  }



  void _showGeneralNotificationDialog(Map<String, dynamic> item) {

    final title = item['title']?.toString() ?? 'Pemberitahuan';

    final message = item['remark']?.toString() ?? '';

    final sender = item['sender_name']?.toString() ?? '';

    final priority = item['priority']?.toString().toLowerCase() ?? 'normal';

    final url = item['url']?.toString() ?? '';

    final actionText = item['action_text']?.toString() ?? 'Buka Tautan';



    final isUrgent = priority == 'urgent';

    final accent = isUrgent ? const Color(0xFFE11D48) : const Color(0xFF2563EB);

    final background =

        isUrgent ? const Color(0xFFFFF1F2) : const Color(0xFFEFF6FF);

    showModalBottomSheet<void>(

      context: context,

      isScrollControlled: true,

      backgroundColor: Colors.transparent,

      builder: (ctx) => SafeArea(

        top: false,

        child: Container(

          decoration: const BoxDecoration(

            color: Colors.white,

            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),

          ),

          padding: EdgeInsets.fromLTRB(

              20, 12, 20, MediaQuery.of(ctx).padding.bottom + 20),

          child: Column(

              mainAxisSize: MainAxisSize.min,

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Center(

                    child: Container(

                        width: 42,

                        height: 4,

                        decoration: BoxDecoration(

                            color: const Color(0xFFE2E8F0),

                            borderRadius: BorderRadius.circular(8)))),

                const SizedBox(height: 20),

                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

                  Container(

                    width: 48,

                    height: 48,

                    decoration: BoxDecoration(

                        color: background,

                        borderRadius: BorderRadius.circular(15)),

                    child: Icon(

                        isUrgent

                            ? Icons.priority_high_rounded

                            : Icons.notifications_outlined,

                        color: accent,

                        size: 25),

                  ),

                  const SizedBox(width: 12),

                  Expanded(

                      child: Column(

                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [

                        Row(children: [

                          Text(isUrgent ? 'PERLU ATENSI' : 'PEMBERITAHUAN',

                              style: TextStyle(

                                  fontSize: 10,

                                  letterSpacing: .8,

                                  fontWeight: FontWeight.w900,

                                  color: accent)),

                          if (isUrgent) ...[

                            const SizedBox(width: 7),

                            Container(

                                width: 6,

                                height: 6,

                                decoration: BoxDecoration(

                                    color: accent, shape: BoxShape.circle))

                          ],

                        ]),

                        const SizedBox(height: 4),

                        Text(title,

                            maxLines: 2,

                            overflow: TextOverflow.ellipsis,

                            style: const TextStyle(

                                fontSize: 19,

                                height: 1.15,

                                fontWeight: FontWeight.w900,

                                color: Color(0xFF0F172A))),

                      ])),

                  IconButton(

                      onPressed: () => Navigator.pop(ctx),

                      icon: const Icon(Icons.close_rounded,

                          color: Color(0xFF64748B)),

                      tooltip: 'Tutup'),

                ]),

                if (sender.isNotEmpty) ...[

                  const SizedBox(height: 16),

                  Container(

                    width: double.infinity,

                    padding:

                        const EdgeInsets.symmetric(horizontal: 11, vertical: 9),

                    decoration: BoxDecoration(

                        color: const Color(0xFFF8FAFC),

                        borderRadius: BorderRadius.circular(11)),

                    child: Row(children: [

                      Icon(Icons.person_outline_rounded,

                          size: 16, color: accent),

                      const SizedBox(width: 7),

                      Expanded(

                        child: Text(sender,

                            overflow: TextOverflow.ellipsis,

                            style: const TextStyle(

                                fontSize: 12,

                                fontWeight: FontWeight.w700,

                                color: Color(0xFF334155))),

                      ),

                    ]),

                  ),

                ],

                const SizedBox(height: 18),

                Text(message,

                    style: const TextStyle(

                        fontSize: 14, height: 1.55, color: Color(0xFF334155))),

                const SizedBox(height: 24),

                Row(children: [

                  Expanded(

                      child: OutlinedButton(

                          onPressed: () => Navigator.pop(ctx),

                          style: OutlinedButton.styleFrom(

                              foregroundColor: const Color(0xFF475569),

                              side: const BorderSide(color: Color(0xFFCBD5E1)),

                              padding: const EdgeInsets.symmetric(vertical: 14),

                              shape: RoundedRectangleBorder(

                                  borderRadius: BorderRadius.circular(13))),

                          child: const Text('Tutup',

                              style: TextStyle(fontWeight: FontWeight.w800)))),

                  if (url.isNotEmpty) ...[

                    const SizedBox(width: 10),

                    Expanded(

                        child: ElevatedButton(

                            onPressed: () {

                              Navigator.pop(ctx);

                              NotificationService.navigateToUrl(url);

                            },

                            style: ElevatedButton.styleFrom(

                                backgroundColor: accent,

                                foregroundColor: Colors.white,

                                elevation: 0,

                                padding:

                                    const EdgeInsets.symmetric(vertical: 14),

                                shape: RoundedRectangleBorder(

                                    borderRadius: BorderRadius.circular(13))),

                            child: Text(actionText,

                                overflow: TextOverflow.ellipsis,

                                style: const TextStyle(

                                    fontWeight: FontWeight.w800)))),

                  ],

                ]),

              ]),

        ),

      ),

    );

  }



  Widget _buildNotificationCard(Map<String, dynamic> item) {

    // Satu renderer ringkas untuk semua sumber notifikasi. Ini mencegah kartu

    // lama yang terlalu bercabang gagal terpaint di beberapa perangkat Android.

    return _buildProfessionalNotificationCard(item);
  }

  Widget _buildProfessionalNotificationCard(Map<String, dynamic> item) {
    final category = (item['category'] ?? '').toString().toLowerCase();
    final title = titleCase(item['title']?.toString() ?? 'Pemberitahuan');
    final message = item['remark']?.toString() ?? '';
    final sender = item['sender_name']?.toString() ?? '';
    final time =
        _formatDisplayDate(item['date']?.toString(), item['time']?.toString());
    final urgent =
        (item['priority'] ?? '').toString().toLowerCase() == 'urgent' ||
            item['is_special_permit'] == true;
    final approval =
        item['is_approval_item'] == true || category.contains('approval');
    final hazard = category.contains('hazard') || category.contains('action');
    final inspection =
        category.contains('inspect') || category.contains('simama');

    // Evaluasi 3 status utama:
    // 1. Belum di-take up / Menunggu tindak lanjut
    // 2. Belum dibaca (informasi/umum)
    // 3. Sudah dibaca & sudah ditindaklanjuti / selesai
    final isPendingTakeUp = _isItemPendingTakeUp(item);
    final isUnread = _isItemUnread(item);
    final status = (item['status'] as num?)?.toInt() ?? 0;

    // Warna tema kategori
    final Color categoryColor = urgent
        ? const Color(0xFFE11D48)
        : approval
            ? const Color(0xFF0F766E)
            : hazard
                ? const Color(0xFFEA580C)
                : inspection
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF6366F1);

    // 1. Background Card Berbeda Warna:
    // - Belum di-take up: Soft Warm Coral/Amber tint (0xFFFFF7ED) / (0xFFFEF2F2 jika urgent)
    // - Belum dibaca: Soft Ice Sky Blue tint (0xFFF0F7FF)
    // - Sudah dibaca & selesai: Clean Crisp White (Colors.white)
    final Color cardBgColor = isPendingTakeUp
        ? (urgent ? const Color(0xFFFEF2F2) : const Color(0xFFFFF7ED))
        : (isUnread ? const Color(0xFFF0F7FF) : Colors.white);

    // 2. Border Card Berbeda:
    final Border cardBorder = Border.all(
      color: isPendingTakeUp
          ? (urgent ? const Color(0xFFFCA5A5) : const Color(0xFFFDBA74))
          : (isUnread ? const Color(0xFFBAE6FD) : const Color(0xFFE2E8F0)),
      width: isPendingTakeUp ? 1.5 : (isUnread ? 1.3 : 1.0),
    );

    // 3. Left Accent Strip Line:
    final Color stripColor = isPendingTakeUp
        ? (urgent ? const Color(0xFFDC2626) : const Color(0xFFEA580C))
        : (isUnread ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1));

    // 4. Box Shadow:
    final List<BoxShadow> cardShadow = [
      BoxShadow(
        color: isPendingTakeUp
            ? (urgent
                ? const Color(0xFFDC2626).withValues(alpha: 0.12)
                : const Color(0xFFEA580C).withValues(alpha: 0.12))
            : (isUnread
                ? const Color(0xFF2563EB).withValues(alpha: 0.08)
                : const Color(0x060F172A)),
        blurRadius: isPendingTakeUp ? 12 : 8,
        offset: const Offset(0, 3),
      ),
    ];

    // Icon
    final IconData icon = isPendingTakeUp
        ? (urgent
            ? Icons.priority_high_rounded
            : (approval
                ? Icons.gavel_rounded
                : Icons.assignment_late_rounded))
        : (urgent
            ? Icons.priority_high_rounded
            : approval
                ? Icons.approval_outlined
                : hazard
                    ? Icons.warning_amber_rounded
                    : inspection
                        ? Icons.fact_check_outlined
                        : Icons.notifications_none_rounded);

    final Color iconColor = isPendingTakeUp
        ? (urgent ? const Color(0xFFDC2626) : const Color(0xFFEA580C))
        : (isUnread ? categoryColor : const Color(0xFF64748B));

    final String label = urgent
        ? 'PERLU ATENSI'
        : approval
            ? 'PERSETUJUAN'
            : hazard
                ? 'HAZARD'
                : inspection
                    ? 'INSPEKSI'
                    : 'INFORMASI';

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: cardBorder,
        boxShadow: cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Accent Line with 3 distinct indicator states
              Container(width: isPendingTakeUp ? 5.5 : 4.5, color: stripColor),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _openDetail(item),
                    child: Padding(
                      padding: const EdgeInsets.all(13),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: iconColor.withValues(alpha: .12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(icon, size: 17, color: iconColor),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: categoryColor.withValues(alpha: .09),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: categoryColor.withValues(alpha: 0.25),
                                      width: 0.8),
                                ),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    letterSpacing: .3,
                                    fontWeight: FontWeight.w900,
                                    color: categoryColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Status Indicator Chip: Belum di-take up vs Belum dibaca vs Selesai
                              if (isPendingTakeUp)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: urgent
                                        ? const Color(0xFFFEE2E2)
                                        : const Color(0xFFFFEDD5),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: urgent
                                          ? const Color(0xFFFCA5A5)
                                          : const Color(0xFFFDBA74),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: urgent
                                              ? const Color(0xFFDC2626)
                                              : const Color(0xFFEA580C),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        approval
                                            ? 'PERLU PERSETUJUAN'
                                            : (urgent
                                                ? 'PERLU ATENSI'
                                                : 'BELUM DI-TAKE UP'),
                                        style: TextStyle(
                                          fontSize: 9,
                                          letterSpacing: .2,
                                          fontWeight: FontWeight.w900,
                                          color: urgent
                                              ? const Color(0xFFB91C1C)
                                              : const Color(0xFFC2410C),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else if (isUnread)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDBEAFE),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: const Color(0xFF93C5FD),
                                        width: 0.8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF2563EB),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'BELUM DIBACA',
                                        style: TextStyle(
                                          fontSize: 9,
                                          letterSpacing: .2,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF1D4ED8),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.check_rounded,
                                          size: 10, color: Color(0xFF64748B)),
                                      const SizedBox(width: 3),
                                      Text(
                                        status >= 1 ? 'SELESAI' : 'SUDAH DIBACA',
                                        style: const TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const Spacer(),
                              Text(
                                time,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: (isPendingTakeUp || isUnread)
                                      ? const Color(0xFF334155)
                                      : const Color(0xFF94A3B8),
                                  fontWeight: (isPendingTakeUp || isUnread)
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.25,
                              fontWeight: isPendingTakeUp
                                  ? FontWeight.w900
                                  : (isUnread
                                      ? FontWeight.w800
                                      : FontWeight.w600),
                              color: isPendingTakeUp
                                  ? const Color(0xFF0F172A)
                                  : (isUnread
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFF475569)),
                            ),
                          ),
                          if (message.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                height: 1.35,
                                color: (isPendingTakeUp || isUnread)
                                    ? const Color(0xFF475569)
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                          const SizedBox(height: 9),
                          Row(
                            children: [
                              if (sender.isNotEmpty) ...[
                                Icon(Icons.person_outline_rounded,
                                    size: 13, color: iconColor),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    sender,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: iconColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ] else
                                const Spacer(),
                              // Action Button: High contrast filled button if pending take-up
                              if (isPendingTakeUp)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: urgent
                                        ? const Color(0xFFDC2626)
                                        : (approval
                                            ? const Color(0xFF0F766E)
                                            : const Color(0xFFEA580C)),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (urgent
                                                ? const Color(0xFFDC2626)
                                                : const Color(0xFFEA580C))
                                            .withValues(alpha: 0.28),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        approval
                                            ? 'Review & Setujui'
                                            : (urgent
                                                ? 'Tindak Lanjut'
                                                : (title.toLowerCase().contains('pja') ||
                                                        message.toLowerCase().contains('take up')
                                                    ? 'Take Up Sekarang'
                                                    : 'Tindak Lanjut')),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                      const Icon(Icons.arrow_forward_rounded,
                                          size: 12, color: Colors.white),
                                    ],
                                  ),
                                )
                              else if (isUnread)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 4.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: const Color(0xFFBFDBFE),
                                        width: 0.9),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Buka Detail',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF1D4ED8),
                                        ),
                                      ),
                                      SizedBox(width: 3),
                                      Icon(Icons.chevron_right_rounded,
                                          size: 13, color: Color(0xFF1D4ED8)),
                                    ],
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(7),
                                    border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                        width: 0.8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Detail',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                      SizedBox(width: 2),
                                      Icon(Icons.chevron_right_rounded,
                                          size: 12, color: Color(0xFF64748B)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          height: 115,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 80,
                      height: 16,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 100,
                      height: 16,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 50,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 220,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {

    return SingleChildScrollView(

      physics: const AlwaysScrollableScrollPhysics(),

      child: Container(

        width: double.infinity,

        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),

        child: Column(

          mainAxisAlignment: MainAxisAlignment.center,

          children: [

            Container(

              width: 90,

              height: 90,

              decoration: BoxDecoration(

                color: const Color(0xFF009688).withValues(alpha: 0.1),

                shape: BoxShape.circle,

              ),

              child: const Icon(

                Icons.task_alt_rounded,

                size: 46,

                color: Color(0xFF009688),

              ),

            ),

            const SizedBox(height: 22),

            const Text(

              'Semua Beres! Tidak Ada Notifikasi',

              style: TextStyle(

                fontSize: 16,

                fontWeight: FontWeight.w700,

                color: Color(0xFF1E293B),

              ),

              textAlign: TextAlign.center,

            ),

            const SizedBox(height: 8),

            const Text(

              'Tidak ada action plan atau temuan yang membutuhkan respon Anda saat ini. Tetap utamakan keselamatan kerja.',

              style: TextStyle(

                fontSize: 13,

                fontWeight: FontWeight.w400,

                color: Color(0xFF64748B),

                height: 1.4,

              ),

              textAlign: TextAlign.center,

            ),

            const SizedBox(height: 24),

            ElevatedButton.icon(

              onPressed: () {

                _getData();

                _fetchApiActions();

              },

              icon: const Icon(Icons.refresh_rounded, size: 18),

              label: const Text('Periksa Kembali'),

              style: ElevatedButton.styleFrom(

                backgroundColor: const Color(0xFF009688),

                foregroundColor: Colors.white,

                elevation: 0,

                padding:

                    const EdgeInsets.symmetric(horizontal: 20, vertical: 11),

                shape: RoundedRectangleBorder(

                  borderRadius: BorderRadius.circular(12),

                ),

              ),

            ),

          ],

        ),

      ),

    );

  }

}


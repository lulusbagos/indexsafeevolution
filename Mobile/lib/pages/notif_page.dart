import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api.dart';
import '../models/notification_item_model.dart';
import '../services/database.dart';
import '../services/notification.dart';
import '../services/preference.dart';
import '../services/sync.dart';
import '../utils/enums.dart';
import '../utils/globals.dart' as globals;
import '../utils/helpers.dart';
import 'approval/approval_center_page.dart';
import 'hazard/hazard_hub_page.dart';
import 'history/history_detail_page.dart';
import 'inspeksi/inspection_hub_page.dart';
import 'performance/action_tracker_page.dart';
import 'roster_settings_page.dart';
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
  List<dynamic> _rawData = [];
  bool _isSyncing = false;
  bool _isOfflineMode = false;
  DateTime? _lastSyncTime;
  String _selectedFilter = 'all'; // 'all', 'hazard', 'inspection'

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLocalData();
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
              'id', 'code', 'title', 'area_id', 'location_id', 'location_detail',
              'date', 'time', 'remark', 'image', 'video', 'status', 'pja_id', 'pic_id',
              'plan', 'plan_date', 'overdue', 'reason', 'action', 'action_date',
              'action_image', 'action_video', 'table', 'category', 'tran_id',
              'detail_id', 'company_id', 'employee_id', 'created_at', 'updated_at', 'deleted_at'
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
                    if ((row['pja_id'] != null && (row['pja_id'] as int) == profileId) ||
                        (row['nik_pja'] != null && userNik.isNotEmpty && row['nik_pja'].toString().trim() == userNik)) {
                      status = 'Ditugaskan ke Anda (PJA)';
                    }
                    if ((row['pic_id'] != null && (row['pic_id'] as int) == profileId) ||
                        (row['nik_pic'] != null && userNik.isNotEmpty && row['nik_pic'].toString().trim() == userNik)) {
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
                        debugPrint(
                            '--- update action_plans: ${row['id']} ---');
                        var profileId = _profile?.id;
                        var userNik = _profile?.noNik?.trim() ?? '';
                        var status = '';
                        if (row['status'] as int == 1) {
                          if (row['employee_id'] != null &&
                              (row['employee_id'] as int) == profileId) {
                            status = 'Diproses PJA';
                          }
                          if ((row['pic_id'] != null && (row['pic_id'] as int) == profileId) ||
                              (row['nik_pic'] != null && userNik.isNotEmpty && row['nik_pic'].toString().trim() == userNik)) {
                            status = 'Ditugaskan ke Anda (PIC)';
                          }
                        }
                        if (row['status'] as int == 2) {
                          if (row['employee_id'] != null &&
                              (row['employee_id'] as int) == profileId) {
                            status = 'Selesai Dikerjakan PIC';
                          }
                          if ((row['pja_id'] != null && (row['pja_id'] as int) == profileId) ||
                              (row['nik_pja'] != null && userNik.isNotEmpty && row['nik_pja'].toString().trim() == userNik)) {
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

  void _processRawNotificationItems(List<NotificationItemModel> notifs, List<Map<String, dynamic>> combined) {
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

      final isViolation = typeLower.contains('violation') ||
          titleLower.contains('pelanggaran');

      final isGateMovement = typeLower.contains('movement') ||
          titleLower.contains('gerbang') ||
          titleLower.contains('gate');

      final isHazard = !isCoaching && !isRoster && !isViolation && !isGateMovement && (typeLower.contains('hazard') || urlLower.contains('hazard'));
      final isInspect = !isCoaching && !isRoster && !isViolation && !isGateMovement && (typeLower.contains('inspect') || urlLower.contains('inspect'));

      final String category = isCoaching
          ? 'coaching'
          : (isRoster
              ? 'roster'
              : (isViolation
                  ? 'violation'
                  : (isGateMovement
                      ? 'movement'
                      : (isHazard ? 'hazard' : (isInspect ? 'inspection' : 'general')))));

      combined.add({
        'id': n.id,
        'is_server_notif': true,
        'title': n.title,
        'remark': n.message,
        'category': (n.category != null && n.category!.isNotEmpty) ? n.category : category,
        'notif_type': isCoaching ? 'coaching' : n.notifType,
        'url': n.url,
        'logo': n.logo,
        'sender_name': n.senderName,
        'priority': n.priority,
        'payload': n.payload,
        'action_text': n.actionText,
        'is_read': n.isRead,
        'is_actioned': n.isActioned,
        'is_action_required': (isCoaching || isRoster || isGateMovement) ? false : (isViolation ? true : n.isActionRequired),
        'date': n.createdAt != null ? DateFormat('yyyy-MM-dd').format(n.createdAt!) : '',
        'time': n.createdAt != null ? DateFormat('HH:mm').format(n.createdAt!) : '',
        'created_at_dt': n.createdAt ?? DateTime.now(),
        'status': isCoaching ? -1 : (isRoster || isGateMovement ? (n.isRead ? 1 : 0) : (isViolation ? 0 : (n.isActioned ? 2 : (n.isRead ? 1 : 0)))),
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
                : (isGateMovement
                    ? 'Pos Security Tambang'
                    : (n.url ?? ''))),
      });
    }
  }

  /// 1. Ambil data lokal SQLite INSTAN (0 detik) agar mode offline langsung aktif tanpa nunggu network
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

      await PreferenceService.setNotif(combined.length);
      if (mounted) {
        setState(() {
          _rawData = combined;
          // loaded
        });
      }
    } catch (e) {
      debugPrint('[NotifPage] Error _loadLocalData: $e');
      // loaded
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
              for (var a in items) {
                final aMap = a as Map<String, dynamic>;
                final aId = aMap['approvalId'] as int? ?? 0;
                final mod = aMap['module']?.toString() ?? 'Persetujuan';
                final nomor = aMap['nomor']?.toString() ?? '-';
                final applicant = aMap['applicantName']?.toString() ?? 'Pemohon';
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
                  'remark': 'Permohonan $mod oleh $applicant ($dept • $comp). Menunggu persetujuan Anda ($roleTarget).',
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
                  'date': reqDate != null ? DateFormat('yyyy-MM-dd').format(reqDate) : '',
                  'time': reqDate != null ? DateFormat('HH:mm').format(reqDate) : '',
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
              for (var sp in list) {
                final spMap = sp as Map<String, dynamic>;
                final reqId = spMap['reqId']?.toString() ?? '-';
                final actType = (spMap['activityType']?.toString() ?? 'Pekerjaan Khusus').replaceAll('_', ' ');
                final loc = spMap['workLocation']?.toString() ?? 'Area Operasional Tambang';
                final picName = spMap['applicantName']?.toString() ?? spMap['pjoName']?.toString() ?? 'PIC Tim';
                final issueTime = spMap['issueTime']?.toString() ?? '';
                final issueDate = spMap['issueDate']?.toString() ?? '';

                _rawData.add({
                  'id': spMap['id'],
                  'is_server_notif': true,
                  'is_special_permit': true,
                  'raw_permit': spMap,
                  'title': '⚠️ Observasi High Risk: $reqId',
                  'remark': 'Kegiatan risiko tinggi $actType di $loc. Pengawas/PJO: $picName. Segera lakukan verifikasi & observasi lapangan!',
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
                  'date': issueDate.isNotEmpty ? issueDate.substring(0, 10.clamp(0, issueDate.length)) : '',
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

        if (mounted) setState(() {});
      }

      // Getaran fisik jika ada prioritas tinggi
      final hasPicAssignments = _rawData.any((item) {
        final isActionReq = item['is_action_required'] == true;
        final isRead = item['is_read'] == true;
        final status = (item['status'] as num?)?.toInt() ?? 0;
        final p = (item['priority'] ?? '').toString().toLowerCase();
        final isApproval = item['is_approval_item'] == true;
        final isSpecialPermit = item['is_special_permit'] == true;
        return (isActionReq && (!isRead || status < 2)) || p == 'urgent' || isApproval || isSpecialPermit;
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
              content: Text('Berhasil menyinkronkan & mengunduh $downloadedCount notifikasi baru ke penyimpanan lokal HP (Mode Offline Siap).'),
              backgroundColor: const Color(0xFF009688),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Mode Offline: Menggunakan ${_rawData.length} notifikasi yang tersimpan di HP.'),
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

  List<dynamic> get _filteredData {
    if (_selectedFilter == 'all') return _rawData;
    if (_selectedFilter == 'approval') {
      return _rawData.where((item) {
        final cat = (item['category'] ?? '').toString().toLowerCase();
        return cat.contains('approval') || item['is_approval_item'] == true;
      }).toList();
    }
    if (_selectedFilter == 'special_permit') {
      return _rawData.where((item) {
        final cat = (item['category'] ?? '').toString().toLowerCase();
        return cat.contains('special_permit') || item['is_special_permit'] == true;
      }).toList();
    }
    if (_selectedFilter == 'hazard') {
      return _rawData.where((item) {
        final cat = (item['category'] ?? '').toString().toLowerCase();
        final notifType = (item['notif_type'] ?? '').toString().toLowerCase();
        return cat.contains('hazard') || cat.contains('action') || notifType.contains('hazard') || notifType.contains('action');
      }).toList();
    }
    if (_selectedFilter == 'inspection') {
      return _rawData.where((item) {
        final cat = (item['category'] ?? '').toString().toLowerCase();
        final notifType = (item['notif_type'] ?? '').toString().toLowerCase();
        return cat.contains('inspect') || cat.contains('simama') || notifType.contains('inspect');
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
    if (type == 'approval') {
      return _rawData.where((item) {
        final cat = (item['category'] ?? '').toString().toLowerCase();
        return cat.contains('approval') || item['is_approval_item'] == true;
      }).length;
    }
    if (type == 'special_permit') {
      return _rawData.where((item) {
        final cat = (item['category'] ?? '').toString().toLowerCase();
        return cat.contains('special_permit') || item['is_special_permit'] == true;
      }).length;
    }
    if (type == 'hazard') {
      return _rawData.where((item) {
        final cat = (item['category'] ?? '').toString().toLowerCase();
        final notifType = (item['notif_type'] ?? '').toString().toLowerCase();
        return cat.contains('hazard') || cat.contains('action') || notifType.contains('hazard') || notifType.contains('action');
      }).length;
    }
    if (type == 'inspection') {
      return _rawData.where((item) {
        final cat = (item['category'] ?? '').toString().toLowerCase();
        final notifType = (item['notif_type'] ?? '').toString().toLowerCase();
        return cat.contains('inspect') || cat.contains('simama') || notifType.contains('inspect');
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

      final timeStr = (rawTime != null && rawTime.isNotEmpty) ? ' $rawTime' : '';

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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                        const Icon(Icons.info_outline, size: 14, color: Color(0xFF64748B)),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF64748B)),
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

  void _openDetail(Map<String, dynamic> item) {
    final cat = (item['category'] ?? '').toString().toLowerCase();
    final isCoaching = cat.contains('coaching') ||
        (item['title'] ?? '').toString().toLowerCase().contains('coaching') ||
        (item['title'] ?? '').toString().toLowerCase().contains('pembinaan') ||
        (item['remark'] ?? '').toString().toLowerCase().contains('coaching') ||
        (item['remark'] ?? '').toString().toLowerCase().contains('pembinaan');

    if (item['is_server_notif'] == true) {
      final notifId = item['id'] as int? ?? 0;
      if (notifId > 0 && item['is_read'] != true) {
        _db.updateLocalNotificationRead(notifId, true);
        _api.markNotificationRead(notifId);
      }
      
      // Jika Coaching, tampilkan detail modal informasi
      if (isCoaching) {
        _showCoachingDialog(item);
        return;
      }

      final url = (item['url'] ?? '').toString().toLowerCase();
      final notifType = (item['notif_type'] ?? '').toString().toLowerCase();

      if (item['is_approval_item'] == true || cat.contains('approval') || url.contains('approval')) {
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
              builder: (_) => SpecialPermitFollowupPage(permit: item['raw_permit'] as Map<String, dynamic>),
            ),
          ).then((_) => _getData());
          return;
        }
        final permitId = item['payload']?.toString();
        if (permitId != null && permitId.isNotEmpty) {
          _api.getSpecialPermitDetail(permitId).then((res) {
            res.fold(
              (_) => Navigator.push(context, MaterialPageRoute(builder: (_) => const SpecialPermitListPage())).then((_) => _getData()),
              (detailData) {
                final p = detailData['data'] as Map<String, dynamic>?;
                if (p != null) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => SpecialPermitFollowupPage(permit: p))).then((_) => _getData());
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SpecialPermitListPage())).then((_) => _getData());
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
      if (cat.contains('roster') || url.contains('roster') || notifType.contains('roster')) {
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
        } else if (t.contains('takeup') || t.contains('progress') || t.contains('info')) {
          targetTab = HazardHubTab.monitoring;
        } else {
          targetTab = HazardHubTab.action;
        }
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => HazardHubPage(initialTab: targetTab)),
        ).then((_) => _getData());
        return;
      }

      if (cat.contains('inspect') || url.contains('inspect') || cat.contains('simama')) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const InspectionHubPage(initialTab: InspectionHubTab.pjaArea)),
        ).then((_) => _getData());
        return;
      }

      if (cat.contains('action') || url.contains('action') || notifType.contains('action')) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ActionTrackerPage()),
        ).then((_) => _getData());
        return;
      }

      if (!cat.contains('hazard') && !cat.contains('inspect') && !cat.contains('simama') && !cat.contains('action') && !cat.contains('approval') && !cat.contains('special_permit') && !url.contains('hazard') && !url.contains('inspect') && !url.contains('action') && !url.contains('approval') && !url.contains('special_permit')) {
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
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF009688).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.notifications_active_rounded,
                color: Color(0xFF009688),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notifikasi Tindak Lanjut',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Text(
                  'Action Plan & Temuan Lapangan',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Status Pill: Mode Offline vs Online
          Container(
            margin: const EdgeInsets.symmetric(vertical: 14),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _isOfflineMode
                  ? const Color(0xFFFEF3C7)
                  : const Color(0xFFE6F4EA),
              borderRadius: BorderRadius.circular(12),
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
          const SizedBox(width: 6),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildFilterChip('all', 'Semua', _countFor('all')),
                  const SizedBox(width: 8),
                  _buildFilterChip('approval', 'Approval', _countFor('approval')),
                  const SizedBox(width: 8),
                  _buildFilterChip('special_permit', 'Special Permit', _countFor('special_permit')),
                  const SizedBox(width: 8),
                  _buildFilterChip('hazard', 'Hazard', _countFor('hazard')),
                  const SizedBox(width: 8),
                  _buildFilterChip('inspection', 'Inspeksi', _countFor('inspection')),
                  const SizedBox(width: 8),
                  _buildFilterChip('coaching', 'Coaching', _countFor('coaching')),
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
            if (_isOfflineMode)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.offline_bolt_rounded, size: 16, color: Color(0xFFD97706)),
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
              child: filtered.isNotEmpty
                  ? ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index] as Map<String, dynamic>;
                        return _buildNotificationCard(item);
                      },
                    )
                  : _buildEmptyState(),
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
          color: isSelected ? const Color(0xFF009688) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF009688) : const Color(0xFFE2E8F0),
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
            errorBuilder: (_, __, ___) => Icon(Icons.notifications_active_rounded, size: 16, color: fallbackColor),
          ),
        ),
      );
    } else if (clean.startsWith('/') || clean.startsWith('uploads/')) {
      final fullUrl = clean.startsWith('/') ? '${_api.baseUrl}$clean' : '${_api.baseUrl}/$clean';
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
            errorBuilder: (_, __, ___) => Icon(Icons.notifications_active_rounded, size: 16, color: fallbackColor),
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
      } else if (clean.contains('broadcast') || clean.contains('announcement') || clean.contains('info')) {
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
    final logo = item['logo']?.toString();
    final url = item['url']?.toString() ?? '';
    final actionText = item['action_text']?.toString() ?? 'Buka Tautan';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        title: Row(
          children: [
            _buildNotifLogo(logo, const Color(0xFF0D9488)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  if (sender.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Dari: $sender',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0D9488)),
                    ),
                  ],
                ],
              ),
            ),
            if (priority == 'urgent')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('URGENT', style: TextStyle(color: Color(0xFFDC2626), fontSize: 9.5, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 16),
            Text(
              message,
              style: const TextStyle(fontSize: 13, height: 1.45, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Tutup', style: TextStyle(color: Color(0xFF64748B))),
                ),
                if (url.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      NotificationService.navigateToUrl(url);
                    },
                    child: Text(actionText),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> item) {
    final category = (item['category'] ?? '').toString().toLowerCase();
    final isCoaching = category.contains('coaching') ||
        (item['title'] ?? '').toString().toLowerCase().contains('coaching') ||
        (item['title'] ?? '').toString().toLowerCase().contains('pembinaan') ||
        (item['remark'] ?? '').toString().toLowerCase().contains('coaching') ||
        (item['remark'] ?? '').toString().toLowerCase().contains('pembinaan');

    final isRoster = category.contains('roster') ||
        (item['notif_type'] ?? '').toString().toLowerCase().contains('roster') ||
        (item['url'] ?? '').toString().toLowerCase().contains('roster');

    final isHazard = !isCoaching && !isRoster && (category.contains('hazard') || category.contains('action'));
    final isInspection = !isCoaching && !isRoster && (category.contains('inspect') || category.contains('simama'));

    final notifType = (item['notif_type'] ?? '').toString().toLowerCase();
    final itemTitleLower = (item['title'] ?? '').toString().toLowerCase();
    final isPjaTag = notifType.contains('pja') || itemTitleLower.contains('pja');
    final isPicTag = notifType.contains('pic') || itemTitleLower.contains('pic');

    final isApproval = item['is_approval_item'] == true || category.contains('approval');
    final isSpecialPermit = item['is_special_permit'] == true || category.contains('special_permit');

    final isViolation = category.contains('violation') ||
        notifType.contains('violation') ||
        itemTitleLower.contains('pelanggaran');

    final isGateMovement = category.contains('movement') ||
        notifType.contains('movement') ||
        itemTitleLower.contains('gerbang') ||
        itemTitleLower.contains('gate');

    final primaryTheme = isSpecialPermit
        ? const Color(0xFFDC2626)
        : (isApproval
            ? const Color(0xFF0D9488)
            : (isViolation
                ? const Color(0xFFDC2626)
                : (isGateMovement
                    ? const Color(0xFF0284C7)
                    : (isCoaching
                        ? const Color(0xFF7C3AED)
                        : (isRoster
                            ? const Color(0xFF7C3AED)
                            : (isPicTag
                                ? const Color(0xFF2563EB)
                                : (isPjaTag
                                    ? (isInspection ? const Color(0xFF0F766E) : const Color(0xFFEA580C))
                                    : (isHazard
                                        ? const Color(0xFFE65100)
                                        : (isInspection
                                            ? const Color(0xFF0288D1)
                                            : const Color(0xFF00897B))))))))));

    final bgTheme = isSpecialPermit
        ? const Color(0xFFFEE2E2)
        : (isApproval
            ? const Color(0xFFCCFBF1)
            : (isViolation
                ? const Color(0xFFFEE2E2)
                : (isGateMovement
                    ? const Color(0xFFE0F2FE)
                    : (isCoaching
                        ? const Color(0xFFF5F3FF)
                        : (isRoster
                            ? const Color(0xFFF3E8FF)
                            : (isPicTag
                                ? const Color(0xFFEFF6FF)
                                : (isPjaTag
                                    ? (isInspection ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7ED))
                                    : (isHazard
                                        ? const Color(0xFFFFF3E0)
                                        : (isInspection
                                            ? const Color(0xFFE1F5FE)
                                            : const Color(0xFFE0F2F1))))))))));

    final statusInt = (item['status'] as int?) ?? (isCoaching ? -1 : 0);
    final String statusText = (statusInt >= 0 && statusInt < globals.status.length)
        ? (globals.status[statusInt] ?? 'Status $statusInt')
        : 'Status $statusInt';
    final Color statusColor = (statusInt >= 0 && statusInt < globals.statusColor.length)
        ? (globals.statusColor[statusInt] ?? Colors.grey)
        : Colors.grey;

    final dateStr = _formatDisplayDate(item['date']?.toString(), item['time']?.toString());
    final title = titleCase(item['title']?.toString() ?? 'Tindak Lanjut');
    final remark = item['remark']?.toString() ?? '';
    final areaName = titleCase(item['area_name']?.toString() ?? '-');
    final locName = titleCase(item['location_name']?.toString() ?? '-');

    String moduleBadge;
    if (isSpecialPermit) {
      moduleBadge = 'SPECIAL PERMIT';
    } else if (isApproval) {
      moduleBadge = 'APPROVAL CENTER';
    } else if (isViolation) {
      moduleBadge = 'PELANGGARAN K3';
    } else if (isGateMovement) {
      moduleBadge = 'AKSES GERBANG';
    } else if (isCoaching) {
      moduleBadge = 'COACHING';
    } else if (isRoster) {
      moduleBadge = notifType.contains('tugas') ? 'PERIODE TUGAS' : 'ROSTER KERJA';
    } else if (isPicTag) {
      moduleBadge = 'PENUGASAN PIC';
    } else if (isPjaTag) {
      moduleBadge = isInspection ? 'PENUGASAN PJA INSPEKSI' : 'PENUGASAN PJA HAZARD';
    } else if (isHazard) {
      moduleBadge = 'HAZARD';
    } else if (category.contains('simama')) {
      moduleBadge = 'SIMAMA';
    } else if (category.contains('broadcast')) {
      moduleBadge = 'PENGUMUMAN';
    } else {
      moduleBadge = isInspection ? 'INSPEKSI' : 'TINDAK LANJUT';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFF1F5F9),
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openDetail(item),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top header: Logo + Module Pill + Priority + Timestamp
                Row(
                  children: [
                    _buildNotifLogo(item['logo']?.toString(), primaryTheme),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: bgTheme,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSpecialPermit
                                ? Icons.warning_amber_rounded
                                : (isApproval
                                    ? Icons.approval_rounded
                                    : (isViolation
                                        ? Icons.gavel_rounded
                                        : (isGateMovement
                                            ? Icons.meeting_room_rounded
                                            : (isCoaching
                                                ? Icons.psychology_outlined
                                                : (isRoster
                                                    ? (item['notif_type']?.toString().contains('tugas') == true
                                                        ? Icons.flight_takeoff_rounded
                                                        : Icons.calendar_month_rounded)
                                                    : (isPicTag
                                                        ? Icons.assignment_ind_rounded
                                                        : (isPjaTag
                                                            ? Icons.shield_rounded
                                                            : (isHazard
                                                                ? Icons.warning_amber_rounded
                                                                : Icons.fact_check_outlined)))))))),
                            size: 13,
                            color: primaryTheme,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            moduleBadge,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: primaryTheme,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (item['priority']?.toString().toLowerCase() == 'urgent') ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt_rounded, size: 11, color: Color(0xFFDC2626)),
                            SizedBox(width: 2),
                            Text('URGENT', style: TextStyle(color: Color(0xFFDC2626), fontSize: 9.5, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 13,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dateStr,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (item['sender_name'] != null && item['sender_name'].toString().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Pengirim: ${item['sender_name']}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0D9488)),
                  ),
                ],
                const SizedBox(height: 10),

                // Title
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    height: 1.3,
                  ),
                ),

                // Remark / Note Quote Bubble
                if (remark.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                        left: BorderSide(
                          color: primaryTheme.withValues(alpha: 0.6),
                          width: 3,
                        ),
                      ),
                    ),
                    child: Text(
                      titleCase(remark),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF475569),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 10),

                // Area & Location Pills
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 12, color: Color(0xFF64748B)),
                          const SizedBox(width: 3),
                          Text(
                            areaName,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (locName != '-' && locName.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.place_outlined,
                                size: 12, color: Color(0xFF64748B)),
                            const SizedBox(width: 3),
                            Text(
                              locName,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const Divider(height: 20, thickness: 0.8, color: Color(0xFFF1F5F9)),

                // Bottom row: Status badge + Action link
                Row(
                  children: [
                    if (isCoaching || statusInt < 0) ...[
                      // Coaching is purely informational: "ini hanya menampilkan saya dapat coacing dari PIC nya dan tidak ada statusnya"
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDE9FE),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 12,
                              color: Color(0xFF7C3AED),
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Informasi Pembinaan PIC',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6D28D9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: 13,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Aktif 7 hari',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (isApproval) ...[
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D9488),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: const Size(64, 28),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ApprovalCenterPage()),
                            ).then((_) => _getData());
                          },
                          icon: const Icon(Icons.check_circle_outline_rounded, size: 13),
                          label: const Text('Tinjau Persetujuan', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ] else if (isSpecialPermit) ...[
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: const Size(64, 28),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SpecialPermitListPage()),
                            ).then((_) => _getData());
                          },
                          icon: const Icon(Icons.assignment_turned_in_rounded, size: 13),
                          label: const Text('Inspeksi Lapangan', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ] else if (item['is_server_notif'] == true &&
                          (item['notif_type'] == 'hazard_assigned' || item['notif_type'] == 'hazard_new' || item['notif_type'] == 'hazard_reassigned') &&
                          item['is_actioned'] != true) ...[
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            minimumSize: const Size(54, 28),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            final notifId = item['id'] as int? ?? 0;
                            if (notifId > 0) {
                              _db.updateLocalNotificationActioned(notifId, true);
                              _db.updateLocalNotificationRead(notifId, true);
                              _api.markNotificationActioned(notifId);
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const HazardHubPage()),
                            ).then((_) => _getData());
                          },
                          icon: const Icon(Icons.touch_app_rounded, size: 12),
                          label: const Text('Take Up', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFD97706),
                            side: const BorderSide(color: Color(0xFFFDE68A)),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            minimumSize: const Size(48, 28),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const HazardHubPage()),
                            ).then((_) => _getData());
                          },
                          child: const Text('Alihkan', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                        ),
                      ] else if (item['is_server_notif'] == true &&
                          (item['notif_type'] == 'inspection_assigned') &&
                          item['is_actioned'] != true) ...[
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F766E),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            minimumSize: const Size(60, 28),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            final notifId = item['id'] as int? ?? 0;
                            if (notifId > 0) {
                              _db.updateLocalNotificationRead(notifId, true);
                              _api.markNotificationRead(notifId);
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const InspectionHubPage(initialTab: InspectionHubTab.pjaArea)),
                            ).then((_) => _getData());
                          },
                          icon: const Icon(Icons.shield_rounded, size: 12),
                          label: const Text('Area PJA', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                        ),
                      ] else if (item['is_server_notif'] == true &&
                          (item['notif_type'] == 'actionplan_assigned' || item['notif_type'] == 'actionplan_pja_assigned') &&
                          item['is_actioned'] != true) ...[
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            minimumSize: const Size(60, 28),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            final notifId = item['id'] as int? ?? 0;
                            if (notifId > 0) {
                              _db.updateLocalNotificationRead(notifId, true);
                              _api.markNotificationRead(notifId);
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ActionTrackerPage()),
                            ).then((_) => _getData());
                          },
                          icon: const Icon(Icons.assignment_ind_rounded, size: 12),
                          label: Text(
                            item['notif_type'] == 'actionplan_assigned' ? 'Perbaiki' : 'Pilih PIC',
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ] else ...[
                        InkWell(
                          onTap: () => _openDetail(item),
                          child: const Row(
                            children: [
                              Text(
                                'Tindak Lanjuti',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF009688),
                                ),
                              ),
                              SizedBox(width: 2),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 11,
                                color: Color(0xFF009688),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
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

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/api.dart';
import '../../services/database.dart';
import '../../services/preference.dart';
import '../../services/sync.dart';
import '../../utils/enums.dart';
import '../../utils/globals.dart' as globals;
import '../../utils/helpers.dart';
import '../../widgets/sap_module_ui.dart';
import '../../widgets/snackbar_msg.dart';
import '../../widgets/top_bar.dart';
import 'history_detail_page.dart';

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

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getData();
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
    /** */

    super.dispose();
  }

  void _getData() {
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
        where tr.deleted_at is null and tr.employee_id=${_profile?.id} and tr.category='${widget.module.name}' order by tr.id desc''';
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
        where tr.deleted_at is null and tr.employee_id=${_profile?.id} order by tr.id desc''';
        _table = 'hazard_trans';
        break;
      case Module.coaching:
        qry = '''$select from coaching_trans tr $joinArea
        where tr.deleted_at is null and tr.employee_id=${_profile?.id} order by tr.id desc''';
        _table = 'coaching_trans';
        break;
      case Module.observation:
        qry = '''$select,
        (select me."name" from enum_masters me where me."type"='dept' and me.id=tr.dept_id) as departemen_pekerja_yang_diamati,
        (select om."name" from observation_masters om where om."type"='document' and om.id=tr.doc_id) as dokumen_pendukung,
        (select om."name" from observation_masters om where om."type"='risk' and om.id=tr.risk_id) as resiko_kritis
        from observation_trans tr $joinArea
        where tr.deleted_at is null and tr.employee_id=${_profile?.id} order by tr.id desc''';
        _table = 'observation_trans';
        break;
      case Module.p2h:
        qry = '''select tr.*, mv.code as area_name, mv.type as location_name, 
        mv.type as jenis_kendaraan, mv.code as no_lambung_kendaraan, mv."name" as merek_kendaraan
        from p2h_trans tr
        left join vehicle_masters mv on mv.id=tr.vehicle_id and mv.deleted_at is null
        where tr.deleted_at is null and tr.employee_id=${_profile?.id} order by tr.id desc''';
        _table = 'p2h_trans';
        break;
      case Module.p5m:
        qry = '''$select,
        (select pm."name" from p5m_masters pm where pm."type"='topic-p5m' and pm.id=tr.topic_id) as topic_name
        from p5m_trans tr $joinArea
        where tr.deleted_at is null and tr.employee_id=${_profile?.id} order by tr.id desc''';
        _table = 'p5m_trans';
        break;
      case Module.safety:
        qry = '''$select from safety_trans tr $joinArea
        where tr.deleted_at is null and tr.employee_id=${_profile?.id} order by tr.id desc''';
        _table = 'safety_trans';
        break;
      case Module.induction:
        qry = '''$select from k3_trans tr $joinArea
        where tr.deleted_at is null and tr.employee_id=${_profile?.id} order by tr.id desc''';
        _table = 'k3_trans';
        break;
    }

    if (widget.history == History.action) {
      qry = '''$select, 1 as sync_id,
      (select e.nama_lengkap from employees e where e.id=tr.pja_id) as pja_name,
      (select e.nama_lengkap from employees e where e.id=tr.pic_id) as pic_name
      from action_plans tr $joinArea
      where tr.deleted_at is null and ((tr.pja_id=${_profile?.id} and tr.status<1) or (tr.pic_id=${_profile?.id} and tr.status<2))
      and tr.category='${widget.module.name}'
      order by tr.id desc''';
      _table = '';
    }

    if (widget.history == History.monitoring) {
      qry = '''$select, 1 as sync_id,
      (select e.nama_lengkap from employees e where e.id=tr.pja_id) as pja_name,
      (select e.nama_lengkap from employees e where e.id=tr.pic_id) as pic_name
      from action_plans tr $joinArea
      where tr.deleted_at is null and ((tr.pja_id=${_profile?.id} and tr.status>0) or (tr.pic_id=${_profile?.id} and tr.status>1) or tr.employee_id=${_profile?.id})
      and tr.category='${widget.module.name}'
      order by tr.id desc''';
      _table = '';
    }

    if (qry != '') {
      _db.rawQuery(qry).then((val) {
        if (val.isNotEmpty) {
          debugPrint('--- $_table : ${val.length} ---');

          if (widget.lastId != null) {
            var lastData =
                val.where((e) => e['id'] as int == widget.lastId).toList();
            if (lastData.isNotEmpty) {
              if (!mounted) return;
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

          if (!mounted) return;
          setState(() => _rawData = val.toList());
        }
      });
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

  Future<dynamic> _showBottomSheet(int index) {
    var sync = (_rawData[index]['sync_id'] == null) ? false : true;
    return showModalBottomSheet(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(
        maxHeight: 350,
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
                          case Module.inspection:
                          case Module.inspectionDaily:
                          case Module.inspectionWeekly:
                          case Module.simama:
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
                onTap: (sync)
                    ? null
                    : () {
                        Navigator.pop(context);
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('Delete Data'),
                              content: const Text(
                                'Apakah anda akan menghapus data?',
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
                                TextButton(
                                  style: TextButton.styleFrom(
                                    textStyle:
                                        Theme.of(context).textTheme.labelLarge,
                                  ),
                                  child: const Text('Ok'),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _db
                                        .delete(_table,
                                            _rawData[index]['id'] as int)
                                        .then((val) {
                                      if (!mounted) return;
                                      if (val > 0) {
                                        _db.execute(
                                            '''delete from ${_table.replaceAll('_trans', '')}_details 
                                            where tran_id=${_rawData[index]['id'] as int}''');
                                        setState(
                                            () => _rawData.removeAt(index));
                                        SnackBarMsg.success(this.context,
                                            'Data berhasil dihapus!');
                                      } else {
                                        SnackBarMsg.danger(this.context,
                                            'Data gagal dihapus!');
                                      }
                                    });
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
        onRefresh: () async => _getData(),
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
                  label: '${_rawData.length} Data',
                  color: Colors.white,
                  icon: Icons.dataset_rounded,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _historyTitle(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              if (_rawData.isNotEmpty)
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _rawData.length,
                  itemBuilder: (context, index) {
                    final row = _rawData[index] as Map<String, dynamic>;
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
                          );
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
        onPressed: () => openPage(context, widget.module),
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
    final remark = titleCase('${row['remark'] ?? '-'}');
    final area = titleCase('${row['area_name'] ?? '-'}');
    final location = titleCase('${row['location_name'] ?? '-'}');
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
                        else
                          SapStatusPill(
                            label: _actionStatusLabel(row),
                            color: _actionStatusColor(row),
                            icon: Icons.flag_rounded,
                          ),
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
          SapInfoLine(icon: Icons.notes_rounded, text: 'Note: $remark'),
          SapInfoLine(icon: Icons.map_rounded, text: 'Area: $area'),
          SapInfoLine(icon: Icons.place_rounded, text: 'Lokasi: $location'),
        ],
      ),
    );
  }

  String _actionStatusLabel(Map<String, dynamic> row) {
    final status = row['status'];
    if (status is int && globals.status.containsKey(status)) {
      return '${globals.status[status]}';
    }
    return 'Open';
  }

  Color _actionStatusColor(Map<String, dynamic> row) {
    final status = row['status'];
    if (status is int && globals.statusColor.containsKey(status)) {
      return globals.statusColor[status]!;
    }
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

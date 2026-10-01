import 'package:flutter/material.dart';

import '../../services/database.dart';
import '../../services/preference.dart';
import '../../utils/enums.dart';
import '../../utils/helpers.dart';
import '../../widgets/sap_module_ui.dart';
import '../../widgets/top_bar.dart';
import 'history_page.dart';

class OptionPage extends StatefulWidget {
  const OptionPage(this.module, {this.statusMgmt = false, super.key});

  final Module module;
  final bool? statusMgmt;

  @override
  State<OptionPage> createState() => _OptionPageState();
}

class _OptionPageState extends State<OptionPage> {
  final _db = DatabaseService();
  final _profile = PreferenceService.getProfile();
  int? _summary = 0;
  int? _action = 0;
  int? _monitor = 0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      var qry = '';

      switch (widget.module) {
        case Module.inspection:
        case Module.inspectionDaily:
        case Module.inspectionWeekly:
        case Module.simama:
          qry = '''
          select count(1) as jml from inspection_trans tr
          where tr.deleted_at is null and tr.employee_id=${_profile?.id} and tr.category='${widget.module.name}'
          ''';
        default:
          qry = '''
          select count(1) as jml from hazard_trans tr
          where tr.deleted_at is null and tr.employee_id=${_profile?.id}
          ''';
      }

      if (qry != '') {
        _db.rawQuery(qry).then((val) {
          if (val.isNotEmpty) {
            if (!mounted) return;
            setState(() => _summary = val[0]['jml'] as int);
          }
        });
      }

      _db.rawQuery('''
        select count(1) as jml from action_plans tr
        where tr.deleted_at is null and ((tr.pja_id=${_profile?.id} and tr.status<1) or (tr.pic_id=${_profile?.id} and tr.status<2))
        and tr.category='${widget.module.name}'
        ''').then((val) {
        if (val.isNotEmpty) {
          if (!mounted) return;
          setState(() => _action = val[0]['jml'] as int);
        }
      });

      _db.rawQuery('''
        select count(1) as jml from action_plans tr
        where tr.deleted_at is null and ((tr.pja_id=${_profile?.id} and tr.status>0) or (tr.pic_id=${_profile?.id} and tr.status>1) or tr.employee_id=${_profile?.id})
        and tr.category='${widget.module.name}'
        ''').then((val) {
        if (val.isNotEmpty) {
          if (!mounted) return;
          setState(() => _monitor = val[0]['jml'] as int);
        }
      });
    });
  }

  @override
  void dispose() {
    /** */

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = moduleAccentColor(widget.module);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: TopBar(title: pageTitle(widget.module)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SapModuleHeader(module: widget.module),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _MiniCounter(
                    label: 'Summary',
                    value: _summary ?? 0,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MiniCounter(
                    label: 'Action',
                    value: _action ?? 0,
                    color: const Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MiniCounter(
                    label: 'Monitor',
                    value: _monitor ?? 0,
                    color: const Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Pilih Alur Kerja',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            _OptionActionCard(
              title: 'Summary',
              subtitle: 'Lihat laporan yang sudah dibuat dan status sinkron.',
              count: _summary ?? 0,
              icon: Icons.summarize_rounded,
              color: accent,
              onTap: () => _openHistory(History.summary),
            ),
            _OptionActionCard(
              title: 'Action',
              subtitle:
                  'Tindak lanjuti action yang menjadi tanggung jawab Anda.',
              count: _action ?? 0,
              icon: Icons.assignment_turned_in_rounded,
              color: const Color(0xFFF59E0B),
              onTap: () => _openHistory(History.action),
            ),
            _OptionActionCard(
              title: 'Monitoring',
              subtitle: 'Pantau semua progres action sampai close.',
              count: _monitor ?? 0,
              icon: Icons.monitor_heart_rounded,
              color: const Color(0xFF16A34A),
              onTap: () => _openHistory(History.monitoring),
            ),
          ],
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

  void _openHistory(History history) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HistoryPage(widget.module, history),
      ),
    );
  }
}

class _MiniCounter extends StatelessWidget {
  const _MiniCounter({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionActionCard extends StatelessWidget {
  const _OptionActionCard({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final int count;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SapSoftCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    SapStatusPill(label: '$count Data', color: color),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.blueGrey.shade600,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Icon(Icons.chevron_right_rounded, color: Colors.blueGrey.shade300),
        ],
      ),
    );
  }
}

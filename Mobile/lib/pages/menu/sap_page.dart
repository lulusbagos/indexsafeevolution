import 'package:flutter/material.dart';

import '../../pages/home_page.dart';
import '../../pages/notif_page.dart';
import '../../services/offline_sync_service.dart';
import '../../utils/globals.dart' as globals;
import '../../utils/links.dart';
import '../../utils/routers.dart';

const _ink = Color(0xFF0D2F31);
const _green = Color(0xFF0AA45A);

class SapPage extends StatelessWidget {
  const SapPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF5F9F8),
        body: SafeArea(
          child: Column(children: [
            _header(context),
            Expanded(
              child: CustomScrollView(slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const Text('Pilih Aktivitas',
                          style: TextStyle(
                              color: _ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                    ]),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _moduleCard(context, index),
                      childCount: listMenuSap.length,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: .92,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 30)),
              ]),
            ),
          ]),
        ),
      );

  Widget _header(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Row(children: [
          _roundButton(
              icon: Icons.chevron_left_rounded,
              onTap: () => Navigator.maybePop(context)),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Safety Activity',
                    style: TextStyle(
                        color: _ink,
                        fontSize: 22,
                        height: 1,
                        fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text('Catat hari ini, lebih aman esok hari',
                    style: TextStyle(color: Color(0xFF68757B), fontSize: 11)),
              ],
            ),
          ),
          ValueListenableBuilder<OfflineSyncState>(
            valueListenable: OfflineSyncService.instance.state,
            builder: (_, state, __) =>
                Stack(clipBehavior: Clip.none, children: [
              _roundButton(
                icon: state.isOnline
                    ? Icons.sync_rounded
                    : Icons.cloud_off_rounded,
                color: state.pendingCount > 0 || !state.isOnline
                    ? const Color(0xFFDC2626)
                    : _green,
                onTap: () => OfflineSyncService.instance.syncNow(),
              ),
              if (state.pendingCount > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: CircleAvatar(
                    radius: 9,
                    backgroundColor: const Color(0xFFDC2626),
                    child: Text('${state.pendingCount}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
            ]),
          ),
          const SizedBox(width: 7),
          _roundButton(
              icon: Icons.notifications_none_rounded,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const NotifPage()))),
          const SizedBox(width: 7),
          _roundButton(
            icon: Icons.account_circle_outlined,
            onTap: () {
              globals.currentPage = 4;
              Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const HomePage()),
                  (_) => false);
            },
          ),
        ]),
      );

  Widget _moduleCard(BuildContext context, int index) {
    final item = listMenuSap[index];
    final style = _styles[index];
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(23),
      child: InkWell(
        borderRadius: BorderRadius.circular(23),
        onTap: () => routePage(context, item.route, title: item.title),
        child: Ink(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(23),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, style.color.withValues(alpha: .07)],
            ),
            border: Border.all(color: style.color.withValues(alpha: .14)),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x140B2B33),
                  blurRadius: 14,
                  offset: Offset(0, 7))
            ],
          ),
          child: Stack(children: [
            Positioned(
                right: -17,
                top: 8,
                child: Icon(style.icon,
                    size: 92, color: style.color.withValues(alpha: .075))),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                height: 43,
                width: 43,
                decoration: BoxDecoration(
                    color: style.color,
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                          color: style.color.withValues(alpha: .28),
                          blurRadius: 10,
                          offset: const Offset(0, 5))
                    ]),
                child: Icon(style.icon, color: Colors.white, size: 23),
              ),
              const SizedBox(height: 7),
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: _ink,
                            fontSize: 12,
                            fontWeight: FontWeight.w900)),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _roundButton(
          {required IconData icon,
          required VoidCallback onTap,
          Color color = _ink}) =>
      Material(
        color: const Color(0xFFF1F6F4),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
              height: 40, width: 40, child: Icon(icon, color: color, size: 23)),
        ),
      );
}

class _ModuleStyle {
  const _ModuleStyle(this.color, this.icon, this.description);
  final Color color;
  final IconData icon;
  final String description;
}

const _styles = [
  _ModuleStyle(Color(0xFF16A34A), Icons.bar_chart_rounded,
      'Laporan aktivitas keselamatan'),
  _ModuleStyle(Color(0xFF2677E8), Icons.find_in_page_rounded,
      'Inspeksi area dan peralatan'),
  _ModuleStyle(Color(0xFFF59E0B), Icons.warning_amber_rounded,
      'Identifikasi potensi bahaya'),
  _ModuleStyle(Color(0xFF0AA99A), Icons.fact_check_rounded,
      'Catat observasi area kerja'),
  _ModuleStyle(Color(0xFF7C4DE8), Icons.record_voice_over_rounded,
      'Komunikasi keselamatan'),
  _ModuleStyle(
      Color(0xFFEE5966), Icons.groups_rounded, 'Pembinaan dan tindak lanjut'),
  _ModuleStyle(Color(0xFF2481D4), Icons.groups_3_rounded,
      'Perilaku aman di tempat kerja'),
  _ModuleStyle(Color(0xFF159947), Icons.analytics_rounded,
      'Pantau kondisi dan indikator'),
];

import 'package:flutter/material.dart';

import '../../models/link_model.dart';
import '../../services/api.dart';
import '../../utils/links.dart';
import '../../utils/routers.dart';

const _ohsInk = Color(0xFF0D2F31);

class OhsPage extends StatefulWidget {
  const OhsPage({super.key});

  @override
  State<OhsPage> createState() => _OhsPageState();
}

class _OhsPageState extends State<OhsPage> {
  final ApiService _api = ApiService();
  bool _isApprovalRegistered = false;
  int _pendingApprovalCount = 0;
  int _pendingSpecialPermitCount = 0;

  @override
  void initState() {
    super.initState();
    _checkApprovalAccess();
  }

  Future<void> _checkApprovalAccess() async {
    try {
      final res = await _api.checkApprovalCenterStatus();
      res.fold(
        (err) {},
        (data) {
          if (mounted) {
            final d = data['data'] as Map<String, dynamic>?;
            final isReg = d?['isRegistered'] as bool? ?? false;
            final pCount = d?['pendingCount'] as int? ?? 0;
            setState(() {
              _isApprovalRegistered = isReg;
              _pendingApprovalCount = pCount;
            });
          }
        },
      );
    } catch (_) {}

    try {
      final spRes = await _api.getSpecialPermitAlerts();
      spRes.fold(
        (err) {},
        (data) {
          if (mounted) {
            final list = (data['data'] as List<dynamic>?) ?? [];
            setState(() {
              _pendingSpecialPermitCount = list.length;
            });
          }
        },
      );
    } catch (_) {}
  }

  List<LinkMenuModel> _getMenuList() {
    final list = List<LinkMenuModel>.from(listMenuOhs1);
    list.add(
      LinkMenuModel(
        title: 'Special\nPermit',
        icon: Icons.warning_amber_rounded,
        image: '',
        route: '/special_permit',
        opacity: 1,
      ),
    );
    if (_isApprovalRegistered) {
      list.add(
        LinkMenuModel(
          title: 'Approval\nCenter',
          icon: Icons.fact_check_rounded,
          image: '',
          route: '/approval_center',
          opacity: 1,
        ),
      );
    }
    return list;
  }

  Widget _buildHero(BuildContext context) => SizedBox(
    height: 156,
    child: Stack(children: [
      Positioned.fill(child: Image.asset('assets/images/sap-activity-hero.png', fit: BoxFit.cover, alignment: Alignment.centerRight)),
      Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [const Color(0xFFF4FFFC).withValues(alpha: .98), const Color(0xFFE3F8F3).withValues(alpha: .82), const Color(0xFFA9DDD2).withValues(alpha: .18)], stops: const [0, .52, 1])))),
      Positioned(top: 10, left: 11, child: _heroButton(Icons.chevron_left_rounded, () => Navigator.maybePop(context))),
      Positioned(top: 10, right: 11, child: _heroButton(Icons.health_and_safety_outlined, () {})),
      const Positioned(left: 18, right: 125, bottom: 18, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('OHS Program', style: TextStyle(color: _ohsInk, fontSize: 25, height: 1, fontWeight: FontWeight.w900)), SizedBox(height: 7),
        Text('Kesiapan kerja, inspeksi, dan keselamatan\noperasional di setiap area kerja.', style: TextStyle(color: Color(0xFF56736D), fontSize: 11.5, height: 1.2, fontWeight: FontWeight.w600)),
      ])),
    ]),
  );

  Widget _heroButton(IconData icon, VoidCallback tap) => Material(color: Colors.white.withValues(alpha: .72), shape: const CircleBorder(), child: InkWell(customBorder: const CircleBorder(), onTap: tap, child: SizedBox(width: 37, height: 37, child: Icon(icon, color: _ohsInk, size: 22))));

  @override
  Widget build(BuildContext context) {
    final menuItems = _getMenuList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F8),
      body: SafeArea(
        child: CustomScrollView(slivers: [
              SliverToBoxAdapter(child: _buildHero(context)),
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(18, 8, 18, 10),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pilih Aktivitas OHS',
                          style: TextStyle(
                              color: _ohsInk,
                              fontSize: 18,
                              fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = menuItems[index];
                      final isApprovalCenter = item.route == '/approval_center';
                      final isSpecialPermit = item.route == '/special_permit';
                      int badge = 0;
                      if (isApprovalCenter) badge = _pendingApprovalCount;
                      if (isSpecialPermit) badge = _pendingSpecialPermitCount;
                      return _OhsModuleCard(
                        item: item,
                        badgeCount: badge,
                      );
                    },
                    childCount: menuItems.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: .92,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ]),
      ),
    );
  }
}

class _OhsModuleCard extends StatelessWidget {
  const _OhsModuleCard({required this.item, this.badgeCount = 0});
  final LinkMenuModel item;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final style = _getOhsStyle(item.route);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: () => routePage(context, item.route, title: item.title),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            color: style.color.withValues(alpha: .12),
            border: Border.all(color: style.color.withValues(alpha: .12)),
          ),
          child: Stack(children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Opacity(
                  opacity: .23,
                  child: Image.asset(_ohsCardImage(item.route),
                      fit: BoxFit.cover, alignment: Alignment.centerRight),
                ),
              ),
            ),
            Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white.withValues(alpha: .76), style.color.withValues(alpha: .19)])))),
            Padding(padding: const EdgeInsets.fromLTRB(18, 14, 14, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
              const Spacer(),
              Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _ohsInk, fontSize: 14, height: .95, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              Text(_ohsDescription(item.route), maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF52627A), fontSize: 9.5, height: 1.08, fontWeight: FontWeight.w600)),
              const SizedBox(height: 7),
              Container(width: 25, height: 25, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.chevron_right_rounded, size: 19, color: Color(0xFF52627A))),
            ])),
            if (badgeCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class _OhsStyle {
  const _OhsStyle(this.color, this.icon);
  final Color color;
  final IconData icon;
}

_OhsStyle _getOhsStyle(String route) {
  switch (route) {
    case '/p5m':
      return const _OhsStyle(Color(0xFFEE5966), Icons.health_and_safety_rounded);
    case '/simama':
      return const _OhsStyle(Color(0xFF7C4DE8), Icons.nights_stay_rounded);
    case '/p2h':
      return const _OhsStyle(Color(0xFFF59E0B), Icons.car_repair_rounded);
    case '/dpa':
      return const _OhsStyle(Color(0xFF159947), Icons.drive_eta_rounded);
    case '/approval_center':
      return const _OhsStyle(Color(0xFF0284C7), Icons.fact_check_rounded);
    case '/special_permit':
      return const _OhsStyle(Color(0xFFDC2626), Icons.warning_amber_rounded);
    case '/inspection':
      return const _OhsStyle(Color(0xFF2677E8), Icons.manage_search_rounded);
    case '/daily_inspection':
      return const _OhsStyle(Color(0xFF0AA99A), Icons.fact_check_rounded);
    default:
      return const _OhsStyle(Color(0xFF0AA99A), Icons.work_outline_rounded);
  }
}

String _ohsCardImage(String route) {
  switch (route) {
    case '/p5m': return 'assets/images/ohs-fit-to-work.png';
    case '/simama': return 'assets/images/ohs-simama.png';
    case '/p2h': return 'assets/images/ohs-p2h.png';
    case '/dpa': return 'assets/images/ohs-dpa.png';
    case '/special_permit': return 'assets/images/ohs-special.png';
    default: return 'assets/images/ohs-inspection.png';
  }
}

String _ohsDescription(String route) {
  switch (route) {
    case '/p5m': return 'Pastikan kondisi kesehatan dan kesiapan sebelum bekerja.';
    case '/simama': return 'Sidak Malam Management.';
    case '/p2h': return 'Pemeriksaan harian unit kendaraan operasional.';
    case '/dpa': return 'Driver Performance Assessment.';
    case '/special_permit': return 'Pengajuan dan persetujuan izin kerja khusus.';
    default: return 'Pemeriksaan keselamatan area kerja.';
  }
}

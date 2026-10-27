import 'package:flutter/material.dart';

import '../../models/link_model.dart';
import '../../services/api.dart';
import '../../utils/links.dart';
import '../../utils/routers.dart';
import '../../widgets/activity_hub_header.dart';

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

  @override
  Widget build(BuildContext context) {
    final menuItems = _getMenuList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F8),
      body: SafeArea(
        child: Column(children: [
          const ActivityHubHeader(
            title: 'OHS Program',
            subtitle: 'Kesiapan kerja, inspeksi, dan keselamatan operasional',
          ),
          Expanded(
            child: CustomScrollView(slivers: [
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 18, 16, 10),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Operational Health & Safety',
                          style: TextStyle(
                              color: _ohsInk,
                              fontSize: 18,
                              fontWeight: FontWeight.w900)),
                      SizedBox(height: 4),
                      Text('Pilih aktivitas inspeksi dan kesiapan kerja.',
                          style: TextStyle(
                              color: Color(0xFF68757B), fontSize: 12)),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: .92,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ]),
          ),
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
                            color: _ohsInk,
                            fontSize: 12,
                            fontWeight: FontWeight.w900)),
                  ),
                ),
              ),
            ]),
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

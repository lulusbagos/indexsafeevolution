import 'package:flutter/material.dart';

import '../../utils/links.dart';
import '../../utils/routers.dart';
import '../../widgets/activity_hub_header.dart';

const _hubInk = Color(0xFF0D2F31);

class ExtraPage extends StatelessWidget {
  const ExtraPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF5F9F8),
        body: SafeArea(
          child: Column(children: [
            const ActivityHubHeader(
              title: 'Performance Hub',
              subtitle: 'Pantau pencapaian, tindak lanjut, dan informasi SAP',
            ),
            Expanded(
                child: CustomScrollView(slivers: [
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 18, 16, 10),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Performance Hub',
                          style: TextStyle(
                              color: _hubInk,
                              fontSize: 18,
                              fontWeight: FontWeight.w900)),
                      SizedBox(height: 4),
                      Text(
                          'Pantau pencapaian, tindak lanjut, dan informasi SAP.',
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
                    (context, index) => _HubModuleCard(index: index),
                    childCount: listMenuExtra.length,
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
            ])),
          ]),
        ),
      );
}

class _HubModuleCard extends StatelessWidget {
  const _HubModuleCard({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    final item = listMenuExtra[index];
    final style = _hubStyles[index];
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
                            color: _hubInk,
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
}

class _HubStyle {
  const _HubStyle(this.color, this.icon);
  final Color color;
  final IconData icon;
}

const _hubStyles = [
  _HubStyle(Color(0xFF16A34A), Icons.track_changes_rounded),
  _HubStyle(Color(0xFFF59E0B), Icons.emoji_events_rounded),
  _HubStyle(Color(0xFFEE5966), Icons.newspaper_rounded),
  _HubStyle(Color(0xFF2677E8), Icons.calendar_month_rounded),
  _HubStyle(Color(0xFF7C4DE8), Icons.verified_rounded),
  _HubStyle(Color(0xFF0AA99A), Icons.assignment_turned_in_rounded),
];

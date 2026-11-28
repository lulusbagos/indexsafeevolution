import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../utils/links.dart';
import '../../utils/routers.dart';

const _hubInk = Color(0xFF0D2F31);
const _webSapUrl = 'https://mbssap.indexim.id/';

class ExtraPage extends StatelessWidget {
  const ExtraPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF5F9F8),
        body: SafeArea(
          child: CustomScrollView(slivers: [
              SliverToBoxAdapter(child: _hubHero(context)),
              SliverToBoxAdapter(child: _webSapDirectCard(context)),
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Modul Kinerja & Evaluasi',
                          style: TextStyle(
                              color: _hubInk,
                              fontSize: 18,
                              fontWeight: FontWeight.w900)),
                      SizedBox(height: 4),
                      Text(
                          'Pantau pencapaian, peringkat kinerja, dan laporan analitik terpadu.',
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

  Widget _webSapDirectCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0A2540), Color(0xFF134E4A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF134E4A).withValues(alpha: 0.25),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2DD4BF).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2DD4BF).withValues(alpha: 0.35)),
                  ),
                  child: const Icon(Icons.language_rounded, color: Color(0xFF2DD4BF), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Portal Web MBS SAP',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Pengerjaan & verifikasi SAP lengkap di $_webSapUrl',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final uri = Uri.parse(_webSapUrl);
                    try {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } catch (_) {}
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 1,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Buka Web', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                      SizedBox(width: 3),
                      Icon(Icons.arrow_outward_rounded, size: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _hubHero(BuildContext context) => SizedBox(height: 156, child: Stack(children: [
  Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [const Color(0xFFF8FBFF), const Color(0xFFDDEEFF), const Color(0xFFB9D7FF)])))),
  Positioned(right: 8, top: 8, bottom: 0, child: Icon(Icons.query_stats_rounded, size: 150, color: const Color(0xFF2563EB).withValues(alpha: .14))),
  Positioned(top: 10,left: 11,child: Material(color: Colors.white.withValues(alpha:.75),shape: const CircleBorder(),child: InkWell(customBorder: const CircleBorder(),onTap:()=>Navigator.maybePop(context),child: const SizedBox(width:37,height:37,child:Icon(Icons.chevron_left_rounded,color:_hubInk))))),
  const Positioned(left:18,right:115,bottom:18,child: Column(crossAxisAlignment: CrossAxisAlignment.start,children:[Text('Performance Hub',style:TextStyle(color:_hubInk,fontSize:25,fontWeight:FontWeight.w900)),SizedBox(height:7),Text('Pantau pencapaian, tindak lanjut, dan\ninformasi SAP.',style:TextStyle(color:Color(0xFF64748B),fontSize:11.5,fontWeight:FontWeight.w600))])),
]));

class _HubModuleCard extends StatelessWidget {
  const _HubModuleCard({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    final item = listMenuExtra[index];
    final style = _hubStyles[index % _hubStyles.length];
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
  _HubStyle(Color(0xFF16A34A), Icons.bar_chart_rounded),
  _HubStyle(Color(0xFF0284C7), Icons.person_pin_rounded),
  _HubStyle(Color(0xFFF59E0B), Icons.emoji_events_rounded),
  _HubStyle(Color(0xFF6366F1), Icons.groups_rounded),
  _HubStyle(Color(0xFF7C4DE8), Icons.verified_rounded),
  _HubStyle(Color(0xFF2563EB), Icons.calendar_month_rounded),
  _HubStyle(Color(0xFF0D9488), Icons.assignment_turned_in_rounded),
  _HubStyle(Color(0xFFE11D48), Icons.assessment_rounded),
  _HubStyle(Color(0xFFEA580C), Icons.campaign_rounded),
  _HubStyle(Color(0xFF059669), Icons.drive_eta_rounded),
];

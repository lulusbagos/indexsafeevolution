import 'package:flutter/material.dart';
import '../../pages/home_page.dart';
import '../../utils/globals.dart' as globals;
import '../../utils/links.dart';
import '../../utils/routers.dart';

const _ink = Color(0xFF0A1D3A);

class SapPage extends StatelessWidget {
  const SapPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF9FCFF),
    body: SafeArea(child: CustomScrollView(slivers: [
      SliverToBoxAdapter(child: _hero(context)),
      const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(18, 4, 18, 10), child: Text('Pilih Aktivitas', style: TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w900)))),
      SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 10), sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate((c, i) => _card(c, i), childCount: 6),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: .92))),
      SliverPadding(padding: const EdgeInsets.fromLTRB(10, 10, 10, 30), sliver: SliverToBoxAdapter(child: _condition(context))),
    ])),
  );

  Widget _hero(BuildContext c) => SizedBox(height: 156, child: Stack(children: [
    Positioned.fill(child: Image.asset('assets/images/sap-activity-hero.png', fit: BoxFit.cover, alignment: Alignment.centerRight)),
    Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [const Color(0xFFF8FBFF).withValues(alpha: .98), const Color(0xFFEAF4FF).withValues(alpha: .84), const Color(0xFFCCE2FF).withValues(alpha: .18)], stops: const [0, .52, 1])))),
    Positioned(top: 10, left: 11, child: _button(Icons.chevron_left_rounded, () => Navigator.maybePop(c))),
    Positioned(top: 10, right: 11, child: _button(Icons.account_circle_outlined, () { globals.currentPage = 4; Navigator.pushAndRemoveUntil(c, MaterialPageRoute(builder: (_) => const HomePage()), (_) => false); })),
    const Positioned(left: 18, right: 125, bottom: 18, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Safety Activity', style: TextStyle(color: _ink, fontSize: 25, height: 1, fontWeight: FontWeight.w900)), SizedBox(height: 7),
      Text('Catat, lapor, dan tingkatkan keselamatan\nbersama di setiap langkah kerja.', style: TextStyle(color: Color(0xFF65748C), fontSize: 11.5, height: 1.2, fontWeight: FontWeight.w600)),
    ])),
  ]));

  Widget _card(BuildContext c, int i) {
    final s = _styles[i]; final m = listMenuSap[i];
    return Material(color: Colors.transparent, borderRadius: BorderRadius.circular(17), child: InkWell(
      onTap: () => routePage(c, m.route, title: m.title), borderRadius: BorderRadius.circular(17),
      child: Ink(decoration: BoxDecoration(color: s.color.withValues(alpha: .12), borderRadius: BorderRadius.circular(17), border: Border.all(color: s.color.withValues(alpha: .12))), child: Stack(children: [
        Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Opacity(opacity: .23, child: Image.asset(s.path, fit: BoxFit.cover)))),
        Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white.withValues(alpha: .76), s.color.withValues(alpha: .19)])))),
        Padding(padding: const EdgeInsets.fromLTRB(18, 14, 14, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 43, height: 43, decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: s.color.withValues(alpha: .28), blurRadius: 8, offset: const Offset(0, 4))]), child: Icon(s.icon, color: Colors.white, size: 23)),
          const Spacer(), Text(s.title, maxLines: 2, style: const TextStyle(color: _ink, fontSize: 14, height: .95, fontWeight: FontWeight.w900)), const SizedBox(height: 5),
          Text(s.desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF52627A), fontSize: 9.5, height: 1.08, fontWeight: FontWeight.w600)), const SizedBox(height: 7), _arrow(),
        ])),
      ])),
    ));
  }

  Widget _condition(BuildContext c) { final m = listMenuSap.length > 6 ? listMenuSap[6] : listMenuSap.last; return Material(color: Colors.transparent, borderRadius: BorderRadius.circular(17), child: InkWell(onTap: () => routePage(c, m.route, title: m.title), borderRadius: BorderRadius.circular(17), child: Ink(height: 100, decoration: BoxDecoration(borderRadius: BorderRadius.circular(17), gradient: const LinearGradient(colors: [Color(0xFFE8FFF0), Color(0xFFB8F0C6)])), child: Stack(children: [
    Positioned(right: -14, top: -25, bottom: -25, width: 190, child: Opacity(opacity: .26, child: Image.asset('assets/images/sap-activity-hero.png', fit: BoxFit.cover))),
    Padding(padding: const EdgeInsets.all(16), child: Row(children: [Container(width: 43, height: 43, decoration: BoxDecoration(color: const Color(0xFF16A432), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.query_stats_rounded, color: Colors.white, size: 24)), const SizedBox(width: 16), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Condition Index (CI)', style: TextStyle(color: _ink, fontSize: 14, fontWeight: FontWeight.w900)), SizedBox(height: 4), Text('Pantau kondisi area kerja\nsecara berkala.', style: TextStyle(color: Color(0xFF426B50), fontSize: 10, height: 1.1, fontWeight: FontWeight.w600))])), _arrow()]))
  ])))); }
  Widget _arrow() => Container(width: 25, height: 25, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.chevron_right_rounded, size: 19, color: Color(0xFF52627A)));
  Widget _button(IconData icon, VoidCallback tap) => Material(color: Colors.white.withValues(alpha: .75), shape: const CircleBorder(), child: InkWell(customBorder: const CircleBorder(), onTap: tap, child: SizedBox(width: 37, height: 37, child: Icon(icon, color: _ink, size: 23))));
}

class _Style { const _Style(this.title, this.desc, this.color, this.icon, this.path); final String title, desc, path; final Color color; final IconData icon; }
const _styles = [
  _Style('Inspection\n& Weekly', 'Lakukan inspeksi rutin lapangan.', Color(0xFF2378F5), Icons.find_in_page_rounded, 'assets/images/sap-inspection.png'),
  _Style('Hazard\nReport', 'Laporkan potensi bahaya di area kerja.', Color(0xFFFF9D00), Icons.warning_amber_rounded, 'assets/images/sap-hazard.png'),
  _Style('Observation', 'Catat perilaku aman dan tidak aman.', Color(0xFF00BCA8), Icons.fact_check_rounded, 'assets/images/sap-observation.png'),
  _Style('Safety Talk', 'Laksanakan dan dokumentasikan safety talk.', Color(0xFF8239ED), Icons.forum_rounded, 'assets/images/sap-talk.png'),
  _Style('Coaching', 'Lakukan coaching untuk peningkatan keselamatan.', Color(0xFFFF5963), Icons.groups_rounded, 'assets/images/sap-coaching.png'),
  _Style('BBS', 'Catat perilaku dan budaya keselamatan.', Color(0xFF1688EA), Icons.group_rounded, 'assets/images/sap-bbs.png'),
];

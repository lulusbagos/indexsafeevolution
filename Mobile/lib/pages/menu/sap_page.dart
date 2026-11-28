import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../pages/home_page.dart';
import '../../utils/globals.dart' as globals;
import '../../utils/links.dart';
import '../../utils/routers.dart';

const _ink = Color(0xFF0A1D3A);
const _webSapUrl = 'https://mbssap.indexim.id/';

class SapPage extends StatelessWidget {
  const SapPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF9FCFF),
    body: SafeArea(child: CustomScrollView(slivers: [
      SliverToBoxAdapter(child: _hero(context)),
      SliverToBoxAdapter(child: _webSapDirectCard(context)),
      const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(18, 12, 18, 10), child: Text('Pilih Aktivitas', style: TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w900)))),
      SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 10), sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate((c, i) => _card(c, i), childCount: 6),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: .92))),
      SliverPadding(padding: const EdgeInsets.fromLTRB(10, 10, 10, 10), sliver: SliverToBoxAdapter(child: _condition(context))),
      SliverToBoxAdapter(child: _syncFooterNote(context)),
    ])),
  );

  Widget _webSapDirectCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 4),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned(
                right: -15,
                bottom: -20,
                child: Icon(
                  Icons.language_rounded,
                  size: 135,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.public_rounded, color: Color(0xFF38BDF8), size: 12),
                              SizedBox(width: 4),
                              Text(
                                'PORTAL WEB RESMI',
                                style: TextStyle(
                                  color: Color(0xFF38BDF8),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline_rounded, color: Color(0xFF4ADE80), size: 12),
                              SizedBox(width: 4),
                              Text(
                                'Online 24/7',
                                style: TextStyle(
                                  color: Color(0xFF4ADE80),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Pengerjaan & Pelaporan SAP via Web',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Untuk pengerjaan form laporan SAP, verifikasi persetujuan (approval), review dokumen, dan monitoring kepatuhan tim secara lengkap, silakan akses portal web:',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Material(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () async {
                                final uri = Uri.parse(_webSapUrl);
                                try {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                } catch (_) {}
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.link_rounded, color: Color(0xFF93C5FD), size: 16),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _webSapUrl,
                                        style: TextStyle(
                                          color: Color(0xFF93C5FD),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          decoration: TextDecoration.underline,
                                          decorationColor: Color(0xFF93C5FD),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Clipboard.setData(const ClipboardData(text: _webSapUrl));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Tautan Web MBS SAP disalin ke clipboard!'),
                                  duration: Duration(seconds: 2),
                                  backgroundColor: Color(0xFF0F172A),
                                ),
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(8.5),
                              child: Icon(Icons.copy_rounded, color: Colors.white, size: 17),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse(_webSapUrl);
                          try {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          } catch (_) {}
                        },
                        icon: const Icon(Icons.open_in_browser_rounded, size: 16, color: Colors.white),
                        label: const Text(
                          'Buka Web MBS SAP',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _syncFooterNote(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Row(
          children: [
            Icon(Icons.sync_rounded, size: 16, color: Color(0xFF64748B)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Data pelaporan SAP tersinkronisasi otomatis dengan server https://mbssap.indexim.id/',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
  _Style('Inspeksi', 'Lakukan inspeksi rutin lapangan.', Color(0xFF2378F5), Icons.find_in_page_rounded, 'assets/images/sap-inspection.png'),
  _Style('Hazard\nReport', 'Laporkan potensi bahaya di area kerja.', Color(0xFFFF9D00), Icons.warning_amber_rounded, 'assets/images/sap-hazard.png'),
  _Style('Observation', 'Catat perilaku aman dan tidak aman.', Color(0xFF00BCA8), Icons.fact_check_rounded, 'assets/images/sap-observation.png'),
  _Style('Safety Talk', 'Laksanakan dan dokumentasikan safety talk.', Color(0xFF8239ED), Icons.forum_rounded, 'assets/images/sap-talk.png'),
  _Style('Coaching', 'Lakukan coaching untuk peningkatan keselamatan.', Color(0xFFFF5963), Icons.groups_rounded, 'assets/images/sap-coaching.png'),
  _Style('BBS', 'Catat perilaku dan budaya keselamatan.', Color(0xFF1688EA), Icons.group_rounded, 'assets/images/sap-bbs.png'),
];

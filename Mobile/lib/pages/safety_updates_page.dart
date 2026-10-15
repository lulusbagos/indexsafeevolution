import 'package:flutter/material.dart';

class SafetyUpdatesPage extends StatefulWidget {
  const SafetyUpdatesPage({super.key});

  @override
  State<SafetyUpdatesPage> createState() => _SafetyUpdatesPageState();
}

class _SafetyUpdatesPageState extends State<SafetyUpdatesPage> {
  static const _blue = Color(0xFF155EEF);
  String _category = 'Semua';

  final List<_SafetyUpdate> _updates = const [
    _SafetyUpdate(
      category: 'Safety Alert',
      label: 'URGENT',
      title: 'Perubahan Jalur Hauling KM 18 – KM 22',
      summary:
          'Mulai berlaku 1 Oktober 2026. Seluruh operator wajib mengikuti jalur terbaru untuk meningkatkan keselamatan di area kerja.',
      date: '30 Sep 2026',
      time: '10:30',
      views: '1.2K',
      image: 'assets/images/header-home.png',
      color: Color(0xFFEF4444),
      icon: Icons.warning_amber_rounded,
    ),
    _SafetyUpdate(
      category: 'Announcement',
      label: 'IMPORTANT',
      title: 'Inspeksi Gabungan Area Workshop',
      summary:
          'Inspeksi gabungan akan dilaksanakan pada 3–5 Oktober 2026. Pastikan area kerja dalam kondisi siap dan aman.',
      date: '29 Sep 2026',
      time: '16:20',
      views: '856',
      image: 'assets/images/info2.jpg',
      color: Color(0xFF2563EB),
      icon: Icons.campaign_rounded,
    ),
    _SafetyUpdate(
      category: 'MBS Update',
      label: 'INFO',
      title: 'SAP League September 2026 Result',
      summary:
          'Berikut hasil SAP League bulan September 2026. Terus tingkatkan komitmen dan kualitas pelaporan keselamatan.',
      date: '28 Sep 2026',
      time: '09:15',
      views: '642',
      image: 'assets/images/logo-mbs.png',
      color: Color(0xFF16A34A),
      icon: Icons.verified_rounded,
    ),
    _SafetyUpdate(
      category: 'Safety Campaign',
      label: 'INFO',
      title: 'World First Aid Day 2026',
      summary:
          'Mari tingkatkan kesadaran pertolongan pertama di tempat kerja. Cek jadwal kegiatan dan materi kampanye.',
      date: '27 Sep 2026',
      time: '14:45',
      views: '509',
      image: 'assets/images/quick-hazard.png',
      color: Color(0xFF7C3AED),
      icon: Icons.health_and_safety_rounded,
    ),
  ];

  List<_SafetyUpdate> get _visibleUpdates {
    if (_category == 'Semua') return _updates;
    return _updates.where((item) => item.category == _category).toList();
  }

  @override
  Widget build(BuildContext context) {
    final categories = <String>[
      'Semua',
      'Safety Alert',
      'Announcement',
      'MBS Update',
      'Safety Campaign',
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Safety Updates',
                      style: TextStyle(
                        color: Color(0xFF101828),
                        fontSize: 27,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Berita keselamatan, peringatan, dan pengumuman terbaru',
                      style: TextStyle(
                        color: Colors.blueGrey.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _HeroUpdate(update: _updates.first),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 48,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final selected = category == _category;
                    return ChoiceChip(
                      label: Text(category),
                      selected: selected,
                      showCheckmark: false,
                      side: BorderSide(
                        color: selected ? _blue : const Color(0xFFE4EAF2),
                      ),
                      backgroundColor: Colors.white,
                      selectedColor: _blue,
                      labelStyle: TextStyle(
                        color:
                            selected ? Colors.white : const Color(0xFF475467),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      onSelected: (_) => setState(() => _category = category),
                    );
                  },
                ),
              ),
            ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(18, 8, 18, 10),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Text(
                      'Update Terbaru',
                      style: TextStyle(
                        color: Color(0xFF101828),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Spacer(),
                    Text(
                      'Lihat Semua',
                      style: TextStyle(
                        color: _blue,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded, color: _blue, size: 18),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 120),
              sliver: SliverList.separated(
                itemCount: _visibleUpdates.length,
                separatorBuilder: (_, __) => const SizedBox(height: 9),
                itemBuilder: (context, index) => _UpdateCard(
                  update: _visibleUpdates[index],
                  onTap: () => _showUpdate(_visibleUpdates[index]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUpdate(_SafetyUpdate update) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: .72,
        minChildSize: .48,
        maxChildSize: .92,
        expand: false,
        builder: (context, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD0D5DD),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  update.image,
                  height: 190,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 18),
              _CategoryBadge(update: update),
              const SizedBox(height: 12),
              Text(
                update.title,
                style: const TextStyle(
                  color: Color(0xFF101828),
                  fontSize: 23,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              _UpdateMeta(update: update),
              const SizedBox(height: 18),
              Text(
                update.summary,
                style: const TextStyle(
                  color: Color(0xFF475467),
                  fontSize: 15,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroUpdate extends StatelessWidget {
  const _HeroUpdate({required this.update});

  final _SafetyUpdate update;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 205,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(19),
        boxShadow: const [
          BoxShadow(
            color: Color(0x220F172A),
            blurRadius: 18,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(update.image, fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x10000000), Color(0xE6000000)],
                stops: [.28, 1],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CategoryBadge(update: update, light: true),
                const Spacer(),
                Text(
                  update.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  update.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFE4E7EC),
                    fontSize: 11,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        color: Colors.white, size: 13),
                    const SizedBox(width: 6),
                    Text(
                      '${update.date} • ${update.time}',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                    const Spacer(),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white70),
                      ),
                      child: const Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UpdateCard extends StatelessWidget {
  const _UpdateCard({required this.update, required this.onTap});

  final _SafetyUpdate update;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFEAECF0)),
            borderRadius: BorderRadius.circular(17),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 78,
                  height: 78,
                  color: update.color.withValues(alpha: .1),
                  child: Image.asset(update.image, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CategoryBadge(update: update),
                    const SizedBox(height: 5),
                    Text(
                      update.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF101828),
                        fontSize: 13,
                        height: 1.12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      update.summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _UpdateMeta(update: update),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 29),
                child: Icon(Icons.chevron_right_rounded,
                    color: Color(0xFF667085), size: 21),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.update, this.light = false});

  final _SafetyUpdate update;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: light ? update.color : update.color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(update.icon,
                  size: 11, color: light ? Colors.white : update.color),
              const SizedBox(width: 3),
              Text(
                update.category.toUpperCase(),
                style: TextStyle(
                  color: light ? Colors.white : update.color,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: update.label == 'URGENT'
                ? const Color(0xFFFFE4E8)
                : const Color(0xFFF2F4F7),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            update.label,
            style: TextStyle(
              color: update.label == 'URGENT'
                  ? const Color(0xFFD92D20)
                  : const Color(0xFF667085),
              fontSize: 8,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _UpdateMeta extends StatelessWidget {
  const _UpdateMeta({required this.update});

  final _SafetyUpdate update;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.calendar_today_rounded,
            size: 11, color: Color(0xFF98A2B3)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            '${update.date} • ${update.time}',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF98A2B3), fontSize: 9),
          ),
        ),
        const SizedBox(width: 9),
        const Icon(Icons.visibility_outlined,
            size: 12, color: Color(0xFF98A2B3)),
        const SizedBox(width: 3),
        Text(update.views,
            style: const TextStyle(color: Color(0xFF98A2B3), fontSize: 9)),
      ],
    );
  }
}

class _SafetyUpdate {
  const _SafetyUpdate({
    required this.category,
    required this.label,
    required this.title,
    required this.summary,
    required this.date,
    required this.time,
    required this.views,
    required this.image,
    required this.color,
    required this.icon,
  });

  final String category;
  final String label;
  final String title;
  final String summary;
  final String date;
  final String time;
  final String views;
  final String image;
  final Color color;
  final IconData icon;
}

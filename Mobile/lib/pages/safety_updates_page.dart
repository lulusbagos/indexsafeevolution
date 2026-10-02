import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/incident_news_model.dart';
import '../services/api.dart';
import '../services/preference.dart';
import '../widgets/ambient_background.dart';

class SafetyUpdatesPage extends StatefulWidget {
  const SafetyUpdatesPage({super.key});

  @override
  State<SafetyUpdatesPage> createState() => _SafetyUpdatesPageState();
}

class _SafetyUpdatesPageState extends State<SafetyUpdatesPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static const _blue = Color(0xFF155EEF);
  final ApiService _api = ApiService();
  String _category = 'Semua';
  bool _isLoadingIncidents = false;
  List<IncidentNewsModel> _rawIncidents = [];

  @override
  void initState() {
    super.initState();
    _fetchIncidents();
  }

  Future<void> _fetchIncidents() async {
    setState(() => _isLoadingIncidents = true);
    final res = await _api.getIncidents(limit: 30);
    res.fold(
      (err) {
        if (mounted) setState(() => _isLoadingIncidents = false);
      },
      (incidents) async {
        if (mounted) {
          final lastSeen = PreferenceService.getLastSeenIncidentId();
          if (incidents.isNotEmpty) {
            final latest = incidents.first;
            if (lastSeen > 0 && latest.id > lastSeen) {
              try {
                for (int i = 0; i < 3; i++) {
                  await HapticFeedback.heavyImpact();
                  await Future.delayed(const Duration(milliseconds: 200));
                  await HapticFeedback.vibrate();
                  await Future.delayed(const Duration(milliseconds: 250));
                }
              } catch (_) {}

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.vibration_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Safety Update Terbaru: ${latest.judul}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: const Color(0xFFDC2626),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            }
            await PreferenceService.setLastSeenIncidentId(latest.id);
          }

          setState(() {
            _rawIncidents = incidents;
            _isLoadingIncidents = false;
          });
        }
      },
    );
  }

  List<_SafetyUpdate> get _incidentUpdates {
    return _rawIncidents.map((inc) {
      final isNewest = _rawIncidents.isNotEmpty && inc.id == _rawIncidents.first.id;
      Color catColor = const Color(0xFFEF4444);
      IconData catIcon = Icons.warning_amber_rounded;
      final cat = inc.kategori.toLowerCase();

      if (cat.contains('banner') || cat.contains('informasi')) {
        catColor = const Color(0xFF0284C7);
        catIcon = Icons.campaign_rounded;
      } else if (cat.contains('near miss')) {
        catColor = const Color(0xFFD97706);
        catIcon = Icons.report_problem_rounded;
      } else if (cat.contains('property')) {
        catColor = const Color(0xFFEA580C);
        catIcon = Icons.build_circle_rounded;
      } else if (cat.contains('first aid')) {
        catColor = const Color(0xFF0D9488);
        catIcon = Icons.medical_services_rounded;
      } else if (cat.contains('fire') || cat.contains('kebakaran')) {
        catColor = const Color(0xFFDC2626);
        catIcon = Icons.local_fire_department_rounded;
      } else if (cat.contains('fatal')) {
        catColor = const Color(0xFF991B1B);
        catIcon = Icons.dangerous_rounded;
      } else if (cat.contains('medical')) {
        catColor = const Color(0xFF7C3AED);
        catIcon = Icons.health_and_safety_rounded;
      }

      String dateStr = 'Hari ini';
      String timeStr = '10:00';
      if (inc.tanggalKejadian != null) {
        dateStr = DateFormat('d MMM yyyy').format(inc.tanggalKejadian!);
        timeStr = DateFormat('HH:mm').format(inc.tanggalKejadian!);
      }

      return _SafetyUpdate(
        id: inc.id,
        category: cat.contains('banner') ? 'Informasi' : 'Insiden',
        rawCategory: inc.kategori,
        label: inc.kategori.toUpperCase(),
        title: inc.judul,
        summary: inc.konten,
        date: dateStr,
        time: timeStr,
        views: '${700 + (inc.id * 43) % 400}',
        image: 'assets/images/header-home.png',
        imageUrl: inc.gambarUrl,
        color: catColor,
        icon: catIcon,
        location: inc.lokasi,
        reporter: inc.dibuatOleh,
        isFromIncidentServer: true,
        isLatest: isNewest,
      );
    }).toList();
  }

  List<_SafetyUpdate> get _visibleUpdates {
    if (_category == 'Semua') {
      return _incidentUpdates;
    }
    final target = _category.toLowerCase().trim();
    return _incidentUpdates.where((item) {
      final lbl = item.label.toLowerCase().trim();
      final raw = item.rawCategory.toLowerCase().trim();
      return lbl == target || raw == target || lbl.contains(target) || raw.contains(target);
    }).toList();
  }

  _SafetyUpdate? get _currentHero {
    if (_visibleUpdates.isNotEmpty) {
      return _visibleUpdates.first;
    }
    if (_incidentUpdates.isNotEmpty) {
      return _incidentUpdates.first;
    }
    return null;
  }

  Widget _buildStandbyHero() {
    return Container(
      height: 180,
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_rounded, color: Color(0xFF22C55E), size: 14),
                SizedBox(width: 5),
                Text(
                  'SAFETY FLASH • LIVE MONITORING',
                  style: TextStyle(color: Color(0xFF22C55E), fontSize: 10.5, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Laporan & Pemantauan Insiden',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Seluruh data terintegrasi real-time dengan database SAP & HSE pusat.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final categories = <String>[
      'Semua',
      'Banner Informasi',
      'Near Miss',
      'Property Damage',
      'First Aid Injury',
      'Kebakaran',
      'Medical Treatment Injury',
      'Fatality',
    ];

    final heroItem = _currentHero;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: AmbientBackground(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _fetchIncidents,
            color: _blue,
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. TOP HEADER
                        _buildTopHeader(),

                        const SizedBox(height: 14),

                        // ==================== HERO BANNER ====================
                        if (heroItem != null)
                          _HeroUpdate(
                            update: heroItem,
                            isIncidentTab: true,
                            onTap: () => _showUpdate(heroItem),
                          )
                        else
                          _buildStandbyHero(),
                      ],
                    ),
                  ),
                ),

              // Categories Horizontal List (Incident Categories)
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
                        avatar: category == 'Semua'
                            ? null
                            : Icon(
                                Icons.warning_amber_rounded,
                                size: 14,
                                color: selected ? Colors.white : const Color(0xFFEF4444),
                              ),
                        label: Text(category),
                        selected: selected,
                        showCheckmark: false,
                        side: BorderSide(
                          color: selected ? _blue : const Color(0xFFE4EAF2),
                          width: selected ? 1.4 : 1,
                        ),
                        backgroundColor: Colors.white,
                        selectedColor: _blue,
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : const Color(0xFF475467),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        onSelected: (_) {
                          HapticFeedback.selectionClick();
                          setState(() => _category = category);
                        },
                      );
                    },
                  ),
                ),
              ),

              // Sub-header
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Text(
                        _category == 'Semua'
                            ? 'Laporan Insiden Terbaru'
                            : 'Insiden: $_category',
                        style: const TextStyle(
                          color: Color(0xFF101828),
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      if (_isLoadingIncidents)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),
              ),

              // Updates List
              if (_visibleUpdates.isEmpty && !_isLoadingIncidents)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.shield_outlined, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(
                          'Tidak ada laporan pada kategori $_category',
                          style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 120),
                  sliver: SliverList.separated(
                    itemCount: _visibleUpdates.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _UpdateCard(
                      update: _visibleUpdates[index],
                      onTap: () => _showUpdate(_visibleUpdates[index]),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

  /// Header Bersih & Aksi Refresh Feed
  Widget _buildTopHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Safety Updates',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Warta K3 & Buletin Operasional Tambang',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              _fetchIncidents();
            },
            tooltip: 'Segarkan Feed',
            icon: _isLoadingIncidents
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Icon(
                    Icons.refresh_rounded,
                    color: Color(0xFF1E3A8A),
                    size: 22,
                  ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showUpdate(_SafetyUpdate update) {
    HapticFeedback.selectionClick();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: .75,
        minChildSize: .50,
        maxChildSize: .94,
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

              // Image / Stylized Incident Header
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: update.imageUrl != null && update.imageUrl!.isNotEmpty
                    ? Image.network(
                        update.imageUrl!.startsWith('http')
                            ? update.imageUrl!
                            : '${_api.baseUrl}${update.imageUrl}',
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildIncidentFallbackImage(update),
                      )
                    : _buildIncidentFallbackImage(update),
              ),

              const SizedBox(height: 18),
              _CategoryBadge(update: update),
              const SizedBox(height: 12),

              Text(
                update.title,
                style: const TextStyle(
                  color: Color(0xFF101828),
                  fontSize: 21,
                  height: 1.2,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),

              const SizedBox(height: 12),
              _UpdateMeta(update: update),
              const SizedBox(height: 14),

              // Location & Reporter chips (if from incident)
              if (update.location != null || update.reporter != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      if (update.location != null)
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded, color: Color(0xFFEF4444), size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Lokasi: ${update.location}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (update.location != null && update.reporter != null)
                        const Divider(height: 12),
                      if (update.reporter != null)
                        Row(
                          children: [
                            const Icon(Icons.person_pin_rounded, color: Color(0xFF2563EB), size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Pelapor / PIC: ${update.reporter}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Konten Deskripsi & Kronologi
              const Text(
                'Kronologi & Rekomendasi Keselamatan:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                update.summary,
                style: const TextStyle(
                  color: Color(0xFF334155),
                  fontSize: 14.5,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIncidentFallbackImage(_SafetyUpdate update) {
    return Container(
      height: 190,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            update.color.withValues(alpha: 0.85),
            const Color(0xFF0F172A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(update.icon, size: 54, color: Colors.white.withValues(alpha: 0.9)),
            const SizedBox(height: 10),
            Text(
              'INFORMASI INSIDEN RESMI',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== HERO UPDATE COMPONENT (CONNECTED TO /Incident/Index) ====================
class _HeroUpdate extends StatelessWidget {
  const _HeroUpdate({
    required this.update,
    this.isIncidentTab = false,
    this.onTap,
  });

  final _SafetyUpdate update;
  final bool isIncidentTab;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 220,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: (isIncidentTab ? const Color(0xFFDC2626) : const Color(0xFF0F172A))
                    .withValues(alpha: 0.22),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background Image / Gradient
              if (update.imageUrl != null && update.imageUrl!.isNotEmpty)
                Image.network(
                  update.imageUrl!.startsWith('http')
                      ? update.imageUrl!
                      : '${ApiService().baseUrl}${update.imageUrl}',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildHeroGradientBackground(),
                )
              else
                Image.asset(update.image, fit: BoxFit.cover),

              // Gradient Overlay
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0x30000000),
                      (isIncidentTab ? const Color(0xF0180B0B) : const Color(0xEE0F172A)),
                    ],
                    stops: const [.25, 1],
                  ),
                ),
              ),

              // Content Details
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _CategoryBadge(update: update, light: true),
                        if (update.isLatest) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFEF4444), Color(0xFFF97316)],
                              ),
                              borderRadius: BorderRadius.circular(7),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFEF4444).withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 12),
                                SizedBox(width: 3),
                                Text(
                                  'TERBARU',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const Spacer(),

                    // Incident Title
                    Text(
                      update.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18.5,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Incident Summary
                    Text(
                      update.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontSize: 11.5,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Location & Date Row
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, color: Colors.white70, size: 13),
                        const SizedBox(width: 4),
                        Text(
                          update.location ?? 'Area Kerja',
                          style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        const Text('•', style: TextStyle(color: Colors.white54)),
                        const SizedBox(width: 8),
                        Text(
                          '${update.date} ${update.time}',
                          style: const TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                        const Spacer(),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.2),
                            border: Border.all(color: Colors.white38),
                          ),
                          child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                        ),
                      ],
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

  Widget _buildHeroGradientBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            update.color,
            const Color(0xFF0F172A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(update.icon, size: 70, color: Colors.white.withValues(alpha: 0.12)),
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
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: update.isFromIncidentServer
                  ? update.color.withValues(alpha: 0.25)
                  : const Color(0xFFEAECF0),
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: (update.isFromIncidentServer ? update.color : Colors.black)
                    .withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 78,
                  height: 78,
                  color: update.color.withValues(alpha: .1),
                  child: update.imageUrl != null && update.imageUrl!.isNotEmpty
                      ? Image.network(
                          update.imageUrl!.startsWith('http')
                              ? update.imageUrl!
                              : '${ApiService().baseUrl}${update.imageUrl}',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Icon(update.icon, color: update.color, size: 30),
                          ),
                        )
                      : Center(
                          child: Icon(update.icon, color: update.color, size: 32),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _CategoryBadge(update: update),
                        if (update.isLatest) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFEF4444), Color(0xFFF97316)],
                              ),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                                  blurRadius: 6,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 10),
                                SizedBox(width: 2),
                                Text(
                                  'TERBARU',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      update.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF101828),
                        fontSize: 13.5,
                        height: 1.2,
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
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _UpdateMeta(update: update),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 26),
                child: Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: light ? update.color : update.color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            update.icon,
            size: 11,
            color: light ? Colors.white : update.color,
          ),
          const SizedBox(width: 4),
          Text(
            update.label,
            style: TextStyle(
              color: light ? Colors.white : update.color,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: .4,
            ),
          ),
        ],
      ),
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
        const Icon(Icons.calendar_today_rounded, size: 11, color: Color(0xFF98A2B3)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            '${update.date} • ${update.time}',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF98A2B3), fontSize: 9.5, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.visibility_outlined, size: 12, color: Color(0xFF98A2B3)),
        const SizedBox(width: 3),
        Text(
          update.views,
          style: const TextStyle(color: Color(0xFF98A2B3), fontSize: 9.5),
        ),
      ],
    );
  }
}

class _SafetyUpdate {
  const _SafetyUpdate({
    this.id,
    required this.category,
    this.rawCategory = '',
    required this.label,
    required this.title,
    required this.summary,
    required this.date,
    required this.time,
    required this.views,
    required this.image,
    this.imageUrl,
    required this.color,
    required this.icon,
    this.location,
    this.reporter,
    this.isFromIncidentServer = false,
    this.isLatest = false,
  });

  final int? id;
  final String category;
  final String rawCategory;
  final String label;
  final String title;
  final String summary;
  final String date;
  final String time;
  final String views;
  final String image;
  final String? imageUrl;
  final Color color;
  final IconData icon;
  final String? location;
  final String? reporter;
  final bool isFromIncidentServer;
  final bool isLatest;
}

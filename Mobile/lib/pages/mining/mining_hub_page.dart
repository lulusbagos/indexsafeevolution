import 'package:flutter/material.dart';
import '../../services/preference.dart';

class MiningHubPage extends StatefulWidget {
  const MiningHubPage({super.key});

  @override
  State<MiningHubPage> createState() => _MiningHubPageState();
}

class _MiningHubPageState extends State<MiningHubPage> {
  String _myName = 'LULUS BAGOS HERMAWAN';
  String _myDept = 'SYSTEM INTEGRATIONS';

  // Active Category Filter Tab
  int _selectedTabIndex = 0;
  final List<String> _tabs = [
    'Semua',
    'Pit & Geotek',
    'Water & Sump',
    'CPP & Plant',
    'Hauling & Barging',
  ];

  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  // Set of subscribed module notifications
  final Set<String> _subscribedModules = {};

  @override
  void initState() {
    super.initState();
    final profile = PreferenceService.getProfile();
    _myName = profile?.namaLengkap ?? _myName;
    _myDept = profile?.depart ?? _myDept;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showComingSoonModal(MiningMenuItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isSubscribed = _subscribedModules.contains(item.title);

            return Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x1F000000),
                    blurRadius: 30,
                    spreadRadius: 2,
                    offset: Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header Badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt_rounded, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'COMING SOON • TAHAP RANCANG BANGUN',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Module Title & Icon
                  Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [item.gradientStart, item.gradientEnd],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: item.gradientStart.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(item.icon, color: Colors.white, size: 28),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.categoryLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: item.gradientStart,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Description Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      item.description,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF475569),
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Telemetry Specifications Title
                  const Text(
                    'Spesifikasi Telemetri & Sensor IoT Terintegrasi:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // IoT Sensor Chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: item.iotFeatures.map((feat) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBAE6FD)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.sensors_rounded, size: 13, color: Color(0xFF0284C7)),
                            const SizedBox(width: 5),
                            Text(
                              feat,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0369A1),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 22),

                  // CTA Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSubscribed ? const Color(0xFF059669) : const Color(0xFF0284C7),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      icon: Icon(
                        isSubscribed ? Icons.notifications_active_rounded : Icons.notification_add_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      label: Text(
                        isSubscribed ? 'Notifikasi Aktif (Akan Diberitahu Saat Rilis)' : 'Ingatkan Saya Saat Fitur Ini Rilis',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          if (isSubscribed) {
                            _subscribedModules.remove(item.title);
                          } else {
                            _subscribedModules.add(item.title);
                          }
                        });
                        setModalState(() {});
                        _showToast(
                          isSubscribed
                              ? 'Pengingat untuk ${item.title} dinonaktifkan.'
                              : 'Pengingat berhasil diaktifkan! Anda akan menerima notifikasi saat modul ini dirilis.',
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Clean slate 50
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                    ),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Text(
                    'X MINE',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Mining Operations Suite',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            const Text(
              'End-to-End Hulu ke Hilir Tambang • PT Indexim Coalindo',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, color: Color(0xFF64748B)),
            onPressed: () => _showAboutModal(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Clean Modern Hero Banner
            _buildCleanHeroBanner(),

            const SizedBox(height: 14),

            // 2. Clean Search Bar
            _buildCleanSearchBar(),

            const SizedBox(height: 14),

            // 3. Segmented Filter Tabs
            _buildCategoryFilterTabs(),

            const SizedBox(height: 16),

            // 4. Categorized Sections (GoPay Style Cards)
            ..._buildCategorizedSections(),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildCleanHeroBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo Container
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    'assets/images/home-mining-ops.png',
                    fit: BoxFit.contain,
                    errorBuilder: (ctx, _, __) => const Icon(
                      Icons.terrain_rounded,
                      color: Color(0xFFD97706),
                      size: 32,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'FASE 4.0 • COMING SOON',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFB45309),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'X-MINE OPERATIONS',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Arsitektur Telemetri Hulu ke Hilir Tambang',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Seluruh rangkaian operasional terpadu: dari Pit Tambang, Geoteknik Lereng, Sump & Settling Pond, CPP Crushing, hingga Jalur Hauling dan Pengapalan Tongkang (Barging).',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: Color(0xFF475569),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatPill('18 Modul', 'Hulu ke Hilir', const Color(0xFF0284C7)),
                _buildStatDivider(),
                _buildStatPill('5 Tahapan', 'Rantai Nilai', const Color(0xFFD97706)),
                _buildStatDivider(),
                _buildStatPill('IoT Live', 'Rancang Bangun', const Color(0xFF059669)),
                _buildStatDivider(),
                _buildStatPill('Q3 2026', 'Target Rilis', const Color(0xFF7C3AED)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(String value, String label, Color accentColor) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
            color: accentColor,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 20,
      color: const Color(0xFFCBD5E1),
    );
  }

  Widget _buildCleanSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
        decoration: InputDecoration(
          hintText: 'Cari modul (PIT, Sump, Settling Pond, CPP, Hauling, Barging)...',
          hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF0284C7), size: 22),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildCategoryFilterTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List.generate(_tabs.length, (idx) {
          final isSelected = _selectedTabIndex == idx;
          return Padding(
            padding: EdgeInsets.only(right: idx == _tabs.length - 1 ? 0 : 8),
            child: InkWell(
              onTap: () => setState(() => _selectedTabIndex = idx),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : const [
                          BoxShadow(
                            color: Color(0x04000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                ),
                child: Text(
                  _tabs[idx],
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  List<Widget> _buildCategorizedSections() {
    final List<Widget> sections = [];

    // SECTION 1: PIT TAMBANG & EKSTRAKSI (HULU)
    if (_matchesTab(1)) {
      final items = [
        MiningMenuItem(
          title: 'Pit Geometry & 3D',
          categoryLabel: 'HULU • PIT TAMBANG',
          icon: Icons.architecture_rounded,
          gradientStart: const Color(0xFFD97706),
          gradientEnd: const Color(0xFFF59E0B),
          badge: 'SOON',
          description:
              'Pemodelan batas penambangan (pit limit), desain jenjang (bench), lereng tambang, dan rencana kemajuan tambang jangka pendek & panjang.',
          iotFeatures: ['Surpac / Minex Integration', 'Drone LiDAR 3D Topography', 'Orebody Block Model'],
        ),
        MiningMenuItem(
          title: 'Drilling & Blasting',
          categoryLabel: 'HULU • PIT TAMBANG',
          icon: Icons.flash_on_rounded,
          gradientStart: const Color(0xFFDC2626),
          gradientEnd: const Color(0xFFEF4444),
          badge: 'SOON',
          description:
              'Pola pemboran dan peledakan, perhitungan powder factor, pemantauan getaran blasting, serta fragmentasi batuan hasil ledakan.',
          iotFeatures: ['Blast Vibration Seismograph', 'Drill Depth Smart Sensor', 'AI Rock Fragmentation Vision'],
        ),
        MiningMenuItem(
          title: 'Overburden Stripping',
          categoryLabel: 'HULU • PIT TAMBANG',
          icon: Icons.landscape_rounded,
          gradientStart: const Color(0xFF0284C7),
          gradientEnd: const Color(0xFF38BDF8),
          badge: 'SOON',
          description:
              'Manajemen pengupasan lapisan tanah penutup (OB), alokasi fleet excavator & dump truck overburden menuju disposal area.',
          iotFeatures: ['Payload Monitor Realtime', 'Haul Cycle Time Analyzer', 'Disposal Dump Sensor'],
        ),
        MiningMenuItem(
          title: 'Clean Coal (CCM)',
          categoryLabel: 'HULU • PIT TAMBANG',
          icon: Icons.cleaning_services_rounded,
          gradientStart: const Color(0xFF059669),
          gradientEnd: const Color(0xFF34D399),
          badge: 'SOON',
          description:
              'Pembersihan dan kontrol parting clay dari lapisan batubara untuk memastikan kadar abu (ash content) tetap di bawah 6.5%.',
          iotFeatures: ['Spectrometer Ash Scanner', 'Coal Exposed Surface Cam', 'Parting Loss Estimator'],
        ),
        MiningMenuItem(
          title: 'Fleet Dispatch Telemetry',
          categoryLabel: 'HULU • PIT TAMBANG',
          icon: Icons.hub_rounded,
          gradientStart: const Color(0xFF7C3AED),
          gradientEnd: const Color(0xFFA78BFA),
          badge: 'SOON',
          description:
              'Sistem dispatch otomatis armada alat berat, optimasi rute ritase, antrean loader, dan waktu tunggu (queuing time) di pit.',
          iotFeatures: ['GPS Fleet Telematics 1Hz', 'Excavator Queue Optimizer', 'Fuel Level Telemetry'],
        ),
      ];
      final filtered = _filterItems(items);
      if (filtered.isNotEmpty) {
        sections.add(_buildGoPaySectionCard(
          title: 'Pit Tambang & Ekstraksi',
          subtitle: 'Perencanaan jenjang, pemboran, peledakan & pemuatan batubara',
          icon: Icons.terrain_rounded,
          accentColor: const Color(0xFFD97706),
          items: filtered,
        ));
        sections.add(const SizedBox(height: 16));
      }
    }

    // SECTION 2: GEOTEKNIK & KESTABILAN LERENG
    if (_matchesTab(1)) {
      final items = [
        MiningMenuItem(
          title: 'Slope Stability Radar',
          categoryLabel: 'HULU • GEOTEKNIK LERENG',
          icon: Icons.radar_rounded,
          gradientStart: const Color(0xFFEA580C),
          gradientEnd: const Color(0xFFF97316),
          badge: 'SOON',
          description:
              'Pemantauan radar SSR 24/7 terhadap deformasi mikro dinding lereng pit (sub-milimeter) untuk mendeteksi potensi longsor secara dini.',
          iotFeatures: ['Reutech / GroundProbe Radar', 'Sub-millimeter Displacement', 'Slope Velocity Heatmap'],
        ),
        MiningMenuItem(
          title: 'Prisma Deformasi',
          categoryLabel: 'HULU • GEOTEKNIK LERENG',
          icon: Icons.filter_center_focus_rounded,
          gradientStart: const Color(0xFF0284C7),
          gradientEnd: const Color(0xFF38BDF8),
          badge: 'SOON',
          description:
              'Jaringan prisma reflektor otomatis (Robotic Total Station) dan inclinometer untuk pengukuran pergeseran tanah horizontal dan vertikal.',
          iotFeatures: ['Automated Motorized Total Station', 'Inclinometer Multi-depth', 'GNSS RTK Base Station'],
        ),
        MiningMenuItem(
          title: 'Analisis FoS Lereng',
          categoryLabel: 'HULU • GEOTEKNIK LERENG',
          icon: Icons.analytics_rounded,
          gradientStart: const Color(0xFF7C3AED),
          gradientEnd: const Color(0xFFA78BFA),
          badge: 'SOON',
          description:
              'Perhitungan Faktor Keamanan (FoS) lereng tunggal dan lereng keseluruhan berbasis parameter kekuatan batuan dan air pori.',
          iotFeatures: ['VWP Piezometer Pori', 'Limit Equilibrium Solver', 'Borehole Extensometer'],
        ),
        MiningMenuItem(
          title: 'Early Warning (EWS)',
          categoryLabel: 'HULU • GEOTEKNIK LERENG',
          icon: Icons.warning_amber_rounded,
          gradientStart: const Color(0xFFDC2626),
          gradientEnd: const Color(0xFFEF4444),
          badge: 'SOON',
          description:
              'Alarm peringatan dini otomatis pergerakan tanah kritis, penentuan zona bahaya, dan sirene evakuasi pit darurat.',
          iotFeatures: ['Automated Siren Broadcast', 'Push Alert Geoteknik', 'Geofence Evacuation Map'],
        ),
      ];
      final filtered = _filterItems(items);
      if (filtered.isNotEmpty) {
        sections.add(_buildGoPaySectionCard(
          title: 'Geoteknik & Kestabilan Lereng',
          subtitle: 'Radar kestabilan lereng, prisma deformasi, dan alarm peringatan dini',
          icon: Icons.shield_rounded,
          accentColor: const Color(0xFFEA580C),
          items: filtered,
        ));
        sections.add(const SizedBox(height: 16));
      }
    }

    // SECTION 3: WATER & ENVIRONMENT • SUMP & SETTLING POND
    if (_matchesTab(2)) {
      final items = [
        MiningMenuItem(
          title: 'Central Sump Level',
          categoryLabel: 'WATER MANAGEMENT & SUMP',
          icon: Icons.water_drop_rounded,
          gradientStart: const Color(0xFF0284C7),
          gradientEnd: const Color(0xFF38BDF8),
          badge: 'SOON',
          description:
              'Pemantauan ketinggian muka air sump pit (RL air), estimasi volume genangan (m³), dan kapasitas tampung sebelum overflow.',
          iotFeatures: ['Ultrasonic Level Sensor', 'Radar Level Transmitter', 'Sump Bathymetry 3D'],
        ),
        MiningMenuItem(
          title: 'Dewatering Pump',
          categoryLabel: 'WATER MANAGEMENT & SUMP',
          icon: Icons.speed_rounded,
          gradientStart: const Color(0xFF0891B2),
          gradientEnd: const Color(0xFF06B6D4),
          badge: 'SOON',
          description:
              'Monitoring status pompa tambang (Sulzer, Multiflo, Sykes), debit aliran (liter/detik), RPM mesin, tekanan pipa, dan bahan bakar.',
          iotFeatures: ['Magnetic Flowmeter Live', 'Pump Engine RPM CAN-Bus', 'Pressure Discharge Gauge'],
        ),
        MiningMenuItem(
          title: 'Settling Pond',
          categoryLabel: 'WATER MANAGEMENT & SUMP',
          icon: Icons.waves_rounded,
          gradientStart: const Color(0xFF0D9488),
          gradientEnd: const Color(0xFF14B8A6),
          badge: 'SOON',
          description:
              'Pengelolaan kompartemen kolam pengendap sedimen tambang, waktu retensi air limpasan, dan jadwal pengerukan lumpur.',
          iotFeatures: ['Sediment Depth Sonar', 'Pond Inflow-Outflow Ratio', 'Desilting Fleet Tracking'],
        ),
        MiningMenuItem(
          title: 'Kualitas Air Live',
          categoryLabel: 'WATER MANAGEMENT & SUMP',
          icon: Icons.biotech_rounded,
          gradientStart: const Color(0xFF059669),
          gradientEnd: const Color(0xFF10B981),
          badge: 'SOON',
          description:
              'Sensor online parameter baku mutu lingkungan hidup di titik penaatan outflow: pH air (6–9), TSS (< 300 mg/L), Fe, dan Mn.',
          iotFeatures: ['Digital pH Probe Live', 'Turbidity / TSS Optical Sensor', 'Telemetri KLHK Resmi'],
        ),
        MiningMenuItem(
          title: 'Chemical Dosing',
          categoryLabel: 'WATER MANAGEMENT & SUMP',
          icon: Icons.science_rounded,
          gradientStart: const Color(0xFF7C3AED),
          gradientEnd: const Color(0xFF8B5CF6),
          badge: 'SOON',
          description:
              'Pengaturan otomatis takaran kapur tohor (CaO) dan tawas (Alum) untuk netralisasi Air Asam Tambang (AAT) secara presisi.',
          iotFeatures: ['Automated Lime Feeder', 'Smart Dosing Pump Controller', 'Chemical Consumption Log'],
        ),
        MiningMenuItem(
          title: 'Rainfall & Catchment',
          categoryLabel: 'WATER MANAGEMENT & SUMP',
          icon: Icons.cloud_queue_rounded,
          gradientStart: const Color(0xFF475569),
          gradientEnd: const Color(0xFF64748B),
          badge: 'SOON',
          description:
              'Stasiun cuaca telemetri curah hujan (AWS), perhitungan debit limpasan air hujan, dan kapasitas saluran diversi keliling pit.',
          iotFeatures: ['Tipping Bucket Rain Gauge', 'Catchment Basin Modeler', 'Drainage Channel Sensor'],
        ),
      ];
      final filtered = _filterItems(items);
      if (filtered.isNotEmpty) {
        sections.add(_buildGoPaySectionCard(
          title: 'Sump, Settling Pond & Water',
          subtitle: 'Pemantauan sump, pompa dewatering, kolam sedimen & kualitas air live',
          icon: Icons.water_rounded,
          accentColor: const Color(0xFF0284C7),
          items: filtered,
        ));
        sections.add(const SizedBox(height: 16));
      }
    }

    // SECTION 4: PROCESSING • CPP & ROM STOCKPILE
    if (_matchesTab(3)) {
      final items = [
        MiningMenuItem(
          title: 'ROM Stockpile',
          categoryLabel: 'CPP & COAL PROCESSING',
          icon: Icons.layers_rounded,
          gradientStart: const Color(0xFFD97706),
          gradientEnd: const Color(0xFFF59E0B),
          badge: 'SOON',
          description:
              'Kapasitas timbunan batubara ROM pit, pemetaan nomor seam/kualitas kalori, dan pengaturan sistem First-In First-Out (FIFO).',
          iotFeatures: ['Laser Scanner Volume Timbunan', 'Seam Allocation Tracker', 'FIFO Age Monitoring'],
        ),
        MiningMenuItem(
          title: 'Crushing Plant',
          categoryLabel: 'CPP & COAL PROCESSING',
          icon: Icons.precision_manufacturing_rounded,
          gradientStart: const Color(0xFFEA580C),
          gradientEnd: const Color(0xFFF97316),
          badge: 'SOON',
          description:
              'Laju pengumpanan batubara (TPH), efisiensi pemecahan batubara pada primary crusher, dan beban ampere motor listrik.',
          iotFeatures: ['Feeder Speed Inverter', 'Motor Current Telemetry', 'Choke Feeder Sensor'],
        ),
        MiningMenuItem(
          title: 'Sizing Screen',
          categoryLabel: 'CPP & COAL PROCESSING',
          icon: Icons.filter_alt_rounded,
          gradientStart: const Color(0xFF059669),
          gradientEnd: const Color(0xFF10B981),
          badge: 'SOON',
          description:
              'Pemisahan fraksi ukuran batubara produk crushed coal (0–50 mm) dan pemantauan getaran screen deck pencegah blinding.',
          iotFeatures: ['Screen Vibration Accelerometer', 'Product Size AI Cam', 'Oversize Return Loop'],
        ),
        MiningMenuItem(
          title: 'Conveyor Scale',
          categoryLabel: 'CPP & COAL PROCESSING',
          icon: Icons.linear_scale_rounded,
          gradientStart: const Color(0xFF0284C7),
          gradientEnd: const Color(0xFF38BDF8),
          badge: 'SOON',
          description:
              'Timbangan digital weightometer konveyor batubara terkalibrasi, tonase per jam live, dan sensor metal detector proteksi belt.',
          iotFeatures: ['Belt Scale Weightometer', 'Metal Detector Trip Sensor', 'Belt Misalignment Switch'],
        ),
        MiningMenuItem(
          title: 'Hotspot Thermal',
          categoryLabel: 'CPP & COAL PROCESSING',
          icon: Icons.local_fire_department_rounded,
          gradientStart: const Color(0xFFDC2626),
          gradientEnd: const Color(0xFFEF4444),
          badge: 'SOON',
          description:
              'Kamera thermal inframerah 360° untuk mendeteksi titik panas (hotspot) batubara di stockpile dan mencegah swa-bakar dini.',
          iotFeatures: ['Thermal IR Panoramic Cam', 'Gas CO Sensor Array', 'Water Mist Sprinkler Trigger'],
        ),
      ];
      final filtered = _filterItems(items);
      if (filtered.isNotEmpty) {
        sections.add(_buildGoPaySectionCard(
          title: 'CPP (Coal Processing) & Stockpile',
          subtitle: 'Pengolahan batubara, crusher, sizing screen, conveyor & kontrol hotspot',
          icon: Icons.settings_suggest_rounded,
          accentColor: const Color(0xFF7C3AED),
          items: filtered,
        ));
        sections.add(const SizedBox(height: 16));
      }
    }

    // SECTION 5: HAULING ROAD, JEMBATAN TIMBANG & BARGING (HILIR)
    if (_matchesTab(4)) {
      final items = [
        MiningMenuItem(
          title: 'Hauling KM 0-48',
          categoryLabel: 'HILIR • HAULING & PORT',
          icon: Icons.alt_route_rounded,
          gradientStart: const Color(0xFFD97706),
          gradientEnd: const Color(0xFFF59E0B),
          badge: 'SOON',
          description:
              'Monitoring kondisi jalan angkut tambang sepanjang 48 KM, deteksi lubang (potholes), superelevasi tikungan, dan gradien jalan.',
          iotFeatures: ['AI Dashcam Road Profiler', 'Corridor Speed Sensor', 'Bridge Load Cell Sensor'],
        ),
        MiningMenuItem(
          title: 'Dust Suppression',
          categoryLabel: 'HILIR • HAULING & PORT',
          icon: Icons.opacity_rounded,
          gradientStart: const Color(0xFF0284C7),
          gradientEnd: const Color(0xFF38BDF8),
          badge: 'SOON',
          description:
              'Penjadwalan otomatis armada Water Truck penyiram jalan debu, sensor kelembaban jalan, dan efisiensi chemical dust suppressant.',
          iotFeatures: ['Road Dust PM10 Particle Sensor', 'Water Truck Telematics Flow', 'Smart Sprayer GPS Trigger'],
        ),
        MiningMenuItem(
          title: 'Speed & Fatigue AI',
          categoryLabel: 'HILIR • HAULING & PORT',
          icon: Icons.speed_rounded,
          gradientStart: const Color(0xFFDC2626),
          gradientEnd: const Color(0xFFEF4444),
          badge: 'SOON',
          description:
              'Speed radar kecepatan truk hauling di koridor rawan dan kamera AI pendeteksi kelelahan/kantuk pengemudi (Driver Fatigue).',
          iotFeatures: ['Doppler Speed Radar Camera', 'In-Cabin AI Fatigue Cam', 'Automated Over-speed Warning'],
        ),
        MiningMenuItem(
          title: 'Jembatan Timbang',
          categoryLabel: 'HILIR • HAULING & PORT',
          icon: Icons.scale_rounded,
          gradientStart: const Color(0xFF059669),
          gradientEnd: const Color(0xFF10B981),
          badge: 'SOON',
          description:
              'Jembatan timbang (weighbridge) otomatis keluar pit menuju port, pembacaan RFID truk, dan audit kelebihan muatan (overload).',
          iotFeatures: ['Digital Load Cell 100T', 'RFID Truck Scanner Auto', 'ANPR License Plate Cam'],
        ),
        MiningMenuItem(
          title: 'Port & Blending',
          categoryLabel: 'HILIR • HAULING & PORT',
          icon: Icons.calculate_rounded,
          gradientStart: const Color(0xFF7C3AED),
          gradientEnd: const Color(0xFFA78BFA),
          badge: 'SOON',
          description:
              'Pengaturan tumpukan batubara pelabuhan dan kalkulator otomatis pencampuran (blending) kalori batubara sesuai kontrak pembeli.',
          iotFeatures: ['Quality Coal Matrix DB', 'Automated Blending Solver', 'Stockpile Age Expiry Alert'],
        ),
        MiningMenuItem(
          title: 'Barge Loading (BLC)',
          categoryLabel: 'HILIR • HAULING & PORT',
          icon: Icons.directions_boat_filled_rounded,
          gradientStart: const Color(0xFF0284C7),
          gradientEnd: const Color(0xFF38BDF8),
          badge: 'SOON',
          description:
              'Telemetri laju pemuatan batubara jet conveyor ke palka tongkang (1.200 Ton/Jam), boom angle, dan pasang surut dermaga.',
          iotFeatures: ['Conveyor Speed SCADA Live', 'Tide Gauge Water Sensor', 'Chute Trimming Controller'],
        ),
        MiningMenuItem(
          title: 'AIS Radar Tongkang',
          categoryLabel: 'HILIR • HAULING & PORT',
          icon: Icons.sailing_rounded,
          gradientStart: const Color(0xFF0D9488),
          gradientEnd: const Color(0xFF14B8A6),
          badge: 'SOON',
          description:
              'Pelacakan satelit AIS posisi tongkang 300 feet, estimasi waktu sandar (ETA), antrean tambat dermaga, dan alokasi tugboat.',
          iotFeatures: ['Live Marine AIS Satellite', 'Berthing Queue Optimizer', 'Barge Cargo Manifest API'],
        ),
        MiningMenuItem(
          title: 'Draught Survey Cert',
          categoryLabel: 'HILIR • HAULING & PORT',
          icon: Icons.verified_rounded,
          gradientStart: const Color(0xFF059669),
          gradientEnd: const Color(0xFF34D399),
          badge: 'SOON',
          description:
              'Pencatatan sarat kapal draught survey surveyor independen, perhitungan tonase final pengapalan, dan sertifikat kualitas COA.',
          iotFeatures: ['Draft Mark Optical Sensor', 'Density Water Hydrometer', 'Digital COA Exporter'],
        ),
      ];
      final filtered = _filterItems(items);
      if (filtered.isNotEmpty) {
        sections.add(_buildGoPaySectionCard(
          title: 'Hauling Road & Port Barging',
          subtitle: 'Jalan hauling, jembatan timbang, stockpile pelabuhan & tongkang',
          icon: Icons.local_shipping_rounded,
          accentColor: const Color(0xFF0284C7),
          items: filtered,
        ));
        sections.add(const SizedBox(height: 16));
      }
    }

    if (sections.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              const Icon(Icons.search_off_rounded, size: 48, color: Color(0xFF94A3B8)),
              const SizedBox(height: 10),
              const Text(
                'Modul Tidak Ditemukan',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 4),
              Text(
                'Tidak ada modul yang cocok dengan kata kunci "$_searchQuery".',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ];
    }

    return sections;
  }

  bool _matchesTab(int tabIndex) {
    if (_selectedTabIndex == 0) return true; // Tab Semua
    return _selectedTabIndex == tabIndex;
  }

  List<MiningMenuItem> _filterItems(List<MiningMenuItem> items) {
    if (_searchQuery.isEmpty) return items;
    return items.where((it) {
      return it.title.toLowerCase().contains(_searchQuery) ||
          it.categoryLabel.toLowerCase().contains(_searchQuery) ||
          it.description.toLowerCase().contains(_searchQuery) ||
          it.iotFeatures.any((f) => f.toLowerCase().contains(_searchQuery));
    }).toList();
  }

  // GoPay Style Categorized Card Container
  Widget _buildGoPaySectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required List<MiningMenuItem> items,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 14,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // GoPay Section Header with Arrow (>)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Text(
                    'COMING SOON',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFB45309),
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF94A3B8),
                  size: 20,
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // 4-Column Grid of Cool Menu Icons (GoPay Grid Style)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 16,
                crossAxisSpacing: 6,
                childAspectRatio: 0.72,
              ),
              itemCount: items.length,
              itemBuilder: (ctx, idx) => _buildGoPayItemTile(items[idx]),
            ),
          ),
        ],
      ),
    );
  }

  // Cool GoPay Style Icon Tile with Rounded Squircle, Gradient & SOON Badge
  Widget _buildGoPayItemTile(MiningMenuItem item) {
    return InkWell(
      onTap: () => _showComingSoonModal(item),
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Icon Box with Badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Squircle Container
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [item.gradientStart, item.gradientEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: item.gradientStart.withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    item.icon,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),

              // SOON badge like "BERHADIAH" in GoPay
              Positioned(
                bottom: -4,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white, width: 1),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x26000000),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      item.badge,
                      style: const TextStyle(
                        fontSize: 7.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),

          // Label Underneath (2 Lines max, GoPay Typography)
          Text(
            item.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
              height: 1.22,
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.hub_rounded, color: Color(0xFFD97706), size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Tentang Modul X-MINE',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Modul X-MINE merupakan platform terpadu operasional pertambangan batubara PT Indexim Coalindo yang mengintegrasikan data dari pit hingga pelabuhan pengapalan batubara.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.4),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.construction_rounded, color: Color(0xFFD97706), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tahap Rancang Bangun: Seluruh menu saat ini berstatus Coming Soon dengan target implementasi bertahap pada Q3 2026.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class MiningMenuItem {
  final String title;
  final String categoryLabel;
  final IconData icon;
  final Color gradientStart;
  final Color gradientEnd;
  final String badge;
  final String description;
  final List<String> iotFeatures;

  MiningMenuItem({
    required this.title,
    required this.categoryLabel,
    required this.icon,
    required this.gradientStart,
    required this.gradientEnd,
    required this.badge,
    required this.description,
    required this.iotFeatures,
  });
}

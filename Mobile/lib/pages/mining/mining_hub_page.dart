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
    final isSubscribed = _subscribedModules.contains(item.title);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final currentSubscribed = _subscribedModules.contains(item.title);

            return Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A), // Deep Slate Titanium
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.4), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                    blurRadius: 30,
                    spreadRadius: 2,
                    offset: const Offset(0, -6),
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
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Header Badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFD97706), Color(0xFFB45309)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD97706).withValues(alpha: 0.4),
                              blurRadius: 10,
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
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Module Title & Icon
                  Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: item.iconColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: item.iconColor.withValues(alpha: 0.4)),
                        ),
                        child: Center(
                          child: Icon(item.icon, color: item.iconColor, size: 28),
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
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.categoryLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF38BDF8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Full Functional Description
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Text(
                      item.description,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Planned IoT & Telemetry Features
                  Text(
                    'Spesifikasi Telemetri & Sensor IoT Terintegrasi:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: item.iotFeatures.map((feat) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.sensors_rounded, size: 12, color: Color(0xFF38BDF8)),
                            const SizedBox(width: 5),
                            Text(
                              feat,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFBAE6FD),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // CTA Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: currentSubscribed ? const Color(0xFF059669) : const Color(0xFF0284C7),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      icon: Icon(
                        currentSubscribed ? Icons.notifications_active_rounded : Icons.notification_add_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      label: Text(
                        currentSubscribed ? 'Notifikasi Aktif (Akan Diberitahu Saat Rilis)' : 'Ingatkan Saya Saat Fitur Ini Rilis',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          if (currentSubscribed) {
                            _subscribedModules.remove(item.title);
                          } else {
                            _subscribedModules.add(item.title);
                          }
                        });
                        setModalState(() {});
                        _showToast(
                          currentSubscribed
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
    const bgColor = Color(0xFF0B1120); // Deep High-Tech Obsidian

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 2,
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
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Text(
                    'X MINE',
                    style: TextStyle(
                      fontSize: 12,
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
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'End-to-End Hulu ke Hilir Tambang • PT Indexim Coalindo',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Status Modul',
            icon: const Icon(Icons.info_outline_rounded, color: Color(0xFFFBBF24)),
            onPressed: () {
              _showToast('Seluruh modul X-Mine sedang dalam tahap rancang bangun 4.0 (Coming Soon).');
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
        children: [
          // 1. Futuristic 3D Hero Banner
          _buildFuturisticHeroBanner(),

          const SizedBox(height: 14),

          // 2. High-Tech Search Bar
          _buildFuturisticSearchBar(),

          const SizedBox(height: 14),

          // 3. Segmented Mining Chain Tabs (Hulu ke Hilir)
          _buildSegmentedChainTabs(),

          const SizedBox(height: 16),

          // 4. Mining Modules (Grouped Hulu ke Hilir)
          ..._buildFilteredSections(),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // WIDGETS
  // --------------------------------------------------------------------------

  Widget _buildFuturisticHeroBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF172554)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 3D Futuristic Logo Icon
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.4),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/images/home-mining-ops.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFF59E0B)),
                          ),
                          child: const Text(
                            'FASE 4.0 • COMING SOON',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFFDE047),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'X-MINE OPERATIONS',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Arsitektur Telemetri Hulu ke Hilir Tambang',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Seluruh rangkaian operasional terpadu: dari Pit Tambang, Geoteknik Lereng, Sump & Settling Pond, CPP Crushing, hingga Jalur Hauling dan Pengapalan Tongkang (Barging).',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.38,
              color: Colors.white.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatPill('18 Modul', 'Hulu ke Hilir', const Color(0xFF38BDF8)),
                _buildStatDivider(),
                _buildStatPill('5 Tahapan', 'Rantai Nilai', const Color(0xFFFBBF24)),
                _buildStatDivider(),
                _buildStatPill('IoT Live', 'Rancang Bangun', const Color(0xFF34D399)),
                _buildStatDivider(),
                _buildStatPill('Q3 2026', 'Target Rilis', const Color(0xFFA78BFA)),
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
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 20,
      color: Colors.white.withValues(alpha: 0.15),
    );
  }

  Widget _buildFuturisticSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E293B)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Cari modul (PIT, Sump, Settling Pond, CPP, Hauling, Barging)...',
          hintStyle: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.4), fontWeight: FontWeight.w500),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF38BDF8), size: 22),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white70),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildSegmentedChainTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List.generate(_tabs.length, (index) {
          final isSelected = _selectedTabIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _selectedTabIndex = index),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                        )
                      : null,
                  color: isSelected ? null : const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF1E293B),
                    width: isSelected ? 1.4 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  _tabs[index],
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                    color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.65),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  List<Widget> _buildFilteredSections() {
    final sections = <Widget>[];

    // SECTION 1: HULU 1 • PIT TAMBANG
    if (_matchesTab(1)) {
      final items = [
        MiningMenuItem(
          title: 'Pit Geometry & 3D Design',
          categoryLabel: 'HULU • PIT EXTRACTION',
          icon: Icons.architecture_rounded,
          iconColor: const Color(0xFFF59E0B),
          badge: 'COMING SOON',
          description:
              'Pemodelan geometri pit 3D, elevasi bench, lebar berm, ramp grade hauling pit, dan visualisasi batas boundary penambangan.',
          iotFeatures: ['Drone LiDAR Point-Cloud', 'GPS Geodetik RTK', 'Pit Cut/Fill Surface 3D'],
        ),
        MiningMenuItem(
          title: 'Drilling & Blasting Telemetry',
          categoryLabel: 'HULU • PIT EXTRACTION',
          icon: Icons.flash_on_rounded,
          iconColor: const Color(0xFFEF4444),
          badge: 'COMING SOON',
          description:
              'Perhitungan pola pemboran, kedalaman lubang ledak, Powder Factor (PF), pemantauan seismik getaran peledakan, dan fragmentasi batuan.',
          iotFeatures: ['Seismometer Vibration Live', 'Smart Drill Depth Logger', 'AI Fragmentation Scan'],
        ),
        MiningMenuItem(
          title: 'Overburden (OB) Stripping',
          categoryLabel: 'HULU • PIT EXTRACTION',
          icon: Icons.terrain_rounded,
          iconColor: const Color(0xFF38BDF8),
          badge: 'COMING SOON',
          description:
              'Monitoring volume pengupasan lapisan tanah penutup OB harian, alokasi excavator loader PC2000, dan produktivitas fleet ritase.',
          iotFeatures: ['Payload Weightmeter Loader', 'Fleet Telemetry CAN-Bus', 'BCM Reconciliation API'],
        ),
        MiningMenuItem(
          title: 'Clean Coal Management (CCM)',
          categoryLabel: 'HULU • PIT EXTRACTION',
          icon: Icons.layers_rounded,
          iconColor: const Color(0xFF10B981),
          badge: 'COMING SOON',
          description:
              'Penggalian batubara bersih (Clean Coal Mining), pembersihan parting tanah liat, dan pencegahan kontaminasi ash content.',
          iotFeatures: ['Seam Boundary Sensor', 'Roof & Floor Laser Tracker', 'Online Quality Analyzer'],
        ),
        MiningMenuItem(
          title: 'Fleet Dispatch & Telemetry',
          categoryLabel: 'HULU • PIT EXTRACTION',
          icon: Icons.radar_rounded,
          iconColor: const Color(0xFFA855F7),
          badge: 'COMING SOON',
          description:
              'Sistem otomasi dispatch dump truck, optimasi antrean loader di pit, cycle time pemuatan, dan tracking kecepatan unit.',
          iotFeatures: ['High-Precision GPS Dispatch', 'Automated Loader Pairing', 'Fuel Telemetry Level'],
        ),
      ];
      final filtered = _filterItems(items);
      if (filtered.isNotEmpty) {
        sections.add(_buildSectionCard('1. Pit Tambang & Extraction (Hulu)', filtered));
        sections.add(const SizedBox(height: 14));
      }
    }

    // SECTION 2: HULU 2 • GEOTEKNIK LERENG
    if (_matchesTab(1)) {
      final items = [
        MiningMenuItem(
          title: 'Slope Stability Radar (SSR)',
          categoryLabel: 'HULU • GEOTEKNIK LERENG',
          icon: Icons.biotech_rounded,
          iconColor: const Color(0xFF06B6D4),
          badge: 'COMING SOON',
          description:
              'Pemindaian radar deformasi sub-milimeter pada dinding Highwall & Lowwall tambang secara real-time 24 jam non-stop.',
          iotFeatures: ['SSR-XT Interferometric Radar', 'Sub-mm Velocity Vector', 'Thermal Heatmap Lereng'],
        ),
        MiningMenuItem(
          title: 'Prisma Deformasi Digital',
          categoryLabel: 'HULU • GEOTEKNIK LERENG',
          icon: Icons.track_changes_rounded,
          iconColor: const Color(0xFFF97316),
          badge: 'COMING SOON',
          description:
              'Jaringan prisma pemantauan pergeseran koordinat lereng otomatis terhubung ke Robotic Total Station (RTS).',
          iotFeatures: ['Automated Total Station RTS', 'Wireless Tiltmeter Sensor', 'InSAR Satellite Ingest'],
        ),
        MiningMenuItem(
          title: 'Analisis FoS (Factor of Safety)',
          categoryLabel: 'HULU • GEOTEKNIK LERENG',
          icon: Icons.shield_rounded,
          iconColor: const Color(0xFF10B981),
          badge: 'COMING SOON',
          description:
              'Perhitungan Faktor Keamanan (FoS) lereng tunggal dan lereng keseluruhan berbasis parameter kekuatan batuan dan air pori.',
          iotFeatures: ['VWP Piezometer Pori', 'Limit Equilibrium Solver', 'Borehole Extensometer'],
        ),
        MiningMenuItem(
          title: 'Early Warning System (EWS)',
          categoryLabel: 'HULU • GEOTEKNIK LERENG',
          icon: Icons.warning_amber_rounded,
          iconColor: const Color(0xFFEF4444),
          badge: 'COMING SOON',
          description:
              'Alarm peringatan dini otomatis pergerakan tanah kritis, penentuan zona bahaya, dan sirene evakuasi pit darurat.',
          iotFeatures: ['Automated Siren Broadcast', 'Push Alert Geoteknik', 'Geofence Evacuation Map'],
        ),
      ];
      final filtered = _filterItems(items);
      if (filtered.isNotEmpty) {
        sections.add(_buildSectionCard('2. Geoteknik & Kestabilan Lereng', filtered));
        sections.add(const SizedBox(height: 14));
      }
    }

    // SECTION 3: WATER & ENVIRONMENT • SUMP & SETTLING POND
    if (_matchesTab(2)) {
      final items = [
        MiningMenuItem(
          title: 'Central Sump Water Level',
          categoryLabel: 'WATER MANAGEMENT & SUMP',
          icon: Icons.water_drop_rounded,
          iconColor: const Color(0xFF0284C7),
          badge: 'COMING SOON',
          description:
              'Pemantauan ketinggian muka air sump pit (RL air), estimasi volume genangan (m³), dan kapasitas tampung sebelum overflow.',
          iotFeatures: ['Ultrasonic Level Sensor', 'Radar Level Transmitter', 'Sump Bathymetry 3D'],
        ),
        MiningMenuItem(
          title: 'Dewatering Pump Telemetry',
          categoryLabel: 'WATER MANAGEMENT & SUMP',
          icon: Icons.speed_rounded,
          iconColor: const Color(0xFF06B6D4),
          badge: 'COMING SOON',
          description:
              'Monitoring status pompa tambang (Sulzer, Multiflo, Sykes), debit aliran (liter/detik), RPM mesin, tekanan pipa, dan bahan bakar.',
          iotFeatures: ['Magnetic Flowmeter Live', 'Pump Engine RPM CAN-Bus', 'Pressure Discharge Gauge'],
        ),
        MiningMenuItem(
          title: 'Settling Pond (Kolam Pengendap)',
          categoryLabel: 'WATER MANAGEMENT & SUMP',
          icon: Icons.waves_rounded,
          iconColor: const Color(0xFF0D9488),
          badge: 'COMING SOON',
          description:
              'Pengelolaan kompartemen kolam pengendap sedimen tambang, waktu retensi air limpasan, dan jadwal pengerukan lumpur.',
          iotFeatures: ['Sediment Depth Sonar', 'Pond Inflow-Outflow Ratio', 'Desilting Fleet Tracking'],
        ),
        MiningMenuItem(
          title: 'Kualitas Air Live (pH & TSS)',
          categoryLabel: 'WATER MANAGEMENT & SUMP',
          icon: Icons.biotech_rounded,
          iconColor: const Color(0xFF10B981),
          badge: 'COMING SOON',
          description:
              'Sensor online parameter baku mutu lingkungan hidup di titik penaatan outflow: pH air (6–9), TSS (< 300 mg/L), Fe, dan Mn.',
          iotFeatures: ['Digital pH Probe Live', 'Turbidity / TSS Optical Sensor', 'Telemetri KLHK Resmi'],
        ),
        MiningMenuItem(
          title: 'Chemical Neutralization Dosing',
          categoryLabel: 'WATER MANAGEMENT & SUMP',
          icon: Icons.science_rounded,
          iconColor: const Color(0xFF8B5CF6),
          badge: 'COMING SOON',
          description:
              'Pengaturan otomatis takaran kapur tohor (CaO) dan tawas (Alum) untuk netralisasi Air Asam Tambang (AAT) secara presisi.',
          iotFeatures: ['Automated Lime Feeder', 'Smart Dosing Pump Controller', 'Chemical Consumption Log'],
        ),
        MiningMenuItem(
          title: 'Rainfall & Run-Off Catchment',
          categoryLabel: 'WATER MANAGEMENT & SUMP',
          icon: Icons.cloud_queue_rounded,
          iconColor: const Color(0xFF64748B),
          badge: 'COMING SOON',
          description:
              'Stasiun cuaca telemetri curah hujan (AWS), perhitungan debit limpasan air hujan, dan kapasitas saluran diversi keliling pit.',
          iotFeatures: ['Tipping Bucket Rain Gauge', 'Catchment Basin Modeler', 'Drainage Channel Sensor'],
        ),
      ];
      final filtered = _filterItems(items);
      if (filtered.isNotEmpty) {
        sections.add(_buildSectionCard('3. Sump, Settling Pond & Water Management', filtered));
        sections.add(const SizedBox(height: 14));
      }
    }

    // SECTION 4: PROCESSING • CPP & ROM STOCKPILE
    if (_matchesTab(3)) {
      final items = [
        MiningMenuItem(
          title: 'ROM Stockpile Management',
          categoryLabel: 'CPP & COAL PROCESSING',
          icon: Icons.layers_rounded,
          iconColor: const Color(0xFFD97706),
          badge: 'COMING SOON',
          description:
              'Kapasitas timbunan batubara ROM pit, pemetaan nomor seam/kualitas kalori, dan pengaturan sistem First-In First-Out (FIFO).',
          iotFeatures: ['Laser Scanner Volume Timbunan', 'Seam Allocation Tracker', 'FIFO Age Monitoring'],
        ),
        MiningMenuItem(
          title: 'Crushing Plant & Feeder Breaker',
          categoryLabel: 'CPP & COAL PROCESSING',
          icon: Icons.precision_manufacturing_rounded,
          iconColor: const Color(0xFFEA580C),
          badge: 'COMING SOON',
          description:
              'Laju pengumpanan batubara (TPH), efisiensi pemecahan batubara pada primary crusher, dan beban ampere motor listrik.',
          iotFeatures: ['Feeder Speed Inverter', 'Motor Current Telemetry', 'Choke Feeder Sensor'],
        ),
        MiningMenuItem(
          title: 'Sizing Screen & Product Quality',
          categoryLabel: 'CPP & COAL PROCESSING',
          icon: Icons.filter_alt_rounded,
          iconColor: const Color(0xFF10B981),
          badge: 'COMING SOON',
          description:
              'Pemisahan fraksi ukuran batubara produk crushed coal (0–50 mm) dan pemantauan getaran screen deck pencegah blinding.',
          iotFeatures: ['Screen Vibration Accelerometer', 'Product Size AI Cam', 'Oversize Return Loop'],
        ),
        MiningMenuItem(
          title: 'Conveyor Weightometer Telemetry',
          categoryLabel: 'CPP & COAL PROCESSING',
          icon: Icons.linear_scale_rounded,
          iconColor: const Color(0xFF0284C7),
          badge: 'COMING SOON',
          description:
              'Timbangan digital weightometer konveyor batubara terkalibrasi, tonase per jam live, dan sensor metal detector proteksi belt.',
          iotFeatures: ['Belt Scale Weightometer', 'Metal Detector Trip Sensor', 'Belt Misalignment Switch'],
        ),
        MiningMenuItem(
          title: 'Spontaneous Combustion Hotspot',
          categoryLabel: 'CPP & COAL PROCESSING',
          icon: Icons.local_fire_department_rounded,
          iconColor: const Color(0xFFDC2626),
          badge: 'COMING SOON',
          description:
              'Kamera thermal inframerah 360° untuk mendeteksi titik panas (hotspot) batubara di stockpile dan mencegah swa-bakar dini.',
          iotFeatures: ['Thermal IR Panoramic Cam', 'Gas CO Sensor Array', 'Water Mist Sprinkler Trigger'],
        ),
      ];
      final filtered = _filterItems(items);
      if (filtered.isNotEmpty) {
        sections.add(_buildSectionCard('4. CPP (Coal Processing Plant) & Stockpile', filtered));
        sections.add(const SizedBox(height: 14));
      }
    }

    // SECTION 5: HILIR • HAULING ROAD, WEIGHBRIDGE & BARGING
    if (_matchesTab(4)) {
      final items = [
        MiningMenuItem(
          title: 'Hauling Road Telemetry (KM 0-48)',
          categoryLabel: 'HILIR • HAULING & PORT',
          icon: Icons.alt_route_rounded,
          iconColor: const Color(0xFFF59E0B),
          badge: 'COMING SOON',
          description:
              'Pemantauan kondisi permukaan jalan hauling 48 kilometer, kemiringan ramp, titik blind spot, dan keselamatan jalur angkut.',
          iotFeatures: ['Road Roughness Accelerometer', 'CCTV Corridor Surveillance', 'Digital Kilometer Marker'],
        ),
        MiningMenuItem(
          title: 'Dust Suppression Water Truck',
          categoryLabel: 'HILIR • HAULING & PORT',
          icon: Icons.water_drop_outlined,
          iconColor: const Color(0xFF06B6D4),
          badge: 'COMING SOON',
          description:
              'Jadwal penyiraman jalan hauling unit Water Truck, pemantauan konsentrasi debu PM10/PM2.5, dan efektivitas dust retardant.',
          iotFeatures: ['Dust Particle PM10 Sensor', 'Water Spray Valve Telemetry', 'GPS Water Truck Geo-Stamp'],
        ),
        MiningMenuItem(
          title: 'Speed Radar & AI Fatigue Cam',
          categoryLabel: 'HILIR • HAULING & PORT',
          icon: Icons.speed_rounded,
          iconColor: const Color(0xFFEF4444),
          badge: 'COMING SOON',
          description:
              'Radar pembaca batas kecepatan unit (max 60 km/jam) dan kamera kabin AI deteksi kantuk / mikro-tidur operator dump truck.',
          iotFeatures: ['Doppler Speed Radar Sensor', 'Driver Fatigue AI Camera', 'Audible Speed Warning Box'],
        ),
        MiningMenuItem(
          title: 'Weighbridge (Jembatan Timbang)',
          categoryLabel: 'HILIR • HAULING & PORT',
          icon: Icons.scale_rounded,
          iconColor: const Color(0xFF10B981),
          badge: 'COMING SOON',
          description:
              'Penimbangan otomatis truk hauling tiba di port, pencatatan Gross-Tare-Nett, dan validasi payload kepatuhan muatan.',
          iotFeatures: ['RFID Auto-Timbang Sensor', 'ANPR Plat Nomor Kamera', 'Tare Memory Verification'],
        ),
        MiningMenuItem(
          title: 'Port Stockpile & Blending',
          categoryLabel: 'HILIR • HAULING & PORT',
          icon: Icons.calculate_rounded,
          iconColor: const Color(0xFFA855F7),
          badge: 'COMING SOON',
          description:
              'Pengaturan tumpukan batubara pelabuhan dan kalkulator otomatis pencampuran (blending) kalori batubara sesuai kontrak pembeli.',
          iotFeatures: ['Quality Coal Matrix DB', 'Automated Blending Solver', 'Stockpile Age Expiry Alert'],
        ),
        MiningMenuItem(
          title: 'Barge Loading Conveyor (BLC)',
          categoryLabel: 'HILIR • HAULING & PORT',
          icon: Icons.directions_boat_filled_rounded,
          iconColor: const Color(0xFF0284C7),
          badge: 'COMING SOON',
          description:
              'Telemetri laju pemuatan batubara jet conveyor ke palka tongkang (1.200 Ton/Jam), boom angle, dan pasang surut dermaga.',
          iotFeatures: ['Conveyor Speed SCADA Live', 'Tide Gauge Water Sensor', 'Chute Trimming Controller'],
        ),
        MiningMenuItem(
          title: 'Tugboat & Tongkang AIS Radar',
          categoryLabel: 'HILIR • HAULING & PORT',
          icon: Icons.sailing_rounded,
          iconColor: const Color(0xFF0D9488),
          badge: 'COMING SOON',
          description:
              'Pelacakan satelit AIS posisi tongkang 300 feet, estimasi waktu sandar (ETA), antrean tambat dermaga, dan alokasi tugboat.',
          iotFeatures: ['Live Marine AIS Satellite', 'Berthing Queue Optimizer', 'Barge Cargo Manifest API'],
        ),
        MiningMenuItem(
          title: 'Draught Survey & Quality Cert',
          categoryLabel: 'HILIR • HAULING & PORT',
          icon: Icons.verified_rounded,
          iconColor: const Color(0xFF38BDF8),
          badge: 'COMING SOON',
          description:
              'Pencatatan sarat kapal draught survey surveyor independen, perhitungan tonase final pengapalan, dan sertifikat kualitas COA.',
          iotFeatures: ['Draft Mark Optical Sensor', 'Density Water Hydrometer', 'Digital COA Exporter'],
        ),
      ];
      final filtered = _filterItems(items);
      if (filtered.isNotEmpty) {
        sections.add(_buildSectionCard('5. Hauling Road, Jembatan Timbang & Barging (Hilir)', filtered));
        sections.add(const SizedBox(height: 14));
      }
    }

    if (sections.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Column(
            children: [
              Icon(Icons.search_off_rounded, size: 48, color: Colors.white.withValues(alpha: 0.3)),
              const SizedBox(height: 10),
              Text(
                'Modul Tidak Ditemukan',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.9)),
              ),
              const SizedBox(height: 4),
              Text(
                'Tidak ada modul yang cocok dengan kata kunci "$_searchQuery".',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
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

  Widget _buildSectionCard(String title, List<MiningMenuItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1E293B)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.5)),
                  ),
                  child: const Text(
                    'COMING SOON',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFFDE047),
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF1E293B)),

          // Grid of Items
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.45,
            ),
            itemCount: items.length,
            itemBuilder: (ctx, idx) => _buildItemTile(items[idx]),
          ),
        ],
      ),
    );
  }

  Widget _buildItemTile(MiningMenuItem item) {
    return Material(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _showComingSoonModal(item),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: item.iconColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Icon(item.icon, color: item.iconColor, size: 20),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'SOON',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFDE047),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MiningMenuItem {
  final String title;
  final String categoryLabel;
  final IconData icon;
  final Color iconColor;
  final String badge;
  final String description;
  final List<String> iotFeatures;

  MiningMenuItem({
    required this.title,
    required this.categoryLabel,
    required this.icon,
    required this.iconColor,
    required this.badge,
    required this.description,
    required this.iotFeatures,
  });
}

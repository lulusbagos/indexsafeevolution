import 'package:flutter/material.dart';
import '../../services/preference.dart';

class MiningHubPage extends StatefulWidget {
  const MiningHubPage({super.key});

  @override
  State<MiningHubPage> createState() => _MiningHubPageState();
}

class _MiningHubPageState extends State<MiningHubPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  // Active user info
  String _myName = '';
  String _myDept = '';

  @override
  void initState() {
    super.initState();
    final profile = PreferenceService.getProfile();
    _myName = profile?.namaLengkap ?? 'LULUS BAGOS HERMAWAN';
    _myDept = profile?.depart ?? 'SYSTEM INTEGRATIONS';

    _tabCtrl = TabController(length: 5, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFD97706); // Amber Gold Mining

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mining Operations & Tech',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD97706),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    '$_myDept • $_myName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Simulasi Blending',
            icon: const Icon(Icons.calculate_outlined, color: primaryColor),
            onPressed: _showBlendingCalculatorDialog,
          ),
          IconButton(
            tooltip: 'Pusat Bantuan',
            icon: const Icon(Icons.help_outline_rounded, color: Color(0xFF64748B)),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Modul Mining Operations & Engineering terintegrasi CCM.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: TabBar(
              controller: _tabCtrl,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: primaryColor,
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: primaryColor,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: const [
                Tab(
                  child: Row(
                    children: [
                      Icon(Icons.dashboard_customize_rounded, size: 17),
                      SizedBox(width: 6),
                      Text('Dashboard KPI'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    children: [
                      Icon(Icons.precision_manufacturing_rounded, size: 17),
                      SizedBox(width: 6),
                      Text('Mine Engineering'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    children: [
                      Icon(Icons.science_rounded, size: 17),
                      SizedBox(width: 6),
                      Text('CCM (Coal Quality)'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    children: [
                      Icon(Icons.local_shipping_rounded, size: 17),
                      SizedBox(width: 6),
                      Text('Hauling & Fleet'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    children: [
                      Icon(Icons.landscape_rounded, size: 17),
                      SizedBox(width: 6),
                      Text('Survey & Drone'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildDashboardKpiTab(),
          _buildMineEngineeringTab(),
          _buildCcmTab(),
          _buildHaulingFleetTab(),
          _buildSurveyDroneTab(),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TAB 1: DASHBOARD KPI
  // --------------------------------------------------------------------------
  Widget _buildDashboardKpiTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Highlight Banner
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFD97706)),
                    ),
                    child: const Text(
                      'REALTIME PIT STATUS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFBBF24),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Text(
                    'Update: Hari Ini',
                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Produksi Batubara & Stripping Ratio',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Operasi penambangan Pit Central & Pit West berjalan normal dengan kepatuhan CCM 98.4%.',
                style: TextStyle(fontSize: 12, color: Color(0xFFCBD5E1), height: 1.4),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildKpiMiniBox('Coal Mined', '42,850 MT', const Color(0xFFF59E0B)),
                  const SizedBox(width: 10),
                  _buildKpiMiniBox('OB Removal', '215,400 BCM', const Color(0xFF38BDF8)),
                  const SizedBox(width: 10),
                  _buildKpiMiniBox('Actual SR', '5.02 : 1', const Color(0xFF34D399)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        const Text(
          'Indikator Utama Operasional Tambang',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 12),

        // Grid Metric Cards
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.35,
          children: [
            _buildMetricCard(
              title: 'CCM Quality Index',
              value: '98.4%',
              status: 'Normal Compliance',
              icon: Icons.verified_rounded,
              color: const Color(0xFF10B981),
            ),
            _buildMetricCard(
              title: 'Kapasitas ROM Stockpile',
              value: '185,200 MT',
              status: '72% Kapasitas',
              icon: Icons.layers_rounded,
              color: const Color(0xFFF59E0B),
            ),
            _buildMetricCard(
              title: 'Stabilitas Lereng (FoS)',
              value: '1.42 FoS',
              status: 'Aman & Stabil',
              icon: Icons.shield_rounded,
              color: const Color(0xFF0284C7),
            ),
            _buildMetricCard(
              title: 'Fleet Availability (PA)',
              value: '89.6%',
              status: 'Fleet Siap Operasi',
              icon: Icons.construction_rounded,
              color: const Color(0xFF8B5CF6),
            ),
          ],
        ),

        const SizedBox(height: 20),
        const Text(
          'Pemberitahuan Teknis Mining Terbaru',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 12),

        _buildAlertCard(
          title: 'Transisi Penambangan Seam B2 - Pit West',
          desc: 'Pengawasan ketat CCM untuk mencegah kontaminasi parting clay pada elevasi RL -15 m.',
          time: '2 jam lalu • Mine Geology Team',
          type: 'warning',
        ),
        _buildAlertCard(
          title: 'Inspeksi Geoteknik Mingguan Selesai',
          desc: 'Semua prisma radar pit monitoring menunjukkan perpindahan lereng < 1.5 mm (Normal).',
          time: '4 jam lalu • Geotech Engineering',
          type: 'success',
        ),
      ],
    );
  }

  Widget _buildKpiMiniBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String status,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard({
    required String title,
    required String desc,
    required String time,
    required String type,
  }) {
    final isWarn = type == 'warning';
    final accent = isWarn ? const Color(0xFFF59E0B) : const Color(0xFF10B981);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isWarn ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
              color: accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569), height: 1.4),
                ),
                const SizedBox(height: 6),
                Text(
                  time,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TAB 2: MINE ENGINEERING
  // --------------------------------------------------------------------------
  Widget _buildMineEngineeringTab() {
    final engineeringItems = [
      {
        'title': 'Rencana Pit Central Tahap 4',
        'type': 'Pit Design',
        'status': 'Aktif Berjalan',
        'sr': '4.8 : 1',
        'rl': 'Elevasi -25m s/d +60m',
        'icon': Icons.architecture_rounded,
      },
      {
        'title': 'Mine Sequencing Pit West',
        'type': 'Monthly Schedule',
        'status': 'Review Geoteknik',
        'sr': '5.2 : 1',
        'rl': 'Elevasi -10m s/d +45m',
        'icon': Icons.calendar_view_week_rounded,
      },
      {
        'title': 'Desain Lereng Lowwall & Highwall',
        'type': 'Geotechnical Design',
        'status': 'Approved KTT',
        'sr': 'FoS Min: 1.30',
        'rl': 'Slope Angle 42°',
        'icon': Icons.terrain_rounded,
      },
      {
        'title': 'Disposal & Dump Plan Area Timur',
        'type': 'Waste Dumping',
        'status': 'Kapasitas 82%',
        'sr': 'Kapasitas 1.4M BCM',
        'rl': 'Elevasi +110m',
        'icon': Icons.delete_sweep_rounded,
      },
      {
        'title': 'Water Management & Pit Sump',
        'type': 'Dewatering Plan',
        'status': 'Pompa 3 Unit Standby',
        'sr': 'Debit 320 L/dtk',
        'rl': 'Sump Central RL -30m',
        'icon': Icons.water_drop_rounded,
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Dokumen & Desain Rekayasa Tambang', 'Mining Engineering & Geotechnical Design'),
        const SizedBox(height: 12),
        ...engineeringItems.map((item) => _buildEngineeringCard(item)),
      ],
    );
  }

  Widget _buildEngineeringCard(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item['type']!,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item['status']!,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item['title']!,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.tune_rounded, size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text(item['sr']!, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              const SizedBox(width: 14),
              const Icon(Icons.straighten_rounded, size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text(item['rl']!, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            ],
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TAB 3: CCM (CLEAN COAL MANAGEMENT)
  // --------------------------------------------------------------------------
  Widget _buildCcmTab() {
    final ccmSeams = [
      {
        'seam': 'Seam A - Upper Pit Central',
        'calori': '5,850 kcal/kg (adb)',
        'tm': '24.2% Total Moisture',
        'ash': '5.8% Low Ash',
        'ts': '0.42% Low Sulfur',
        'status': 'Premium Grade',
        'color': const Color(0xFF059669),
      },
      {
        'seam': 'Seam B1 - Main Pit West',
        'calori': '5,320 kcal/kg (adb)',
        'tm': '28.1% Total Moisture',
        'ash': '7.4% Medium Ash',
        'ts': '0.65% Medium Sulfur',
        'status': 'Standard Blending',
        'color': const Color(0xFF0284C7),
      },
      {
        'seam': 'Seam B2 - Lower Pit Central',
        'calori': '5,050 kcal/kg (adb)',
        'tm': '30.4% Total Moisture',
        'ash': '8.9% Parting Clay Alert',
        'ts': '0.78% Medium Sulfur',
        'status': 'Perlu Blending',
        'color': const Color(0xFFD97706),
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Standar Mutu & Parameter Kualitas Batubara (CCM)', 'Clean Coal Management & Quality Control'),
        const SizedBox(height: 12),

        // Blending quick action banner
        InkWell(
          onTap: _showBlendingCalculatorDialog,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFD97706), Color(0xFFB45309)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD97706).withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              children: [
                Icon(Icons.calculate_rounded, color: Colors.white, size: 28),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kalkulator & Simulasi Blending Batubara',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Hitung proporsi tonase Seam A + Seam B untuk target kalori buyer.',
                        style: TextStyle(fontSize: 11, color: Color(0xFFFEF3C7)),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),
        const Text(
          'Daftar Karakteristik Seam Aktif',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 12),

        ...ccmSeams.map((s) => _buildSeamQualityCard(s)),
      ],
    );
  }

  Widget _buildSeamQualityCard(Map<String, dynamic> seam) {
    final color = seam['color'] as Color;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                seam['seam'] as String,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text(
                  seam['status'] as String,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildQualityPill('Kalori', seam['calori'] as String, Icons.local_fire_department_rounded, const Color(0xFFEF4444)),
              const SizedBox(width: 8),
              _buildQualityPill('Ash', seam['ash'] as String, Icons.blur_linear_rounded, const Color(0xFF64748B)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildQualityPill('Moisture', seam['tm'] as String, Icons.water_drop_outlined, const Color(0xFF0284C7)),
              const SizedBox(width: 8),
              _buildQualityPill('Sulfur', seam['ts'] as String, Icons.science_outlined, const Color(0xFF8B5CF6)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQualityPill(String label, String value, IconData icon, Color iconColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TAB 4: HAULING & FLEET
  // --------------------------------------------------------------------------
  Widget _buildHaulingFleetTab() {
    final fleets = [
      {'name': 'Fleet Coal Pit Central', 'excavator': 'Komatsu PC2000 (1 Unit)', 'hauler': 'HD785 (6 Unit)', 'ton': '1,420 MT/shift'},
      {'name': 'Fleet Coal Pit West', 'excavator': 'Hitachi EX1200 (1 Unit)', 'hauler': 'CAT 777E (5 Unit)', 'ton': '1,180 MT/shift'},
      {'name': 'Fleet OB Removal Block 2', 'excavator': 'Komatsu PC1250 (2 Unit)', 'hauler': 'HD785 (10 Unit)', 'ton': '14,500 BCM/shift'},
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Alokasi Unit & Logistik Pengangkutan', 'Fleet Management & Weighbridge Data'),
        const SizedBox(height: 12),

        // Live Jembatan Timbang Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Jembatan Timbang (Weighbridge) ROM 01',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  Text(
                    'ONLINE',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF34D399)),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Ritase Hari Ini', style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
                      SizedBox(height: 2),
                      Text('428 Rit', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Netto Batubara', style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
                      SizedBox(height: 2),
                      Text('41,200 MT', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFFFBBF24))),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Rata-rata Muatan', style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
                      SizedBox(height: 2),
                      Text('96.2 Ton/DT', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF38BDF8))),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        ...fleets.map((f) => _buildFleetCard(f)),
      ],
    );
  }

  Widget _buildFleetCard(Map<String, String> f) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(f['name']!, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
              Text(f['ton']!, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFFD97706))),
            ],
          ),
          const SizedBox(height: 6),
          Text('Excavator: ${f['excavator']}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          Text('Hauler: ${f['hauler']}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TAB 5: SURVEY & DRONE
  // --------------------------------------------------------------------------
  Widget _buildSurveyDroneTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Survei Topografi & Pemetaan Drone', 'Survey, Cut & Fill Volumetric & In-situ Inventory'),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.flight_takeoff_rounded, color: Color(0xFF0284C7), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Drone Orthophoto Pit Map - DJI Matrice 300 RTK',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Penerbangan foto udara mingguan telah selesai. Model 3D DSM/DTM telah diselaraskan dengan titik BM Tambang.',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSurveyStat('Exposed Coal', '94,500 MT', const Color(0xFFD97706)),
                  _buildSurveyStat('Progress Cut', '182,000 BCM', const Color(0xFF0284C7)),
                  _buildSurveyStat('Akurasi BM', '± 1.2 cm', const Color(0xFF10B981)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSurveyStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  // Blending Calculator Dialog
  void _showBlendingCalculatorDialog() {
    double caloriA = 5850;
    double caloriB = 5050;
    double propA = 60; // 60%
    double propB = 40; // 40%

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final resultCalori = (caloriA * (propA / 100)) + (caloriB * (propB / 100));

          return Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Row(
                  children: [
                    Icon(Icons.calculate_rounded, color: Color(0xFFD97706), size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Kalkulator Blending Kualitas Batubara',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Simulasi pencampuran (blending) untuk memenuhi spesifikasi kontrak buyer (CCM).',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 18),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hasil Estimasi Kalori Blending:', style: TextStyle(fontSize: 11, color: Color(0xFF92400E))),
                          SizedBox(height: 2),
                          Text('Target Terpenuhi', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
                        ],
                      ),
                      Text(
                        '${resultCalori.toStringAsFixed(0)} kcal/kg',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFFB45309)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                Text('Proporsi Seam A (5,850 kcal/kg): ${propA.toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                Slider(
                  value: propA,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  activeColor: const Color(0xFFD97706),
                  onChanged: (val) {
                    setModalState(() {
                      propA = val;
                      propB = 100 - val;
                    });
                  },
                ),

                Text('Proporsi Seam B (5,050 kcal/kg): ${propB.toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                Slider(
                  value: propB,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  activeColor: const Color(0xFF0284C7),
                  onChanged: (val) {
                    setModalState(() {
                      propB = val;
                      propA = 100 - val;
                    });
                  },
                ),

                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      'Terapkan Formula Blending',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

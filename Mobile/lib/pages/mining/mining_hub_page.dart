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

  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  // State untuk Kalkulator Blending Batubara
  double _ratioSeamA = 60.0;
  final double _caloriSeamA = 5850.0;
  final double _caloriSeamB = 5050.0;

  double get _blendedCalori {
    final ratioA = _ratioSeamA / 100.0;
    final ratioB = (100.0 - _ratioSeamA) / 100.0;
    return (ratioA * _caloriSeamA) + (ratioB * _caloriSeamB);
  }

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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD97706), Color(0xFFB45309)],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'X MINE',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Mining Operations',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Mine Engineering • CCM • Fleet & Survey • $_myDept',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Simulasi Blending',
            icon: const Icon(Icons.calculate_rounded, color: primaryColor),
            onPressed: _showBlendingCalculatorModal,
          ),
          IconButton(
            tooltip: 'Status Pit Tambang',
            icon: const Icon(Icons.analytics_rounded, color: Color(0xFF64748B)),
            onPressed: _showPitStatusModal,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
        children: [
          // 1. Top Realtime Pit Operations Banner
          _buildPitHeroBanner(),

          const SizedBox(height: 14),

          // 2. Search Bar
          _buildSearchBar(),

          const SizedBox(height: 16),

          // 3. Section 1: Rekayasa Tambang & Geoteknik (Mine Engineering)
          _buildSectionCard(
            title: 'Rekayasa Tambang & Geoteknik',
            onTitleTap: () => _showToast('Kategori: Rekayasa Tambang & Geoteknik'),
            items: [
              _MenuItem(
                title: 'Pit Design',
                icon: Icons.architecture_rounded,
                iconColor: const Color(0xFFD97706),
                bgColor: const Color(0xFFFEF3C7),
                badge: 'RL -25m',
                onTap: () => _showFeatureDetail(
                  'Desain & Rencana Pit Tambang',
                  'Desain geometri bench, ramp akses, dan boundary limit penambangan Pit Central Tahap 4 pada elevasi RL -25 m s/d +60 m.',
                  Icons.architecture_rounded,
                  const Color(0xFFD97706),
                ),
              ),
              _MenuItem(
                title: 'Mine Sequencing',
                icon: Icons.calendar_month_rounded,
                iconColor: const Color(0xFF0284C7),
                bgColor: const Color(0xFFE0F2FE),
                onTap: () => _showFeatureDetail(
                  'Mine Sequencing & Schedule Bulanan',
                  'Penjadwalan arah kemajuan tambang bulanan Pit West, stripping ratio berkala, dan alokasi fleet excavator loader.',
                  Icons.calendar_month_rounded,
                  const Color(0xFF0284C7),
                ),
              ),
              _MenuItem(
                title: 'Geoteknik Lereng',
                icon: Icons.terrain_rounded,
                iconColor: const Color(0xFF059669),
                bgColor: const Color(0xFFD1FAE5),
                badge: 'FoS 1.42',
                onTap: () => _showFeatureDetail(
                  'Kemantapan Lereng (FoS & Slope Stability)',
                  'Monitoring kestabilan dinding tambang Highwall dan Lowwall menggunakan prism monitoring dan slope stability radar. FoS aman: 1.42.',
                  Icons.terrain_rounded,
                  const Color(0xFF059669),
                ),
              ),
              _MenuItem(
                title: 'Pit Dewatering',
                icon: Icons.water_drop_rounded,
                iconColor: const Color(0xFF0891B2),
                bgColor: const Color(0xFFCFFAFE),
                onTap: () => _showFeatureDetail(
                  'Water Management & Pit Sump',
                  'Pengelolaan pompa tambang di Central Sump RL -30m dengan debit 320 Liter/detik dialirkan menuju kolam pengendap sedimen (settling pond).',
                  Icons.water_drop_rounded,
                  const Color(0xFF0891B2),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 4. Section 2: Clean Coal Management (CCM & Kualitas)
          _buildSectionCard(
            title: 'Clean Coal Management (CCM & Kualitas)',
            onTitleTap: () => _showToast('Kategori: Clean Coal Management'),
            items: [
              _MenuItem(
                title: 'Kualitas Seam',
                icon: Icons.science_rounded,
                iconColor: const Color(0xFFDC2626),
                bgColor: const Color(0xFFFEE2E2),
                onTap: _showSeamQualityModal,
              ),
              _MenuItem(
                title: 'Simulasi Blending',
                icon: Icons.calculate_rounded,
                iconColor: const Color(0xFFD97706),
                bgColor: const Color(0xFFFEF3C7),
                badge: 'HITUNG',
                onTap: _showBlendingCalculatorModal,
              ),
              _MenuItem(
                title: 'ROM Stockpile',
                icon: Icons.layers_rounded,
                iconColor: const Color(0xFF7C3AED),
                bgColor: const Color(0xFFEDE9FE),
                onTap: () => _showFeatureDetail(
                  'Manajemen ROM Stockpile Batubara',
                  'Kapasitas aktif ROM Stockpile 185,200 MT (72% kapasitas). Pengaturan sistem FIFO dan pencegahan swa-bakar (spontaneous combustion).',
                  Icons.layers_rounded,
                  const Color(0xFF7C3AED),
                ),
              ),
              _MenuItem(
                title: 'Kontrol Parting',
                icon: Icons.cleaning_services_rounded,
                iconColor: const Color(0xFF0F766E),
                bgColor: const Color(0xFFCCFBF1),
                badge: 'CCM 98%',
                onTap: () => _showFeatureDetail(
                  'Pembersihan & Kontrol Parting Clay',
                  'Pengawasan ketat pemisahan parting tanah liat dari lapisan batubara untuk memastikan kadar abu (ash content) tetap di bawah 6.5%.',
                  Icons.cleaning_services_rounded,
                  const Color(0xFF0F766E),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 5. Section 3: Hauling, Fleet & Timbangan
          _buildSectionCard(
            title: 'Hauling, Fleet & Timbangan',
            onTitleTap: () => _showToast('Kategori: Hauling & Fleet Operasional'),
            items: [
              _MenuItem(
                title: 'Fleet Tracker',
                icon: Icons.local_shipping_rounded,
                iconColor: const Color(0xFF2563EB),
                bgColor: const Color(0xFFDBEAFE),
                badge: '89.6% PA',
                onTap: () => _showFeatureDetail(
                  'Fleet Availability & Monitoring Unit',
                  'Ketersediaan fisik alat berat (Physical Availability): 89.6%. 142 Dump Truck dan 18 Excavator loader beroperasi normal.',
                  Icons.local_shipping_rounded,
                  const Color(0xFF2563EB),
                ),
              ),
              _MenuItem(
                title: 'Jembatan Timbang',
                icon: Icons.scale_rounded,
                iconColor: const Color(0xFF059669),
                bgColor: const Color(0xFFD1FAE5),
                onTap: () => _showFeatureDetail(
                  'Weighbridge & Payload Batubara',
                  'Monitoring otomatis timbangan truk batubara keluar pit menuju port. Rata-rata payload 32.4 ton per ritase dengan deviasi < 2%.',
                  Icons.scale_rounded,
                  const Color(0xFF059669),
                ),
              ),
              _MenuItem(
                title: 'Barging & Port',
                icon: Icons.directions_boat_rounded,
                iconColor: const Color(0xFF0284C7),
                bgColor: const Color(0xFFE0F2FE),
                onTap: () => _showFeatureDetail(
                  'Operasional Pelabuhan & Pemuatan Tongkang',
                  'Laju pemuatan conveyor jet jetty: 1,200 Ton/Jam. Stockpile pelabuhan siap muat untuk pengapalan tongkang 300 feet.',
                  Icons.directions_boat_rounded,
                  const Color(0xFF0284C7),
                ),
              ),
              _MenuItem(
                title: 'Jalur Hauling',
                icon: Icons.alt_route_rounded,
                iconColor: const Color(0xFFD97706),
                bgColor: const Color(0xFFFEF3C7),
                onTap: () => _showFeatureDetail(
                  'Kondisi Jalan Hauling Tambang',
                  'Jalur hauling KM 0 s/d KM 48 dalam kondisi mulus. 6 unit Water Truck aktif menyiram debu jalan secara terjadwal.',
                  Icons.alt_route_rounded,
                  const Color(0xFFD97706),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 6. Section 4: Survey, Drone & Geologi Tambang
          _buildSectionCard(
            title: 'Survey, Drone & Geologi Tambang',
            onTitleTap: () => _showToast('Kategori: Survey & Geologi'),
            items: [
              _MenuItem(
                title: 'Drone LiDAR',
                icon: Icons.flight_takeoff_rounded,
                iconColor: const Color(0xFF7C3AED),
                bgColor: const Color(0xFFEDE9FE),
                badge: 'FOTO 3D',
                onTap: () => _showFeatureDetail(
                  'Pemetaan Udara Drone LiDAR & Fotogrametri',
                  'Penerbangan drone mingguan menghasilkan peta orthophoto kontur topografi 3D bereferensi koordinat geospasial tambang.',
                  Icons.flight_takeoff_rounded,
                  const Color(0xFF7C3AED),
                ),
              ),
              _MenuItem(
                title: 'Volume Cut & Fill',
                icon: Icons.straighten_rounded,
                iconColor: const Color(0xFF0D9488),
                bgColor: const Color(0xFFCCFBF1),
                onTap: () => _showFeatureDetail(
                  'Perhitungan Volume Overburden & Coal',
                  'Rekonsiliasi volume hasil survey tambang bulanan: OB Removal 215,400 BCM dan Coal Mined 42,850 MT.',
                  Icons.straighten_rounded,
                  const Color(0xFF0D9488),
                ),
              ),
              _MenuItem(
                title: 'Eksplorasi Seam',
                icon: Icons.biotech_rounded,
                iconColor: const Color(0xFFE11D48),
                bgColor: const Color(0xFFFFE4E6),
                onTap: () => _showFeatureDetail(
                  'Pemodelan Geologi & Titik Bor',
                  'Data log stratigrafi 84 titik bor eksplorasi aktif untuk memetakan ketebalan dan kemiringan dip seam batubara.',
                  Icons.biotech_rounded,
                  const Color(0xFFE11D48),
                ),
              ),
              _MenuItem(
                title: 'Disposal Dump',
                icon: Icons.delete_sweep_rounded,
                iconColor: const Color(0xFF475569),
                bgColor: const Color(0xFFF1F5F9),
                onTap: () => _showFeatureDetail(
                  'Rencana Penimbunan Waste Dump Timur',
                  'Kapasitas area dumping timur terpakai 82% (1.4 Juta BCM). Penataan terasering lereng dan penanaman vegetasi reklamasi progresif.',
                  Icons.delete_sweep_rounded,
                  const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // WIDGETS
  // --------------------------------------------------------------------------

  Widget _buildPitHeroBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
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
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFFBBF24),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Text(
                'Live Operasional',
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Produksi Batubara & Stripping Ratio',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Operasi Pit Central & Pit West dengan kepatuhan CCM 98.4%',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildPitMetric('COAL MINED', '42,850 MT', const Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              _buildPitMetric('OB REMOVAL', '215.4K BCM', const Color(0xFF38BDF8)),
              const SizedBox(width: 8),
              _buildPitMetric('ACTUAL SR', '5.02 : 1', const Color(0xFF34D399)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPitMetric(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: InputDecoration(
          hintText: 'Cari modul rekayasa, geoteknik, seam, timbangan...',
          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFD97706), size: 22),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required VoidCallback onTitleTap,
    required List<_MenuItem> items,
  }) {
    final filteredItems = _searchQuery.isEmpty
        ? items
        : items.where((i) => i.title.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    if (filteredItems.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTitleTap,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF64748B),
                  size: 20,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: filteredItems.map((item) {
              return Expanded(
                child: _buildGridItemTile(item),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGridItemTile(_MenuItem item) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: item.bgColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: item.iconColor.withValues(alpha: 0.18),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: item.iconColor.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      item.icon,
                      color: item.iconColor,
                      size: 28,
                    ),
                  ),
                ),
                if (item.badge != null)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withValues(alpha: 0.4),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(
                        item.badge!,
                        style: const TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
                height: 1.18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // MODALS
  // --------------------------------------------------------------------------

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showFeatureDetail(String title, String desc, IconData icon, Color color) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Modul Operasional Tambang X Mine',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                desc,
                style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.45),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Tutup', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 1. Kalkulator Blending Modal
  void _showBlendingCalculatorModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final blended = _blendedCalori;
          final meetsTarget = blended >= 5400;

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
                    Icon(Icons.calculate_rounded, color: Color(0xFFD97706), size: 26),
                    SizedBox(width: 8),
                    Text(
                      'Kalkulator Blending Kualitas Batubara',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Simulasi pencampuran (blending) untuk memenuhi spesifikasi kontrak buyer (CCM).',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 18),

                // Calculation Result Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: meetsTarget ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: meetsTarget ? const Color(0xFFFDE68A) : const Color(0xFFFECACA),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Hasil Estimasi Kalori Blending:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF78350F)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            meetsTarget ? 'Target Terpenuhi (>5,400 kcal)' : 'Di Bawah Target Kontrak',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: meetsTarget ? const Color(0xFF059669) : const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${blended.toStringAsFixed(0)} kcal/kg',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Sliders
                Text(
                  'Proporsi Seam A (5,850 kcal/kg): ${_ratioSeamA.toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                Slider(
                  value: _ratioSeamA,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  activeColor: const Color(0xFFD97706),
                  onChanged: (val) {
                    setState(() => _ratioSeamA = val);
                    setModalState(() {});
                  },
                ),

                Text(
                  'Proporsi Seam B (5,050 kcal/kg): ${(100 - _ratioSeamA).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                Slider(
                  value: 100 - _ratioSeamA,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  activeColor: const Color(0xFF0284C7),
                  onChanged: (val) {
                    setState(() => _ratioSeamA = 100 - val);
                    setModalState(() {});
                  },
                ),

                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Formula blending ${_ratioSeamA.toStringAsFixed(0)}% Seam A : ${(100 - _ratioSeamA).toStringAsFixed(0)}% Seam B berhasil disimpan ke ROM dispatch.'),
                          backgroundColor: const Color(0xFFD97706),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Terapkan Formula Blending', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 2. Kualitas Seam Modal
  void _showSeamQualityModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        minChildSize: 0.45,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: ListView(
            controller: scrollCtrl,
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
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.science_rounded, color: Color(0xFFDC2626), size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Karakteristik Seam Batubara Aktif',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Data kualitas batubara hasil laboratorium eksplorasi & sampling ROM.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),

              _buildSeamCard(
                seamName: 'Seam A - Upper Pit Central',
                grade: 'Premium Grade',
                calori: '5,850 kcal/kg (adb)',
                ash: '5.8% Low Ash',
                tm: '24.2% Total Moisture',
                sulfur: '0.42% Low Sulfur',
                badgeColor: const Color(0xFF10B981),
              ),
              _buildSeamCard(
                seamName: 'Seam B1 - Main Pit West',
                grade: 'Standard Blending',
                calori: '5,320 kcal/kg (adb)',
                ash: '7.4% Medium Ash',
                tm: '28.1% Total Moisture',
                sulfur: '0.65% Medium Sulfur',
                badgeColor: const Color(0xFF0284C7),
              ),
              _buildSeamCard(
                seamName: 'Seam B2 - Lower Pit Central',
                grade: 'Perlu Blending',
                calori: '5,050 kcal/kg (adb)',
                ash: '8.9% Parting Clay Alert',
                tm: '30.4% Total Moisture',
                sulfur: '0.78% Medium Sulfur',
                badgeColor: const Color(0xFFF59E0B),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeamCard({
    required String seamName,
    required String grade,
    required String calori,
    required String ash,
    required String tm,
    required String sulfur,
    required Color badgeColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                seamName,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  grade,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: badgeColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildSeamParam(Icons.local_fire_department_rounded, calori, const Color(0xFFDC2626)),
              _buildSeamParam(Icons.grain_rounded, ash, const Color(0xFF64748B)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildSeamParam(Icons.water_drop_rounded, tm, const Color(0xFF0284C7)),
              _buildSeamParam(Icons.science_rounded, sulfur, const Color(0xFF7C3AED)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSeamParam(IconData icon, String label, Color color) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
          ),
        ],
      ),
    );
  }

  // 3. Status Pit Modal
  void _showPitStatusModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
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
                Icon(Icons.analytics_rounded, color: Color(0xFFD97706), size: 26),
                SizedBox(width: 8),
                Text(
                  'Indikator Operasional Pit Utama',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildPitStatusItem('CCM Quality Index', '98.4%', 'Target kepatuhan tercapai', const Color(0xFF10B981)),
            _buildPitStatusItem('Kapasitas ROM Stockpile', '185,200 MT', '72% dari kapasitas maksimum', const Color(0xFF0284C7)),
            _buildPitStatusItem('Stabilitas Lereng (FoS)', '1.42 FoS', 'Aman & stabil (Batas minimum: 1.30)', const Color(0xFF059669)),
            _buildPitStatusItem('Fleet Availability (PA)', '89.6%', '142 Haul Truck & 18 Excavator loader', const Color(0xFF7C3AED)),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Tutup', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPitStatusItem(String title, String value, String subtitle, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
            ],
          ),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }
}

class _MenuItem {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String? badge;
  final VoidCallback onTap;

  const _MenuItem({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    this.badge,
    required this.onTap,
  });
}

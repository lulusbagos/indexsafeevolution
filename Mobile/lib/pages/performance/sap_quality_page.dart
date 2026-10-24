import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/profile_model.dart';
import '../../models/sap_quality_model.dart';
import '../../services/api.dart';
import '../../services/preference.dart';

class SapQualityPage extends StatefulWidget {
  const SapQualityPage({super.key});

  @override
  State<SapQualityPage> createState() => _SapQualityPageState();
}

class _SapQualityPageState extends State<SapQualityPage> {
  final ApiService _api = ApiService();
  ProfileModel? _profile;

  bool _isLoading = true;
  String? _errorMessage;
  SapQualityDashboardModel? _data;

  int? _selectedYear;
  int? _selectedMonth;
  String _activeFilter = 'all'; // 'all', 'high', 'low', 'hazard', 'inspection', 'safetytalk', 'observation', 'coaching'
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  final List<int> _availableYears = [2024, 2025, 2026];
  final List<String> _monthNames = const [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  @override
  void initState() {
    super.initState();
    _profile = PreferenceService.getProfile();
    _loadDashboardData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final nik = _profile?.noNik?.trim() ?? '';

    final result = await _api.getSapQualityDashboard(
      nik: nik,
      year: _selectedYear,
      month: _selectedMonth,
    );

    if (!mounted) return;

    result.fold(
      (err) {
        setState(() {
          _isLoading = false;
          _errorMessage = err['message']?.toString() ?? 'Gagal memuat kualitas SAP.';
        });
      },
      (data) {
        setState(() {
          _isLoading = false;
          _data = SapQualityDashboardModel.fromJson(data);
        });
      },
    );
  }

  void _resetFilter() {
    setState(() {
      _selectedYear = null;
      _selectedMonth = null;
      _activeFilter = 'all';
      _searchQuery = '';
      _searchCtrl.clear();
    });
    _loadDashboardData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kualitas & Mutu SAP',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Audit AI & Pengawas • Pilar Mutu 25% PTS',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, size: 22),
            tooltip: 'Panduan Mutu Bintang',
            onPressed: () => _showQualityGuidelineModal(context),
          ),
          IconButton(
            icon: const Icon(Icons.copy_all_rounded, size: 22),
            tooltip: 'Salin Ringkasan Mutu',
            onPressed: _data != null ? () => _copyQualitySummaryReport(_data!) : null,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            tooltip: 'Segarkan Data',
            onPressed: _loadDashboardData,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Menganalisis Kualitas SAP NIK...',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Memverifikasi standar mutu isi & audit pengawas',
              style: TextStyle(
                fontSize: 11.5,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: const Icon(Icons.error_outline_rounded, size: 40, color: Color(0xFFEF4444)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Gagal Memuat Kualitas SAP',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadDashboardData,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final d = _data;
    if (d == null) return const SizedBox.shrink();

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      color: const Color(0xFF0284C7),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
        children: [
          // 1. Executive Dark Hero Banner with Indeks Mutu K3
          _buildExecutiveHeroCard(d),
          const SizedBox(height: 14),

          // 2. Interactive Period Selector Chip Bar
          _buildPeriodFilterBar(),
          const SizedBox(height: 16),

          // 3. 4-Card Executive Metric Grid
          _buildExecutiveStatGrid(d),
          const SizedBox(height: 16),

          // 4. Kualitas Hasil Audit (Ratio Gauge & Compliance Card)
          _buildQualityDonutCard(d),
          const SizedBox(height: 16),

          // 5. Modul SAP Average Ratings (5 Modules)
          _buildModuleRatingsCard(d),
          const SizedBox(height: 16),

          // 6. Star Breakdown Progress Bars (1 to 5 Stars)
          _buildStarBreakdownCard(d),
          const SizedBox(height: 20),

          // 7. Submissions & Item-level Audit Feed with Search & Filters
          _buildItemsSection(d),
        ],
      ),
    );
  }

  // ==========================================
  // 1. EXECUTIVE DARK HERO BANNER
  // ==========================================
  Widget _buildExecutiveHeroCard(SapQualityDashboardModel d) {
    final qualityScore = d.qualityScorePercent;
    final rating = d.averageRating;

    String gradeText;
    Color gradeColor;
    if (qualityScore >= 90) {
      gradeText = 'MUTU TINGGI (A+)';
      gradeColor = const Color(0xFF10B981);
    } else if (qualityScore >= 80) {
      gradeText = 'BAIK & SESUAI (A)';
      gradeColor = const Color(0xFF38BDF8);
    } else if (qualityScore >= 70) {
      gradeText = 'STANDAR MINIMAL (B)';
      gradeColor = const Color(0xFFF59E0B);
    } else {
      gradeText = 'PERLU PEMBINAAN (C)';
      gradeColor = const Color(0xFFF87171);
    }

    final periodLabel = _selectedYear != null || _selectedMonth != null
        ? '${_selectedMonth != null ? _monthNames[_selectedMonth! - 1] : "Semua Bulan"} ${_selectedYear ?? ""}'
        : 'Akumulasi Periode';

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF38BDF8).withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Identity Row
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Row(
              children: [
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0284C7), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.verified_user_rounded, color: Colors.white, size: 24),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              d.nama.isNotEmpty ? d.nama : (_profile?.namaLengkap ?? 'User NIK'),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFF10B981).withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Text(
                              'NIK Saya',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF34D399),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'NIK: ${d.nik} • ${d.departemen}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        d.perusahaan,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF38BDF8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFF334155)),

          // Main Quality Score Display
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: gradeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: gradeColor.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              gradeText,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: gradeColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            periodLabel,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${qualityScore.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Indeks Mutu K3',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Pilar Ke-3 Formula PTS Klasemen (Bobot 25%)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),

                // Star Rating Capsule
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 28),
                      const SizedBox(height: 2),
                      Text(
                        rating > 0 ? rating.toStringAsFixed(2) : '0.00',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        'Skala 5.0 ★',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom 3-Pillar Micro Diagnostics
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF090E17),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMicroStatItem(
                  label: 'Lolos Riil',
                  value: '${d.goodPercentage}%',
                  sub: '${d.kualitasBaik} Lap',
                  color: const Color(0xFF10B981),
                ),
                Container(width: 1, height: 24, color: const Color(0xFF1E293B)),
                _buildMicroStatItem(
                  label: 'Kejar Target',
                  value: '${d.targetPercentage}%',
                  sub: '${d.kejarTarget} Lap',
                  color: const Color(0xFFEF4444),
                ),
                Container(width: 1, height: 24, color: const Color(0xFF1E293B)),
                _buildMicroStatItem(
                  label: 'Diaudit',
                  value: '${d.totalAssessed}',
                  sub: 'dari ${d.totalAllSap}',
                  color: const Color(0xFF38BDF8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicroStatItem({
    required String label,
    required String value,
    required String sub,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color),
            ),
            const SizedBox(width: 3),
            Text(
              sub,
              style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // 2. INTERACTIVE PERIOD FILTER BAR
  // ==========================================
  Widget _buildPeriodFilterBar() {
    final hasActiveFilter = _selectedYear != null || _selectedMonth != null;

    final yearText = _selectedYear != null ? 'Tahun $_selectedYear' : 'Semua Tahun';
    final monthText = _selectedMonth != null ? _monthNames[_selectedMonth! - 1] : 'Semua Bulan';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.date_range_rounded, size: 16, color: Color(0xFF0284C7)),
          ),
          const SizedBox(width: 10),
          const Text(
            'Periode:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(width: 8),

          // Year Picker Pill
          Expanded(
            child: InkWell(
              onTap: () => _showPeriodPickerModal(isMonth: false),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: _selectedYear != null ? const Color(0xFFE0F2FE) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _selectedYear != null ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        yearText,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: _selectedYear != null ? const Color(0xFF0369A1) : const Color(0xFF475569),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Month Picker Pill
          Expanded(
            child: InkWell(
              onTap: () => _showPeriodPickerModal(isMonth: true),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: _selectedMonth != null ? const Color(0xFFE0F2FE) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _selectedMonth != null ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        monthText,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: _selectedMonth != null ? const Color(0xFF0369A1) : const Color(0xFF475569),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
                  ],
                ),
              ),
            ),
          ),

          if (hasActiveFilter) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: _resetFilter,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFEF4444)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // 3. EXECUTIVE 4-CARD STAT GRID
  // ==========================================
  Widget _buildExecutiveStatGrid(SapQualityDashboardModel d) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'TOTAL SUBMISI SAP',
                value: '${d.totalAllSap}',
                unit: 'Laporan',
                subText: '5 Program Pelaporan',
                icon: Icons.layers_rounded,
                color: const Color(0xFF0F172A),
                bgColor: const Color(0xFFF1F5F9),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                title: 'SUDAH DIAUDIT',
                value: '${d.totalAssessed}',
                unit: 'Data',
                subText: '${d.auditedBySupervisorCount} Oleh Pengawas',
                icon: Icons.verified_rounded,
                color: const Color(0xFF0284C7),
                bgColor: const Color(0xFFE0F2FE),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'KUALITAS BAIK (⭐3-5)',
                value: '${d.kualitasBaik}',
                unit: '(${d.goodPercentage}%)',
                subText: 'Lolos Standar Riil K3',
                icon: Icons.thumb_up_rounded,
                color: const Color(0xFF10B981),
                bgColor: const Color(0xFFECFDF5),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                title: 'KEJAR TARGET (⭐1-2)',
                value: '${d.kejarTarget}',
                unit: '(${d.targetPercentage}%)',
                subText: 'Formalitas / Minim Mitigasi',
                icon: Icons.warning_amber_rounded,
                color: const Color(0xFFEF4444),
                bgColor: const Color(0xFFFEF2F2),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String unit,
    required String subText,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  unit,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: color.withValues(alpha: 0.85),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            subText,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF94A3B8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 4. QUALITY RATIO GAUGE & COMPLIANCE CARD
  // ==========================================
  Widget _buildQualityDonutCard(SapQualityDashboardModel d) {
    final double goodFraction = d.totalAssessed > 0 ? (d.kualitasBaik / d.totalAssessed) : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.pie_chart_rounded, size: 18, color: Color(0xFF0284C7)),
                  SizedBox(width: 8),
                  Text(
                    'Kualitas Hasil Audit',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${d.totalAssessed} Diaudit',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0369A1),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          const Text(
            'Rasio kelayakan data SAP lolos standar rill vs formalitas kejar target.',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 18),

          if (d.totalAssessed == 0)
            Container(
              height: 120,
              alignment: Alignment.center,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_late_outlined, size: 36, color: Color(0xFF94A3B8)),
                  SizedBox(height: 6),
                  Text(
                    'Belum ada data SAP yang diaudit pada periode ini.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            )
          else ...[
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    height: 136,
                    width: 136,
                    child: CircularProgressIndicator(
                      value: goodFraction,
                      strokeWidth: 14,
                      backgroundColor: const Color(0xFFF87171),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${d.goodPercentage}%',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Text(
                        'Lolos Standar',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF059669)),
                            SizedBox(width: 4),
                            Text(
                              'Kualitas Riil (⭐3-5)',
                              style: TextStyle(fontSize: 10.5, color: Color(0xFF047857), fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${d.goodPercentage}% (${d.kualitasBaik} Data)',
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Color(0xFF065F46)),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Laporan valid & mitigasi jelas',
                          style: TextStyle(fontSize: 9.5, color: Color(0xFF059669), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFDC2626)),
                            SizedBox(width: 4),
                            Text(
                              'Kejar Target (⭐1-2)',
                              style: TextStyle(fontSize: 10.5, color: Color(0xFFB91C1C), fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${d.targetPercentage}% (${d.kejarTarget} Data)',
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Color(0xFF991B1B)),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Frasa klise / administratif',
                          style: TextStyle(fontSize: 9.5, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Rule Transparency Note
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, size: 14, color: Color(0xFF64748B)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Laporan ⭐1-2 tetap dihitung pada jumlah capaian fisik, namun mendepresiasi skor Mutu 25% PTS.',
                      style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // 5. MODUL SAP AVERAGE RATINGS (5 Modules)
  // ==========================================
  Widget _buildModuleRatingsCard(SapQualityDashboardModel d) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_graph_rounded, size: 19, color: Color(0xFFF59E0B)),
                  SizedBox(width: 8),
                  Text(
                    'Rata-Rata Mutu per Modul SAP',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Skala 1.0 - 5.0 ★',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          const Text(
            'Klik pada salah satu modul untuk memfilter riwayat submisi di bawah.',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),

          ...d.moduleStats.map((m) {
            final double ratingFraction = (m.averageRating / 5.0).clamp(0.0, 1.0);
            final isModuleActive = _activeFilter == m.key.toLowerCase();

            return InkWell(
              onTap: () {
                setState(() {
                  _activeFilter = isModuleActive ? 'all' : m.key.toLowerCase();
                });
              },
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isModuleActive ? m.parsedColor.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isModuleActive ? m.parsedColor : const Color(0xFFE2E8F0),
                    width: isModuleActive ? 1.5 : 1.0,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: m.parsedColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(m.iconData, size: 16, color: m.parsedColor),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                Text(
                                  '${m.assessed} dari ${m.total} laporan diaudit',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: m.parsedColor,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: m.parsedColor.withValues(alpha: 0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            '⭐ ${m.averageRating.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: ratingFraction,
                        minHeight: 6,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(m.parsedColor),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ==========================================
  // 6. STAR BREAKDOWN CARD (1 - 5 Stars)
  // ==========================================
  Widget _buildStarBreakdownCard(SapQualityDashboardModel d) {
    final stars = [
      {'stars': 5, 'label': '⭐ 5 Bintang (Sangat Baik)', 'desc': 'Rinci, mitigasi jelas & tuntas', 'count': d.star5, 'color': const Color(0xFF10B981)},
      {'stars': 4, 'label': '⭐ 4 Bintang (Baik)', 'desc': 'Kriteria pelaporan riil terpenuhi', 'count': d.star4, 'color': const Color(0xFF34D399)},
      {'stars': 3, 'label': '⭐ 3 Bintang (Cukup)', 'desc': 'Detail dasar dengan mitigasi standar', 'count': d.star3, 'color': const Color(0xFF60A5FA)},
      {'stars': 2, 'label': '⭐ 2 Bintang (Kurang)', 'desc': 'Frasa klise / deskripsi terbatas', 'count': d.star2, 'color': const Color(0xFFF87171)},
      {'stars': 1, 'label': '⭐ 1 Bintang (Kejar Target)', 'desc': 'Formalitas administratif / minimalis', 'count': d.star1, 'color': const Color(0xFFEF4444)},
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.star_half_rounded, size: 19, color: Color(0xFFF59E0B)),
                  SizedBox(width: 8),
                  Text(
                    'Distribusi Skala Bintang Audit',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.help_outline_rounded, size: 18, color: Color(0xFF64748B)),
                onPressed: () => _showQualityGuidelineModal(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'Proporsi kualitas input berdasarkan evaluasi supervisor & AI engine.',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),

          ...stars.map((s) {
            final count = s['count'] as int;
            final double pct = d.totalAssessed > 0 ? ((count / d.totalAssessed) * 100.0) : 0.0;
            final color = s['color'] as Color;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          s['label'] as String,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '$count data (${pct.toStringAsFixed(1)}%)',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    s['desc'] as String,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: (pct / 100.0).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: const Color(0xFFF1F5F9),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ==========================================
  // 7. SUBMISSIONS & ITEM-LEVEL AUDIT FEED
  // ==========================================
  Widget _buildItemsSection(SapQualityDashboardModel d) {
    // 1. Filter by program / rating
    List<SapQualityItemModel> list = d.items.where((it) {
      if (_activeFilter == 'all') return true;
      if (_activeFilter == 'high') return it.rating >= 3;
      if (_activeFilter == 'low') return it.rating < 3;
      if (_activeFilter == 'hazard') return it.programType.toLowerCase() == 'hazard';
      if (_activeFilter == 'inspection') return it.programType.toLowerCase() == 'inspection';
      if (_activeFilter == 'safetytalk') return it.programType.toLowerCase() == 'safetytalk';
      if (_activeFilter == 'observation') return it.programType.toLowerCase() == 'observation';
      if (_activeFilter == 'coaching') return it.programType.toLowerCase() == 'coaching';
      return true;
    }).toList();

    // 2. Filter by search query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = list.where((it) {
        final title = it.title.toLowerCase();
        final desc = it.description.toLowerCase();
        final loc = (it.lokasi ?? '').toLowerCase();
        final pType = it.programType.toLowerCase();
        final notes = (it.notes ?? '').toLowerCase();
        return title.contains(q) || desc.contains(q) || loc.contains(q) || pType.contains(q) || notes.contains(q);
      }).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.format_list_bulleted_rounded, size: 19, color: Color(0xFF0284C7)),
                SizedBox(width: 8),
                Text(
                  'Riwayat Submisi & Evaluasi Mutu',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${list.length} Data',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0369A1)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Search Input Bar
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x060F172A),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Cari judul, isi temuan, lokasi...',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Filter chips row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('all', 'Semua (${d.items.length})'),
              _buildFilterChip('high', '⭐ 3-5 Baik (${d.kualitasBaik})'),
              _buildFilterChip('low', '⭐ 1-2 Kejar Target (${d.kejarTarget})'),
              _buildFilterChip('hazard', 'Hazard'),
              _buildFilterChip('inspection', 'Inspeksi'),
              _buildFilterChip('safetytalk', 'Safety Talk'),
              _buildFilterChip('observation', 'Observasi'),
              _buildFilterChip('coaching', 'Coaching'),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (list.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                const Icon(Icons.assignment_late_outlined, size: 40, color: Color(0xFF94A3B8)),
                const SizedBox(height: 8),
                const Text(
                  'Tidak ada laporan SAP yang cocok dengan filter.',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                ),
                if (_searchQuery.isNotEmpty || _activeFilter != 'all') ...[
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() {
                        _searchQuery = '';
                        _activeFilter = 'all';
                      });
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Reset Filter Pencarian'),
                  ),
                ],
              ],
            ),
          )
        else
          ...list.map((item) => _buildSubmissionItemCard(item)),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _activeFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _activeFilter = key),
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected ? Colors.white : const Color(0xFF475569),
        ),
        selectedColor: const Color(0xFF0F172A),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // HIGH-END SUBMISSION ITEM CARD
  // ==========================================
  Widget _buildSubmissionItemCard(SapQualityItemModel it) {
    final bool isGoodQuality = it.rating >= 3;
    final bool hasPhoto = it.photoUrl != null && it.photoUrl!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isGoodQuality ? const Color(0xFFE2E8F0) : const Color(0xFFFECACA),
          width: 1.3,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Program Badge, Date, Location
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: it.programColor,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: it.programColor.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(it.programIcon, size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      it.programType.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 11, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text(
                    it.tanggalFormatted,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Title & Location
          Text(
            it.title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),

          if (it.lokasi != null && it.lokasi!.isNotEmpty) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                const Icon(Icons.location_on_rounded, size: 12, color: Color(0xFFEF4444)),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    it.lokasi!,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),

          // Hazard Priority Tag (if hazard)
          if (it.programType.toLowerCase() == 'hazard' && it.hazardPriority != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt_rounded, size: 13, color: Color(0xFFD97706)),
                  const SizedBox(width: 4),
                  Text(
                    'Prioritas SLA: ${it.hazardPriority} (${it.hazardDueDateText ?? ""})',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Description Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              it.description,
              style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.4),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),

          // Photo Preview (if photo attachment exists)
          if (hasPhoto) ...[
            GestureDetector(
              onTap: () => _showPhotoPreviewModal(it.photoUrl!),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        it.photoUrl!,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 44,
                          height: 44,
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.broken_image_rounded, size: 20, color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lampiran Dokumentasi Foto',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                          ),
                          Text(
                            'Ketuk untuk melihat foto ukuran penuh',
                            style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.zoom_in_rounded, size: 18, color: Color(0xFF0284C7)),
                  ],
                ),
              ),
            ),
          ],

          // Rating Stars & Quality Label Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  ...List.generate(5, (starIdx) {
                    final starVal = starIdx + 1;
                    final isFilled = it.rating >= starVal;
                    return Icon(
                      Icons.star_rounded,
                      size: 19,
                      color: isFilled ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
                    );
                  }),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: it.parsedQualityColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: it.parsedQualityColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      it.qualityLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: it.parsedQualityColor,
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: it.isAuditedBySupervisor ? const Color(0xFFEFF6FF) : const Color(0xFFFAF5FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: it.isAuditedBySupervisor ? const Color(0xFFBFDBFE) : const Color(0xFFE9D5FF),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      it.isAuditedBySupervisor ? Icons.verified_rounded : Icons.smart_toy_outlined,
                      size: 12,
                      color: it.isAuditedBySupervisor ? const Color(0xFF2563EB) : const Color(0xFF9333EA),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      it.isAuditedBySupervisor ? 'Audit Pengawas' : 'Evaluasi AI',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: it.isAuditedBySupervisor ? const Color(0xFF2563EB) : const Color(0xFF9333EA),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Reviewer Notes Callout
          if (it.notes != null && it.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.rate_review_rounded, size: 14, color: Color(0xFFD97706)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      it.notes!,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF92400E), height: 1.35, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),

          // Action Detail Button
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: () => _showItemDetailModal(it),
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Lihat Rincian Audit',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF0284C7)),
                    ),
                    SizedBox(width: 2),
                    Icon(Icons.arrow_forward_ios_rounded, size: 11, color: Color(0xFF0284C7)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // MODALS & BOTTOM SHEETS
  // ==========================================

  void _showPeriodPickerModal({required bool isMonth}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isMonth ? 'Pilih Bulan Laporan' : 'Pilih Tahun Laporan',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (!isMonth) ...[
                ListTile(
                  leading: const Icon(Icons.all_inclusive_rounded, color: Color(0xFF0284C7)),
                  title: const Text('Semua Tahun', style: TextStyle(fontWeight: FontWeight.w700)),
                  selected: _selectedYear == null,
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _selectedYear = null);
                    _loadDashboardData();
                  },
                ),
                ..._availableYears.map((y) => ListTile(
                      leading: const Icon(Icons.calendar_today_rounded, color: Color(0xFF0284C7)),
                      title: Text('Tahun $y', style: const TextStyle(fontWeight: FontWeight.w700)),
                      selected: _selectedYear == y,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() => _selectedYear = y);
                        _loadDashboardData();
                      },
                    )),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.all_inclusive_rounded, color: Color(0xFF0284C7)),
                  title: const Text('Semua Bulan', style: TextStyle(fontWeight: FontWeight.w700)),
                  selected: _selectedMonth == null,
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _selectedMonth = null);
                    _loadDashboardData();
                  },
                ),
                SizedBox(
                  height: 320,
                  child: ListView.builder(
                    itemCount: 12,
                    itemBuilder: (c, idx) {
                      final m = idx + 1;
                      return ListTile(
                        leading: Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _selectedMonth == m ? const Color(0xFF0284C7) : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$m',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _selectedMonth == m ? Colors.white : const Color(0xFF475569),
                            ),
                          ),
                        ),
                        title: Text(_monthNames[idx], style: const TextStyle(fontWeight: FontWeight.w700)),
                        selected: _selectedMonth == m,
                        onTap: () {
                          Navigator.pop(ctx);
                          setState(() => _selectedMonth = m);
                          _loadDashboardData();
                        },
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showQualityGuidelineModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.verified_rounded, color: Color(0xFF0284C7), size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Panduan Standar Mutu SAP',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Metodologi Penilaian Kualitas (1-5 Bintang) & Bobot PTS Klasemen Karyawan',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),

              _buildGuidelineStarItem(
                stars: '⭐⭐⭐⭐⭐ 5 Bintang',
                title: 'Sangat Baik (Lolos Riil K3)',
                desc: 'Temuan riil berisiko tinggi/sedang, deskripsi lengkap 5W+1H, tindakan mitigasi langsung terukur, foto dokumentasi valid.',
                color: const Color(0xFF10B981),
              ),
              _buildGuidelineStarItem(
                stars: '⭐⭐⭐⭐ 4 Bintang',
                title: 'Baik (Lolos Riil K3)',
                desc: 'Kriteria pelaporan riil terpenuhi, tindakan korektif ada, foto dokumentasi relevan.',
                color: const Color(0xFF34D399),
              ),
              _buildGuidelineStarItem(
                stars: '⭐⭐⭐ 3 Bintang',
                title: 'Cukup (Lolos Riil K3)',
                desc: 'Temuan umum/standar, tindakan perbaikan minimal, foto cukup memadai.',
                color: const Color(0xFF60A5FA),
              ),
              _buildGuidelineStarItem(
                stars: '⭐⭐ 2 Bintang',
                title: 'Kurang (Kejar Target / Formalitas)',
                desc: 'Deskripsi singkat/klise, tindakan korektif tidak spesifik, atau foto kurang relevan.',
                color: const Color(0xFFF87171),
              ),
              _buildGuidelineStarItem(
                stars: '⭐ 1 Bintang',
                title: 'Kejar Target (Formalitas Administratif)',
                desc: 'Copy-paste, deskripsi tidak logis, foto blank/gelap/asal, hanya untuk mengejar jumlah target fisik.',
                color: const Color(0xFFEF4444),
              ),

              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_rounded, color: Color(0xFF0284C7), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Formula Klasemen Karyawan: (35% × Capaian) + (30% × Close Rate) + (25% × Mutu K3) + (10% × Beban). Menjaga mutu laporan tinggi memaksimalkan skor 25% Mutu!',
                        style: TextStyle(fontSize: 10.5, color: Color(0xFF1E40AF), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGuidelineStarItem({
    required String stars,
    required String title,
    required String desc,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(stars, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    const SizedBox(width: 6),
                    Text('• $title', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showItemDetailModal(SapQualityItemModel it) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: it.programColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      it.programType.toUpperCase(),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                it.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 4),
              Text(
                'Tanggal: ${it.tanggalFormatted} ${it.lokasi != null ? "• Lokasi: ${it.lokasi}" : ""}',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),

              const Text('Deskripsi Isi Temuan / Kegiatan:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569))),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(it.description, style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.4)),
              ),
              const SizedBox(height: 14),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Rating & Evaluasi Mutu:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569))),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          ...List.generate(5, (starIdx) {
                            final isFilled = it.rating >= (starIdx + 1);
                            return Icon(
                              Icons.star_rounded,
                              size: 20,
                              color: isFilled ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
                            );
                          }),
                          const SizedBox(width: 8),
                          Text('⭐ ${it.rating} / 5', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: it.parsedQualityColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: it.parsedQualityColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      it.qualityLabel,
                      style: TextStyle(fontWeight: FontWeight.w900, color: it.parsedQualityColor, fontSize: 11),
                    ),
                  ),
                ],
              ),

              if (it.notes != null && it.notes!.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text('Catatan Evaluator / AI:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569))),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Text(it.notes!, style: const TextStyle(fontSize: 12, color: Color(0xFF92400E), height: 1.4)),
                ),
              ],

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final textToCopy = 'LAPORAN SAP: ${it.title}\nModul: ${it.programType}\nTanggal: ${it.tanggalFormatted}\nDeskripsi: ${it.description}\nRating: ⭐ ${it.rating} (${it.qualityLabel})\nCatatan: ${it.notes ?? "-"}';
                    Clipboard.setData(ClipboardData(text: textToCopy));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Rincian laporan berhasil disalin ke clipboard!'),
                        backgroundColor: Color(0xFF10B981),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Salin Rincian Laporan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPhotoPreviewModal(String photoUrl) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: InteractiveViewer(
                  child: Image.network(
                    photoUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 200,
                      color: Colors.white,
                      alignment: Alignment.center,
                      child: const Text('Gagal memuat foto lampiran.'),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: Icon(Icons.close_rounded, color: Colors.white, size: 20),
                ),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
  }

  void _copyQualitySummaryReport(SapQualityDashboardModel d) {
    final buffer = StringBuffer();
    buffer.writeln('========================================');
    buffer.writeln('RINGKASAN AUDIT MUTU & KUALITAS SAP');
    buffer.writeln('========================================');
    buffer.writeln('👤 Karyawan   : ${d.nama} (${d.nik})');
    buffer.writeln('🏢 Departemen : ${d.departemen}');
    buffer.writeln('🏢 Perusahaan : ${d.perusahaan}');
    buffer.writeln('');
    buffer.writeln('📊 INDIKATOR MUTU K3 (25% BOBOT PTS):');
    buffer.writeln('• Skor Mutu K3    : ${d.qualityScorePercent.toStringAsFixed(1)}%');
    buffer.writeln('• Rata-rata Rating: ⭐ ${d.averageRating.toStringAsFixed(2)} / 5.0');
    buffer.writeln('• Total Submisi   : ${d.totalAllSap} Laporan');
    buffer.writeln('• Tervalidasi     : ${d.totalAssessed} (${d.auditedBySupervisorCount} Pengawas)');
    buffer.writeln('• Lolos Riil      : ${d.goodPercentage}% (${d.kualitasBaik} Laporan)');
    buffer.writeln('• Kejar Target    : ${d.targetPercentage}% (${d.kejarTarget} Laporan)');
    buffer.writeln('');
    buffer.writeln('⭐ DISTRIBUSI BINTANG AUDIT:');
    buffer.writeln('• ⭐ 5 Bintang : ${d.star5} Laporan');
    buffer.writeln('• ⭐ 4 Bintang : ${d.star4} Laporan');
    buffer.writeln('• ⭐ 3 Bintang : ${d.star3} Laporan');
    buffer.writeln('• ⭐ 2 Bintang : ${d.star2} Laporan');
    buffer.writeln('• ⭐ 1 Bintang : ${d.star1} Laporan');
    buffer.writeln('');
    buffer.writeln('📌 RATA-RATA MUTU PER MODUL:');
    for (final m in d.moduleStats) {
      buffer.writeln('• ${m.name}: ⭐ ${m.averageRating.toStringAsFixed(2)} (${m.assessed}/${m.total} diaudit)');
    }
    buffer.writeln('');
    buffer.writeln('Generated via Indexsafe Evolution Mobile - PT Indexim Coalindo');
    buffer.writeln('========================================');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Ringkasan Mutu SAP berhasil disalin ke clipboard! Siap dibagikan ke WhatsApp.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        backgroundColor: Color(0xFF10B981),
        duration: Duration(seconds: 3),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api.dart';
import '../../services/preference.dart';
import '../../widgets/top_bar.dart';

class ExecutiveReportsPage extends StatefulWidget {
  const ExecutiveReportsPage({super.key});

  @override
  State<ExecutiveReportsPage> createState() => _ExecutiveReportsPageState();
}

class _ExecutiveReportsPageState extends State<ExecutiveReportsPage> {
  final ApiService _api = ApiService();
  final _profile = PreferenceService.getProfile();

  bool _isLoading = true;
  String _departmentName = 'Departemen';
  String _companyName = 'PT INDEXIM COALINDO';
  String _period = 'Oktober 2026';
  List<dynamic> _standings = [];
  int _totalEmployees = 0;
  int _totalLeaguePlayers = 453;

  // Periodic Export Modal state
  int _startMonth = 1;
  int _startYear = 2026;
  int _endMonth = 10;
  int _endYear = 2026;
  String _targetFilter = 'target'; // target, all, nontarget_active

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _endMonth = now.month;
    _endYear = now.year;
    _startYear = now.year;
    _startMonth = 1;
    _fetchSquadData();
  }

  Future<void> _fetchSquadData() async {
    setState(() => _isLoading = true);
    try {
      final userNik = _profile?.noNik?.trim() ?? '';
      final userDept = _profile?.depart?.trim() ?? '';
      final compId = _profile?.companyId;

      final res = await _api.getDepartmentSquad(
        nik: userNik,
        departmentName: userDept.isNotEmpty ? userDept : null,
        companyId: compId,
      );

      res.fold(
        (err) {
          if (mounted) setState(() => _isLoading = false);
        },
        (resp) {
          if (mounted) {
            final data = resp['data'] as Map<String, dynamic>? ?? {};
            final list = (data['standings'] as List<dynamic>?) ?? [];
            setState(() {
              _departmentName = data['departmentName']?.toString() ??
                  _profile?.depart ??
                  'Departemen';
              _companyName = data['companyName']?.toString() ??
                  'PT INDEXIM COALINDO';
              _period = data['period']?.toString() ?? 'Oktober 2026';
              _totalEmployees = list.length;
              _totalLeaguePlayers =
                  int.tryParse(data['totalLeaguePlayers']?.toString() ?? '453') ??
                      453;
              _standings = list;
              _isLoading = false;
            });
          }
        },
      );
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate macro metrics
    double totalScoreSum = 0;
    double complianceSum = 0;
    double closeRateSum = 0;
    int totalSafetyReportsSum = 0;
    final count = _standings.length;

    int compliantCount = 0; // >=80%
    int attentionCount = 0; // 40-79%
    int uncompliantCount = 0; // <40% or not 100%

    for (final m in _standings) {
      final score = (m['totalScore'] as num?)?.toDouble() ?? 0.0;
      final comp = (m['complianceRate'] as num?)?.toDouble() ?? 0.0;
      final cr = (m['closeRate'] as num?)?.toDouble() ?? 100.0;
      final reps = (m['totalActualAll'] as num?)?.toInt() ??
          ((m['totalActual'] as num?)?.toInt() ?? 0);

      totalScoreSum += score;
      complianceSum += comp;
      closeRateSum += cr;
      totalSafetyReportsSum += reps;

      if (comp >= 80.0) {
        compliantCount++;
      } else if (comp >= 40.0) {
        attentionCount++;
      } else {
        uncompliantCount++;
      }
    }

    final avgScore = count > 0 ? (totalScoreSum / count) : 0.0;
    final avgCompliance = count > 0 ? (complianceSum / count) : 0.0;
    final avgCloseRate = count > 0 ? (closeRateSum / count) : 100.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: const TopBar(
        title: 'Pusat Laporan & Ekspor K3',
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF0284C7)),
                  SizedBox(height: 12),
                  Text(
                    'Memuat Data Laporan Eksekutif...',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchSquadData,
              color: const Color(0xFF0284C7),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 36),
                children: [
                  // Top Banner Header
                  _buildHeaderBanner(),
                  const SizedBox(height: 14),

                  // Macro Metrics Strip
                  _buildMacroKpiStrip(
                    avgScore: avgScore,
                    avgCompliance: avgCompliance,
                    totalReports: totalSafetyReportsSum,
                    avgCloseRate: avgCloseRate,
                    squadCount: count,
                  ),
                  const SizedBox(height: 18),

                  // Section Title
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 18,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'MODUL LAPORAN & EKSPOR DATA RESMI',
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // CARD 1: Laporan Kepatuhan Detail Karyawan
                  _buildReportCard(
                    icon: Icons.person_search_rounded,
                    iconColor: const Color(0xFF2563EB),
                    iconBg: const Color(0xFFDBEAFE),
                    title: 'Laporan Kepatuhan Detail',
                    subtitle:
                        'Lihat dan salin rekapitulasi kepatuhan per karyawan dengan kategori status (Patuh, Perhatian, Kurang) & pencarian lengkap.',
                    badgeText: 'Audit Detail',
                    badgeColor: const Color(0xFF2563EB),
                    buttonText: 'Buka Audit Kepatuhan Skuad',
                    buttonColor: const Color(0xFF2563EB),
                    onTap: () => _showComplianceAuditModal(context),
                  ),
                  const SizedBox(height: 12),

                  // CARD 2: Laporan Uncompliant / Pembinaan K3
                  _buildReportCard(
                    icon: Icons.assignment_late_rounded,
                    iconColor: const Color(0xFFE11D48),
                    iconBg: const Color(0xFFFFE4E6),
                    title: 'Laporan Uncompliant (Pembinaan K3)',
                    subtitle:
                        'Daftar pengawas & karyawan yang belum memenuhi target program K3 untuk intervensi pembinaan langsung via WhatsApp.',
                    badgeText: '${count - compliantCount} Belum 100%',
                    badgeColor: const Color(0xFFE11D48),
                    buttonText: 'Rekap Pembinaan & Salin WA',
                    buttonColor: const Color(0xFFE11D48),
                    onTap: () => _showUncompliantCoachingModal(context),
                  ),
                  const SizedBox(height: 12),

                  // CARD 3: Export Klasemen Super League (.xlsx)
                  _buildReportCard(
                    icon: Icons.table_chart_rounded,
                    iconColor: const Color(0xFF16A34A),
                    iconBg: const Color(0xFFDCFCE7),
                    title: 'Export Klasemen League (Excel)',
                    subtitle:
                        'Download data klasemen kepatuhan antar perusahaan dan departemen lengkap dengan 4 pilar bobot resmi.',
                    badgeText: 'Format .XLSX',
                    badgeColor: const Color(0xFF16A34A),
                    buttonText: 'Unduh Excel Klasemen',
                    buttonColor: const Color(0xFF16A34A),
                    onTap: () => _downloadWebExcel(
                      'ExportLeagueToExcel?mode=dept&year=${DateTime.now().year}&month=${DateTime.now().month}&targetFilter=target',
                      'Klasemen_League_${_period.replaceAll(' ', '_')}.xlsx',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // CARD 4: Export Detail SAP Karyawan (.xlsx)
                  _buildReportCard(
                    icon: Icons.badge_rounded,
                    iconColor: const Color(0xFF9333EA),
                    iconBg: const Color(0xFFF3E8FF),
                    title: 'Export Detail SAP Karyawan',
                    subtitle:
                        'Download rincian target & realisasi 6 pilar SAP (Hazard, Inspeksi, ST, Obs, Coach, P5M) untuk setiap personil.',
                    badgeText: 'Format .XLSX',
                    badgeColor: const Color(0xFF9333EA),
                    buttonText: 'Unduh Detail SAP Karyawan',
                    buttonColor: const Color(0xFF9333EA),
                    onTap: () => _downloadWebExcel(
                      'ExportSapDetailToExcel?mode=dept&year=${DateTime.now().year}&month=${DateTime.now().month}&targetFilter=target',
                      'Detail_SAP_Karyawan_${_period.replaceAll(' ', '_')}.xlsx',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // CARD 5: Download Report SAP Rentang Periode (Multi-Bulan)
                  _buildReportCard(
                    icon: Icons.date_range_rounded,
                    iconColor: const Color(0xFFD97706),
                    iconBg: const Color(0xFFFEF3C7),
                    title: 'Report SAP Rentang Periode (Multi-Bulan)',
                    subtitle:
                        'Download workbook Excel resmi lintas bulan dengan 3 Sheet: Rekapitulasi Departemen, Pencapaian Karyawan, dan Matriks Bulanan.',
                    badgeText: '3 Sheet Resmi',
                    badgeColor: const Color(0xFFD97706),
                    buttonText: 'Konfigurasi Periode & Ekspor',
                    buttonColor: const Color(0xFFD97706),
                    onTap: () => _showPeriodicSapModal(context),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F0F172A),
            blurRadius: 10,
            offset: Offset(0, 4),
          )
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
                  color: const Color(0xFF0284C7).withOpacity(0.25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF0284C7)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_rounded,
                        color: Color(0xFF38BDF8), size: 14),
                    const SizedBox(width: 5),
                    Text(
                      _companyName.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF38BDF8),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _period,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Laporan Eksekutif Departemen ${_departmentName.toUpperCase()}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Pusat unduhan rekapitulasi resmi, audit transparansi kepatuhan K3, dan ekspor data Microsoft Excel terstandarisasi.',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroKpiStrip({
    required double avgScore,
    required double avgCompliance,
    required int totalReports,
    required double avgCloseRate,
    required int squadCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
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
              const Text(
                'Indikator Utama Skuad',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
              Text(
                '$squadCount Pengawas Aktif',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMiniKpi(
                  'Skor PTS',
                  '${avgScore.toStringAsFixed(1)} pts',
                  const Color(0xFF0284C7),
                  const Color(0xFFF0F9FF),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniKpi(
                  'Capaian',
                  '${avgCompliance.toStringAsFixed(1)}%',
                  const Color(0xFF16A34A),
                  const Color(0xFFF0FDF4),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniKpi(
                  'Laporan K3',
                  '$totalReports Lap',
                  const Color(0xFF7C3AED),
                  const Color(0xFFF5F3FF),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniKpi(
                  'Close Rate',
                  '${avgCloseRate.toStringAsFixed(1)}%',
                  const Color(0xFFD97706),
                  const Color(0xFFFFFBEB),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniKpi(
      String label, String value, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required String buttonText,
    required Color buttonColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x060F172A),
                blurRadius: 8,
                offset: Offset(0, 3),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: badgeColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                badgeText,
                                style: TextStyle(
                                  color: badgeColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11.5,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: buttonColor,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: buttonColor.withOpacity(0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.arrow_forward_rounded,
                        color: Colors.white, size: 15),
                    const SizedBox(width: 6),
                    Text(
                      buttonText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
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

  // ==========================================
  // ACTION 1: AUDIT KEPATUHAN DETAIL MODAL
  // ==========================================
  void _showComplianceAuditModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            String filter = 'all'; // all, compliant, attention, uncompliant

            return DraggableScrollableSheet(
              initialChildSize: 0.88,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (_, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                        decoration: const BoxDecoration(
                          color: Color(0xFF1E3A8A),
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Audit Kepatuhan Skuad Karyawan',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Rekapitulasi target vs realisasi seluruh personil departemen',
                                  style: TextStyle(
                                    color: Color(0xFFBAE6FD),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  color: Colors.white),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      ),

                      // Quick Copy All Button
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                        child: InkWell(
                          onTap: () => _copyFullComplianceReport(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 9, horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFBBF7D0)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.copy_all_rounded,
                                    color: Color(0xFF16A34A), size: 16),
                                SizedBox(width: 8),
                                Text(
                                  'Salin Seluruh Data Kepatuhan (Format Lengkap)',
                                  style: TextStyle(
                                    color: Color(0xFF15803D),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // List Karyawan
                      Expanded(
                        child: ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _standings.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, idx) {
                            final m = _standings[idx];
                            final comp =
                                (m['complianceRate'] as num?)?.toDouble() ?? 0.0;
                            final score =
                                (m['totalScore'] as num?)?.toDouble() ?? 0.0;
                            final actual = m['totalActual'] ?? 0;
                            final target = m['totalTarget'] ?? 0;

                            Color statusColor = comp >= 80
                                ? const Color(0xFF16A34A)
                                : (comp >= 40
                                    ? const Color(0xFFD97706)
                                    : const Color(0xFFDC2626));
                            String statusLabel = comp >= 80
                                ? 'PATUH'
                                : (comp >= 40 ? 'PERHATIAN' : 'KURANG');

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor:
                                        statusColor.withOpacity(0.15),
                                    child: Text(
                                      '${idx + 1}',
                                      style: TextStyle(
                                        color: statusColor,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          m['name'] ?? '-',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12.5,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        Text(
                                          '${m['nik'] ?? '-'} • ${m['jabatan'] ?? 'Staff'}',
                                          style: const TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 10.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.12),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '$statusLabel (${comp.toStringAsFixed(0)}%)',
                                          style: TextStyle(
                                            color: statusColor,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 9.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '$actual / $target Lap • ${score.toStringAsFixed(1)} pts',
                                        style: const TextStyle(
                                          color: Color(0xFF475569),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
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
      },
    );
  }

  // ==========================================
  // ACTION 2: LAPORAN UNCOMPLIANT (PEMBINAAN K3)
  // ==========================================
  void _showUncompliantCoachingModal(BuildContext context) {
    final uncompliantList = _standings.where((m) {
      final comp = (m['complianceRate'] as num?)?.toDouble() ?? 0.0;
      return comp < 100.0;
    }).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.88,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                    decoration: const BoxDecoration(
                      color: Color(0xFF991B1B),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Laporan Uncompliant & Pembinaan K3',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${uncompliantList.length} Personil Belum Mencapai Target 100%',
                              style: const TextStyle(
                                color: Color(0xFFFECACA),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),

                  // Quick Copy Action Button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                    child: InkWell(
                      onTap: () => _copyCoachingReport(uncompliantList),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFECDD3)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.copy_rounded,
                                color: Color(0xFFE11D48), size: 16),
                            SizedBox(width: 8),
                            Text(
                              'Salin Format Pembinaan Pengawas (WhatsApp / Memo)',
                              style: TextStyle(
                                color: Color(0xFFBE123C),
                                fontWeight: FontWeight.w800,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // List Item
                  Expanded(
                    child: uncompliantList.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.verified_rounded,
                                      color: Color(0xFF16A34A), size: 48),
                                  SizedBox(height: 10),
                                  Text(
                                    'Luar Biasa! Semua Pengawas Tuntas 100%',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF15803D),
                                      fontSize: 14,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Seluruh personil skuad departemen telah memenuhi seluruh target program K3 periode ini.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: uncompliantList.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, idx) {
                              final m = uncompliantList[idx];
                              final comp = (m['complianceRate'] as num?)
                                      ?.toDouble() ??
                                  0.0;
                              final actual = m['totalActual'] ?? 0;
                              final target = m['totalTarget'] ?? 0;
                              final gap = target - actual;

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFFFDE68A)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${idx + 1}. ${m['name'] ?? '-'}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12.5,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFDC2626)
                                                .withOpacity(0.12),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'Kurang $gap Laporan',
                                            style: const TextStyle(
                                              color: Color(0xFFDC2626),
                                              fontWeight: FontWeight.w800,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${m['nik'] ?? '-'} • ${m['jabatan'] ?? 'Staff'}',
                                      style: const TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 10.5,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Text(
                                          'Realisasi: $actual / $target (${comp.toStringAsFixed(0)}%)',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF92400E),
                                          ),
                                        ),
                                        const Spacer(),
                                        InkWell(
                                          onTap: () =>
                                              _copySinglePersonCoaching(m),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2563EB),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Row(
                                              children: [
                                                Icon(Icons.chat_rounded,
                                                    color: Colors.white,
                                                    size: 11),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Salin Pesan WA',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
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

  // ==========================================
  // ACTION 5: PERIODIC SAP EXPORT MODAL (WEB)
  // ==========================================
  void _showPeriodicSapModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            const months = [
              {'val': 1, 'name': 'Januari'},
              {'val': 2, 'name': 'Februari'},
              {'val': 3, 'name': 'Maret'},
              {'val': 4, 'name': 'April'},
              {'val': 5, 'name': 'Mei'},
              {'val': 6, 'name': 'Juni'},
              {'val': 7, 'name': 'Juli'},
              {'val': 8, 'name': 'Agustus'},
              {'val': 9, 'name': 'September'},
              {'val': 10, 'name': 'Oktober'},
              {'val': 11, 'name': 'November'},
              {'val': 12, 'name': 'Desember'},
            ];

            void setPreset(String preset) {
              final now = DateTime.now();
              setModalState(() {
                if (preset == 'current') {
                  _startMonth = now.month;
                  _startYear = now.year;
                  _endMonth = now.month;
                  _endYear = now.year;
                } else if (preset == 'quarter') {
                  _endMonth = now.month;
                  _endYear = now.year;
                  int sm = now.month - 2;
                  int sy = now.year;
                  if (sm < 1) {
                    sm += 12;
                    sy -= 1;
                  }
                  _startMonth = sm;
                  _startYear = sy;
                } else if (preset == 'semester') {
                  _endMonth = now.month;
                  _endYear = now.year;
                  int sm = now.month - 5;
                  int sy = now.year;
                  if (sm < 1) {
                    sm += 12;
                    sy -= 1;
                  }
                  _startMonth = sm;
                  _startYear = sy;
                } else if (preset == 'ytd') {
                  _startMonth = 1;
                  _startYear = now.year;
                  _endMonth = now.month;
                  _endYear = now.year;
                }
              });
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.9,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (_, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF1E3A8A), Color(0xFF0F172A)],
                          ),
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                  Icons.description_rounded,
                                  color: Color(0xFFFBBF24),
                                  size: 20),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Download Report SAP Rentang Periode',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14.5,
                                    ),
                                  ),
                                  Text(
                                    'Format Standar Web (3 Sheet Excel Multi-Bulan)',
                                    style: TextStyle(
                                      color: Color(0xFFCBD5E1),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  color: Colors.white),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      ),

                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          children: [
                            // Scope Info
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.business_rounded,
                                      size: 16, color: Color(0xFF0284C7)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '$_companyName • $_departmentName',
                                      style: const TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Preset Cepat Buttons
                            Row(
                              children: [
                                const Text(
                                  'Preset Cepat: ',
                                  style: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      _buildPresetChip('1 Bulan Ini',
                                          () => setPreset('current')),
                                      _buildPresetChip('3 Bulan',
                                          () => setPreset('quarter')),
                                      _buildPresetChip('6 Bulan',
                                          () => setPreset('semester')),
                                      _buildPresetChip(
                                          'YTD', () => setPreset('ytd')),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Dari Periode (Awal)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'DARI PERIODE (AWAL)',
                                    style: TextStyle(
                                      color: Color(0xFF16A34A),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 6,
                                        child: DropdownButtonFormField<int>(
                                          value: _startMonth,
                                          isDense: true,
                                          decoration: InputDecoration(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 8),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          items: months.map((m) {
                                            return DropdownMenuItem<int>(
                                              value: m['val'] as int,
                                              child: Text(m['name'] as String,
                                                  style: const TextStyle(
                                                      fontSize: 12)),
                                            );
                                          }).toList(),
                                          onChanged: (v) {
                                            if (v != null) {
                                              setModalState(
                                                  () => _startMonth = v);
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 4,
                                        child: DropdownButtonFormField<int>(
                                          value: _startYear,
                                          isDense: true,
                                          decoration: InputDecoration(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 8),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          items: [2024, 2025, 2026, 2027]
                                              .map((y) => DropdownMenuItem<int>(
                                                    value: y,
                                                    child: Text('$y',
                                                        style: const TextStyle(
                                                            fontSize: 12)),
                                                  ))
                                              .toList(),
                                          onChanged: (v) {
                                            if (v != null) {
                                              setModalState(
                                                  () => _startYear = v);
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Sampai Periode (Akhir)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'SAMPAI PERIODE (AKHIR)',
                                    style: TextStyle(
                                      color: Color(0xFFDC2626),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 6,
                                        child: DropdownButtonFormField<int>(
                                          value: _endMonth,
                                          isDense: true,
                                          decoration: InputDecoration(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 8),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          items: months.map((m) {
                                            return DropdownMenuItem<int>(
                                              value: m['val'] as int,
                                              child: Text(m['name'] as String,
                                                  style: const TextStyle(
                                                      fontSize: 12)),
                                            );
                                          }).toList(),
                                          onChanged: (v) {
                                            if (v != null) {
                                              setModalState(
                                                  () => _endMonth = v);
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 4,
                                        child: DropdownButtonFormField<int>(
                                          value: _endYear,
                                          isDense: true,
                                          decoration: InputDecoration(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 8),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          items: [2024, 2025, 2026, 2027]
                                              .map((y) => DropdownMenuItem<int>(
                                                    value: y,
                                                    child: Text('$y',
                                                        style: const TextStyle(
                                                            fontSize: 12)),
                                                  ))
                                              .toList(),
                                          onChanged: (v) {
                                            if (v != null) {
                                              setModalState(
                                                  () => _endYear = v);
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Filter Skuad Karyawan Radio
                            const Text(
                              'Filter Skuad Karyawan:',
                              style: TextStyle(
                                color: Color(0xFF0F172A),
                                fontWeight: FontWeight.w800,
                                fontSize: 11.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              children: [
                                _buildFilterRadio(
                                  label: 'Hanya Target SAP',
                                  value: 'target',
                                  groupValue: _targetFilter,
                                  onChanged: (val) => setModalState(
                                      () => _targetFilter = val!),
                                ),
                                _buildFilterRadio(
                                  label: 'Semua Skuad',
                                  value: 'all',
                                  groupValue: _targetFilter,
                                  onChanged: (val) => setModalState(
                                      () => _targetFilter = val!),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // 3 Sheet Description
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'FORMAT WORKBOOK EXCEL RESMI:',
                                    style: TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 10.5,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    '• Sheet 1: Rekapitulasi Departemen (Akumulasi target, realisasi, close rate AP & tren bulanan)',
                                    style: TextStyle(
                                        fontSize: 10.5, color: Color(0xFF334155)),
                                  ),
                                  Text(
                                    '• Sheet 2: Pencapaian Karyawan (Rincian per personil HZ, IP, ST, OB, CC, P5M, Capaian %)',
                                    style: TextStyle(
                                        fontSize: 10.5, color: Color(0xFF334155)),
                                  ),
                                  Text(
                                    '• Sheet 3: Matriks Bulanan Karyawan (Log performa audit bulanan untuk Pivot Table)',
                                    style: TextStyle(
                                        fontSize: 10.5, color: Color(0xFF334155)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Download Excel Action Button
                            InkWell(
                              onTap: () {
                                Navigator.pop(ctx);
                                final compId = _profile?.companyId ?? 1;
                                final urlPath =
                                    'ExportPeriodicDeptReportToExcel?companyId=$compId&departmentName=${Uri.encodeComponent(_departmentName)}&startMonth=$_startMonth&startYear=$_startYear&endMonth=$_endMonth&endYear=$_endYear&targetFilter=$_targetFilter';
                                _downloadWebExcel(
                                  urlPath,
                                  'Report_SAP_Periodik_${_startMonth}_${_startYear}_sd_${_endMonth}_${_endYear}.xlsx',
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1D4ED8),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x331D4ED8),
                                      blurRadius: 8,
                                      offset: Offset(0, 3),
                                    )
                                  ],
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.download_rounded,
                                        color: Colors.white, size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      'Unduh File Excel (.xlsx)',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPresetChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
        decoration: BoxDecoration(
          color: const Color(0xFFE0F2FE),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFBAE6FD)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF0369A1),
            fontWeight: FontWeight.w800,
            fontSize: 10,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterRadio({
    required String label,
    required String value,
    required String groupValue,
    required ValueChanged<String?> onChanged,
  }) {
    final isSelected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF3B82F6)
                : const Color(0xFFCBD5E1),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              size: 14,
              color: isSelected
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? const Color(0xFF1E3A8A)
                    : const Color(0xFF475569),
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // HELPER: DOWNLOAD / OPEN WEB EXCEL
  // ==========================================
  Future<void> _downloadWebExcel(String actionUrl, String fileName) async {
    // Generate URL targeting the backend Performance Controller or web portal
    final fullUrl = '${_api.baseUrl}/Performance/$actionUrl';
    try {
      final uri = Uri.parse(fullUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: Copy link and inform user
        await Clipboard.setData(ClipboardData(text: fullUrl));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Link download Excel berhasil disalin: $fileName\nBuka di browser jika tidak otomatis terunduh.'),
              backgroundColor: const Color(0xFF0284C7),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: fullUrl));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Link download disalin ke clipboard! Buka di browser untuk mengunduh Excel.'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    }
  }

  // ==========================================
  // HELPER: COPY FULL COMPLIANCE REPORT
  // ==========================================
  void _copyFullComplianceReport() {
    final buffer = StringBuffer();
    buffer.writeln('========================================');
    buffer.writeln('LAPORAN AUDIT KEPATUHAN K3 (SAP)');
    buffer.writeln('PERIODE: ${_period.toUpperCase()}');
    buffer.writeln('========================================');
    buffer.writeln('🏢 Perusahaan : $_companyName');
    buffer.writeln('👥 Departemen : $_departmentName');
    buffer.writeln('👥 Total Skuad: ${_standings.length} Personil');
    buffer.writeln('');
    buffer.writeln('DAFTAR REKAPITULASI KEPATUHAN:');
    buffer.writeln('----------------------------------------');

    for (int i = 0; i < _standings.length; i++) {
      final m = _standings[i];
      final comp = (m['complianceRate'] as num?)?.toDouble() ?? 0.0;
      final score = (m['totalScore'] as num?)?.toDouble() ?? 0.0;
      final actual = m['totalActual'] ?? 0;
      final target = m['totalTarget'] ?? 0;
      final status = comp >= 80 ? 'PATUH' : (comp >= 40 ? 'PERHATIAN' : 'KURANG');

      buffer.writeln(
          '#${i + 1}. ${m['name']} (${m['nik']}) - ${m['jabatan']}');
      buffer.writeln(
          '    Status: $status | Capaian: ${comp.toStringAsFixed(0)}% ($actual/$target Lap) | Skor: ${score.toStringAsFixed(1)} pts');
    }

    buffer.writeln('========================================');
    buffer.writeln('Generated via Indexsafe Evolution Mobile');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Seluruh data audit kepatuhan berhasil disalin!'),
        backgroundColor: Color(0xFF16A34A),
      ),
    );
  }

  // ==========================================
  // HELPER: COPY UNCOMPLIANT COACHING REPORT
  // ==========================================
  void _copyCoachingReport(List<dynamic> list) {
    final buffer = StringBuffer();
    buffer.writeln('========================================');
    buffer.writeln('LAPORAN PEMBINAAN K3 (TARGET BELUM TUNTAS)');
    buffer.writeln('PERIODE: ${_period.toUpperCase()}');
    buffer.writeln('========================================');
    buffer.writeln('🏢 Departemen: $_departmentName');
    buffer.writeln('⚠️ Total Personil Belum Tuntas: ${list.length} Orang');
    buffer.writeln('');
    buffer.writeln('Daftar Personil Perlu Pembinaan Pengawas:');
    buffer.writeln('----------------------------------------');

    for (int i = 0; i < list.length; i++) {
      final m = list[i];
      final comp = (m['complianceRate'] as num?)?.toDouble() ?? 0.0;
      final actual = m['totalActual'] ?? 0;
      final target = m['totalTarget'] ?? 0;
      final gap = target - actual;

      buffer.writeln('${i + 1}. ${m['name']} (${m['nik']}) - ${m['jabatan']}');
      buffer.writeln(
          '   Capaian: ${comp.toStringAsFixed(0)}% (Realisasi: $actual / Target: $target) -> Kekurangan: $gap Laporan');
    }

    buffer.writeln('----------------------------------------');
    buffer.writeln(
        'Mohon tindak lanjut pembinaan pengawas lapangan sebelum cut-off akhir periode.');
    buffer.writeln('========================================');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Format pembinaan pengawas berhasil disalin ke WhatsApp!'),
        backgroundColor: Color(0xFFE11D48),
      ),
    );
  }

  void _copySinglePersonCoaching(dynamic m) {
    final name = m['name'] ?? '-';
    final nik = m['nik'] ?? '-';
    final actual = m['totalActual'] ?? 0;
    final target = m['totalTarget'] ?? 0;
    final comp = ((m['complianceRate'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(0);
    final gap = target - actual;

    final msg =
        'Halo Pak/Bu $name ($nik),\nMengingatkan terkait pencapaian Safety Accountability Program (SAP) Periode $_period:\n'
        '• Capaian Saat Ini: $comp% (Realisasi: $actual dari target: $target)\n'
        '• Kekurangan: Masih kurang $gap laporan K3 untuk mencapai target 100% patuh.\n\n'
        'Mohon segera dilengkapi sebelum akhir bulan agar evaluasi performa K3 dan klasemen departemen kita tetap prima. Terima kasih dan Salam Sehat Selamat!';

    Clipboard.setData(ClipboardData(text: msg));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pesan pembinaan personal untuk $name berhasil disalin!'),
        backgroundColor: const Color(0xFF2563EB),
      ),
    );
  }
}

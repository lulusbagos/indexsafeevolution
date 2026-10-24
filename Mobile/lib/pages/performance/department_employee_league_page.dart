import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api.dart';
import '../../services/preference.dart';
import '../../utils/routers.dart';

class DepartmentEmployeeLeaguePage extends StatefulWidget {
  const DepartmentEmployeeLeaguePage({super.key});

  @override
  State<DepartmentEmployeeLeaguePage> createState() =>
      _DepartmentEmployeeLeaguePageState();
}

class _DepartmentEmployeeLeaguePageState
    extends State<DepartmentEmployeeLeaguePage> {
  final ApiService _api = ApiService();
  final _profile = PreferenceService.getProfile();

  bool _isLoading = true;
  String _departmentName = 'Departemen';
  String _companyName = 'PT INDEXIM COALINDO';
  String _period = 'Oktober 2026';
  int _userRank = 0;
  int _userPos = 0;
  int _totalLeaguePlayers = 453;
  List<dynamic> _standings = [];
  List<dynamic> _filteredStandings = [];
  String _activeFilterCategory = 'all'; // 'all', 'top', 'uncompliant'
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchDepartmentSquad();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchDepartmentSquad() async {
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
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Gagal memuat data: ${err['message']}')),
            );
          }
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
              _userRank = int.tryParse(data['userRank']?.toString() ?? '0') ?? 0;
              _userPos = int.tryParse(data['userPos']?.toString() ?? '0') ?? 0;
              _totalLeaguePlayers = int.tryParse(data['totalLeaguePlayers']?.toString() ?? '453') ?? 453;
              _standings = list;
              _applyFilter();
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilter() {
    List<dynamic> list = List.from(_standings);

    // Filter berdasarkan kategori analisis
    if (_activeFilterCategory == 'top') {
      list = list.where((m) {
        final score = (m['totalScore'] as num?)?.toDouble() ?? 0.0;
        return score >= 80.0;
      }).toList();
    } else if (_activeFilterCategory == 'uncompliant') {
      list = list.where((m) {
        final comp = (m['complianceRate'] as num?)?.toDouble() ?? 0.0;
        return comp < 100.0;
      }).toList();
    }

    // Filter pencarian
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = list.where((item) {
        final name = (item['name']?.toString() ?? '').toLowerCase();
        final nik = (item['nik']?.toString() ?? '').toLowerCase();
        final jabatan = (item['jabatan']?.toString() ?? '').toLowerCase();
        return name.contains(q) || nik.contains(q) || jabatan.contains(q);
      }).toList();
    }

    _filteredStandings = list;
  }

  @override
  Widget build(BuildContext context) {
    final currentUserMember = _standings.firstWhere(
      (m) => m['isCurrentUser'] == true,
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Klasemen Karyawan',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            Text(
              '$_departmentName • $_period',
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF0F172A), size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0284C7), size: 21),
            tooltip: 'Segarkan Data',
            onPressed: _fetchDepartmentSquad,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF0F172A), size: 21),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (val) {
              if (val == 'sop') _showSopMethodologyModal(context);
              if (val == 'copy_report') _copyExecutiveReport();
              if (val == 'copy_uncompliant') _copyUncompliantReport();
              if (val == 'export') routePage(context, '/sap_reports');
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'sop',
                child: Row(
                  children: [
                    Icon(Icons.menu_book_rounded, color: Color(0xFF0284C7), size: 18),
                    SizedBox(width: 10),
                    Text('Panduan SOP & Formula', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'copy_report',
                child: Row(
                  children: [
                    Icon(Icons.copy_rounded, color: Color(0xFF16A34A), size: 18),
                    SizedBox(width: 10),
                    Text('Salin Format Resmi (WA)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'copy_uncompliant',
                child: Row(
                  children: [
                    Icon(Icons.assignment_late_rounded, color: Color(0xFFE11D48), size: 18),
                    SizedBox(width: 10),
                    Text('Salin Rekap Pembinaan', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.file_download_rounded, color: Color(0xFF7C3AED), size: 18),
                    SizedBox(width: 10),
                    Text('Pusat Laporan & Excel', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF0284C7)),
                  SizedBox(height: 14),
                  Text(
                    'Menghitung Klasemen Internal Departemen...',
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
              onRefresh: _fetchDepartmentSquad,
              color: const Color(0xFF0284C7),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                children: [
                  // Header Info Departemen & Periode
                  _buildDepartmentHeader(),
                  const SizedBox(height: 12),

                  // Ringkasan Laporan Eksekutif Departemen (Macro KPI)
                  _buildDepartmentExecutiveReport(),
                  const SizedBox(height: 14),

                  // Kartu Posisi User yang Login
                  if (currentUserMember != null) ...[
                    _buildCurrentUserCard(currentUserMember),
                    const SizedBox(height: 14),
                  ],

                  // Podium Top 3 (Jika karyawan >= 3)
                  if (_standings.length >= 3) ...[
                    _buildPodiumSection(),
                    const SizedBox(height: 18),
                  ],

                  // Web Info Banner: Menampilkan Skuad Klub
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_user_outlined, color: Color(0xFF16A34A), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Menampilkan Skuad Klub ${_departmentName.toUpperCase()} (${_standings.length} Pemain)',
                            style: const TextStyle(
                              color: Color(0xFF15803D),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Search Box & Judul Daftar Lengkap
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Peringkat Tim (${_standings.length} Karyawan)',
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Formula Web 4-Pillar',
                          style: TextStyle(
                            color: Color(0xFF0369A1),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Search Input
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x080F172A),
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        )
                      ],
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                          _applyFilter();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Cari nama, NIK, jabatan...',
                        hintStyle: const TextStyle(
                            color: Color(0xFF94A3B8), fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: Color(0xFF64748B), size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    size: 18, color: Color(0xFF94A3B8)),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() {
                                    _searchQuery = '';
                                    _applyFilter();
                                  });
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Slicing & Filter Analisis Tim (Semua / Top / Perlu Pembinaan)
                  _buildAnalyticsFilterBar(),
                  const SizedBox(height: 12),

                  // Banner Notifikasi Pembinaan jika filter uncompliant aktif
                  if (_activeFilterCategory == 'uncompliant' && _filteredStandings.isNotEmpty) ...[
                    _buildUncompliantNoticeBanner(),
                    const SizedBox(height: 12),
                  ],

                  // List Item Peringkat
                  if (_filteredStandings.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          Icon(Icons.search_off_rounded,
                              size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          const Text(
                            'Karyawan tidak ditemukan',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._filteredStandings.map((m) => _buildEmployeeRow(m)),

                  // Footer Summary: Menampilkan Pemain dari total X pemain
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.emoji_events_outlined, size: 16, color: Color(0xFF0284C7)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Menampilkan ${_filteredStandings.length} Pemain Terbaik dari total $_totalLeaguePlayers pemain liga',
                            style: const TextStyle(
                              color: Color(0xFF334155),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Syarat Mutlak Podium Rule Banner
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Syarat Mutlak Kelayakan Juara (Podium): Pengawas wajib Tuntas 100% Seluruh Target Program K3 (Capaian 100% / form dots hijau penuh [W] tanpa ada program yang draw/kurang). Pengawas yang kewajiban programnya belum tuntas tidak berhak menempati podium juara.',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF475569),
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _copyExecutiveReport() {
    if (_standings.isEmpty) return;

    double totalScoreSum = 0;
    double complianceSum = 0;
    double closeRateSum = 0;
    int totalSafetyReportsSum = 0;
    final count = _standings.length;

    for (final m in _standings) {
      totalScoreSum += (m['totalScore'] as num?)?.toDouble() ?? 0.0;
      complianceSum += (m['complianceRate'] as num?)?.toDouble() ?? 0.0;
      closeRateSum += (m['closeRate'] as num?)?.toDouble() ?? 100.0;
      totalSafetyReportsSum += (m['totalActualAll'] as num?)?.toInt() ??
          ((m['totalActual'] as num?)?.toInt() ?? 0);
    }

    final avgScore = count > 0 ? (totalScoreSum / count) : 0.0;
    final avgCompliance = count > 0 ? (complianceSum / count) : 0.0;
    final avgCloseRate = count > 0 ? (closeRateSum / count) : 100.0;

    final buffer = StringBuffer();
    buffer.writeln('========================================');
    buffer.writeln('LAPORAN KLASEMEN SAFETY ACCOUNTABILITY PROGRAM (SAP)');
    buffer.writeln('PERIODE: ${_period.toUpperCase()}');
    buffer.writeln('========================================');
    buffer.writeln('🏢 Perusahaan : $_companyName');
    buffer.writeln('👥 Departemen : $_departmentName');
    buffer.writeln('👥 Total Skuad : $count Pengawas / Pemain');
    buffer.writeln('🏆 Total Liga : $_totalLeaguePlayers Pemain Perusahaan');
    buffer.writeln('');
    buffer.writeln('----------------------------------------');
    buffer.writeln('📊 INDIKATOR MAKRO K3 DEPARTEMEN');
    buffer.writeln('----------------------------------------');
    buffer.writeln('• Rata-rata Skor PTS   : ${avgScore.toStringAsFixed(1)} pts');
    buffer.writeln('• Rata-rata Capaian    : ${avgCompliance.toStringAsFixed(1)}%');
    buffer.writeln('• Rata-rata Close Rate : ${avgCloseRate.toStringAsFixed(1)}%');
    buffer.writeln('• Total Laporan K3     : $totalSafetyReportsSum Laporan Riil');
    buffer.writeln('');

    if (_standings.isNotEmpty) {
      buffer.writeln('----------------------------------------');
      buffer.writeln('🥇 PODIUM TOP JUARA DEPARTEMEN');
      buffer.writeln('----------------------------------------');
      final topLimit = _standings.length < 3 ? _standings.length : 3;
      for (int i = 0; i < topLimit; i++) {
        final m = _standings[i];
        final medal = i == 0 ? '🥇' : (i == 1 ? '🥈' : '🥉');
        final pos = m['pos'] ?? (i + 1);
        final score = ((m['totalScore'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(1);
        final cap = ((m['complianceRate'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(0);
        final lap = m['totalActualAll'] ?? m['totalActual'] ?? 0;
        buffer.writeln('$medal Juara ${i + 1} (Pos $pos Liga): ${m['name']}');
        buffer.writeln('   Skor: $score pts | Capaian: $cap% | $lap Laporan K3');
      }
      buffer.writeln('');
    }

    buffer.writeln('----------------------------------------');
    buffer.writeln('📋 KLASEMEN SKUAD PEMAIN K3');
    buffer.writeln('----------------------------------------');
    for (int i = 0; i < _standings.length; i++) {
      final m = _standings[i];
      final rank = i + 1;
      final pos = m['pos'] ?? rank;
      final name = m['name'] ?? '-';
      final nik = m['nik'] ?? '-';
      final jab = m['jabatan'] ?? 'Staff';
      final score = ((m['totalScore'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(1);
      final cap = ((m['complianceRate'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(0);
      final form = ((m['formDots'] as List<dynamic>?)?.map((e) => e.toString()).join(' ') ?? '-');
      buffer.writeln('#$rank. [Pos $pos] $name ($nik) - $jab');
      buffer.writeln('     Skor: $score pts | Capaian: $cap% | Form: [$form]');
    }

    buffer.writeln('');
    buffer.writeln('----------------------------------------');
    buffer.writeln('⚖️ METODOLOGI & SYARAT MUTLAK JUARA');
    buffer.writeln('----------------------------------------');
    buffer.writeln('• Formula 4 Pilar: (35% × Capaian) + (30% × Close Rate) + (25% × Mutu) + (10% × Beban)');
    buffer.writeln('• Syarat Mutlak Podium: Wajib Tuntas 100% Seluruh Target Program K3 (All Green W).');
    buffer.writeln('• Dual Accountability: 50% sisi Pelapor + 50% sisi PIC (Self-close limit 50%).');
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
                'Laporan Resmi Departemen berhasil disalin ke clipboard! Siap dibagikan ke WhatsApp / Email.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        backgroundColor: Color(0xFF16A34A),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _copyUncompliantReport() {
    if (_standings.isEmpty) return;

    final uncompliantList = _standings.where((m) {
      final comp = (m['complianceRate'] as num?)?.toDouble() ?? 0.0;
      return comp < 100.0;
    }).toList();

    if (uncompliantList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Luar biasa! Seluruh skuad departemen telah tuntas 100% target K3.'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('========================================');
    buffer.writeln('LAPORAN PEMBINAAN K3 (TARGET BELUM TUNTAS)');
    buffer.writeln('PERIODE: ${_period.toUpperCase()}');
    buffer.writeln('========================================');
    buffer.writeln('🏢 Perusahaan : $_companyName');
    buffer.writeln('👥 Departemen : $_departmentName');
    buffer.writeln('⚠️ Personil Belum Tuntas: ${uncompliantList.length} dari ${_standings.length} Skuad');
    buffer.writeln('');
    buffer.writeln('Daftar Personil Perlu Tindak Lanjut Pembinaan:');
    buffer.writeln('----------------------------------------');

    for (int i = 0; i < uncompliantList.length; i++) {
      final m = uncompliantList[i];
      final comp = ((m['complianceRate'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(0);
      final score = ((m['totalScore'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(1);
      final actual = m['totalActual'] ?? 0;
      final target = m['totalTarget'] ?? 0;
      final gap = target - actual;

      buffer.writeln('${i + 1}. ${m['name']} (${m['nik']}) - ${m['jabatan']}');
      buffer.writeln('   Capaian: $comp% ($actual / $target Lap) -> KURANG $gap LAPORAN | Skor: $score pts');
    }

    buffer.writeln('');
    buffer.writeln('----------------------------------------');
    buffer.writeln('Instruksi Pengawas:');
    buffer.writeln('Segera selesaikan kewajiban laporan K3 sebelum evaluasi cut-off akhir periode.');
    buffer.writeln('Generated via Indexsafe Evolution Mobile');
    buffer.writeln('========================================');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.assignment_late_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Rekap pembinaan ${uncompliantList.length} personil berhasil disalin! Siap dibagikan ke WhatsApp pengawas.',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFE11D48),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _copyEmployeeAuditReport(dynamic m) {
    final name = m['name']?.toString() ?? '-';
    final nik = m['nik']?.toString() ?? '-';
    final jabatan = m['jabatan']?.toString() ?? 'Staff';
    final rank = m['rank'] ?? 0;
    final pos = m['pos'] ?? rank;
    final onsiteDays = m['onsiteDays'] ?? 0;
    final totalScore = ((m['totalScore'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(1);
    final compliance = ((m['complianceRate'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(1);
    final closeRate = ((m['closeRate'] as num?)?.toDouble() ?? 100.0).toStringAsFixed(1);
    final crCreator = ((m['crCreatorScore'] as num?)?.toDouble() ?? 100.0).toStringAsFixed(1);
    final crPic = ((m['crPicScore'] as num?)?.toDouble() ?? 100.0).toStringAsFixed(1);
    final quality = ((m['qualityScore'] as num?)?.toDouble() ?? 100.0).toStringAsFixed(1);
    final scaleBeban = ((m['scaleBebanScore'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(1);

    final ptsCapaian = ((m['ptsCapaian'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(1);
    final ptsClose = ((m['ptsClose'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(1);
    final ptsKualitas = ((m['ptsKualitas'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(1);
    final ptsBeban = ((m['ptsBeban'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(1);

    final actual = m['totalActual'] ?? 0;
    final target = m['totalTarget'] ?? 0;
    final actualAll = m['totalActualAll'] ?? actual;
    final maxTarget = m['maxTargetPlayer'] ?? 30;

    final hazard = m['hazard'] ?? {};
    final inspeksi = m['inspeksi'] ?? {};
    final safetyTalk = m['safetyTalk'] ?? {};
    final observasi = m['observasi'] ?? {};
    final coaching = m['coaching'] ?? {};
    final p5m = m['p5m'] ?? {};

    final buffer = StringBuffer();
    buffer.writeln('========================================');
    buffer.writeln('AUDIT TRANSPARANSI SKOR SAP - $name');
    buffer.writeln('PERIODE: ${_period.toUpperCase()}');
    buffer.writeln('========================================');
    buffer.writeln('• Posisi Liga       : Pos $pos Liga (Peringkat #$rank $_departmentName)');
    buffer.writeln('• NIK / Jabatan     : $nik / $jabatan');
    buffer.writeln('• Perusahaan        : ${m['companyName'] ?? _companyName}');
    buffer.writeln('• Hari Onsite       : $onsiteDays Hari (Roster Kerja Terverifikasi)');
    buffer.writeln('');
    buffer.writeln('🏆 TOTAL SKOR PTS : $totalScore pts');
    buffer.writeln('');
    buffer.writeln('----------------------------------------');
    buffer.writeln('RINCIAN 4 PILAR FORMULA BOBOT:');
    buffer.writeln('----------------------------------------');
    buffer.writeln('1. Capaian Target (35%) : 35% × $compliance% = $ptsCapaian pts (Realisasi: $actual / Target: $target)');
    buffer.writeln('2. Close Rate (30%)     : 30% × $closeRate% = $ptsClose pts (Pelapor: $crCreator%, PIC: $crPic%)');
    buffer.writeln('3. Kualitas Mutu (25%)  : 25% × $quality% = $ptsKualitas pts (Standar Mutu SAP 5.0 ★)');
    buffer.writeln('4. Skala Beban (10%)    : 10% × $scaleBeban% = $ptsBeban pts (Target: $target vs Max Liga: $maxTarget)');
    buffer.writeln('-> Akumulasi: ($ptsCapaian) + ($ptsClose) + ($ptsKualitas) + ($ptsBeban) = $totalScore pts');
    buffer.writeln('');
    buffer.writeln('----------------------------------------');
    buffer.writeln('7 KPI PROGRAM K3 (Realisasi / Target):');
    buffer.writeln('----------------------------------------');
    buffer.writeln('• Hazard      : ${hazard['actual'] ?? 0} / ${hazard['target'] ?? 0}');
    buffer.writeln('• Inspeksi    : ${inspeksi['actual'] ?? 0} / ${inspeksi['target'] ?? 0}');
    buffer.writeln('• Safety Talk : ${safetyTalk['actual'] ?? 0} / ${safetyTalk['target'] ?? 0}');
    buffer.writeln('• Observasi   : ${observasi['actual'] ?? 0} / ${observasi['target'] ?? 0}');
    buffer.writeln('• Coaching    : ${coaching['actual'] ?? 0} / ${coaching['target'] ?? 0}');
    buffer.writeln('• P5M         : ${p5m['actual'] ?? 0} / ${p5m['target'] ?? 0}');
    buffer.writeln('• Total Lap   : $actualAll Laporan Riil');
    buffer.writeln('');
    buffer.writeln('Syarat Mutlak Juara: Wajib Tuntas 100% Target Seluruh Program K3.');
    buffer.writeln('Generated via Indexsafe Mobile App - PT Indexim Coalindo');
    buffer.writeln('========================================');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Rincian Audit Skor $name berhasil disalin!',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF16A34A),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildDepartmentExecutiveReport() {
    if (_standings.isEmpty) return const SizedBox.shrink();

    double totalScoreSum = 0;
    double complianceSum = 0;
    double closeRateSum = 0;
    int totalSafetyReportsSum = 0;
    final count = _standings.length;

    for (final m in _standings) {
      totalScoreSum += (m['totalScore'] as num?)?.toDouble() ?? 0.0;
      complianceSum += (m['complianceRate'] as num?)?.toDouble() ?? 0.0;
      closeRateSum += (m['closeRate'] as num?)?.toDouble() ?? 100.0;
      totalSafetyReportsSum += (m['totalActualAll'] as num?)?.toInt() ??
          ((m['totalActual'] as num?)?.toInt() ?? 0);
    }

    final avgScore = count > 0 ? (totalScoreSum / count) : 0.0;
    final avgCompliance = count > 0 ? (complianceSum / count) : 0.0;
    final avgCloseRate = count > 0 ? (closeRateSum / count) : 100.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 12,
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.analytics_rounded,
                        color: Color(0xFF0284C7), size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ringkasan Eksekutif Departemen',
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'Indikator Makro Kinerja K3 & Formula Resmi Web',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  '$count Skuad',
                  style: const TextStyle(
                    color: Color(0xFF334155),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 4 Macro KPI Cards (2x2 Grid)
          Row(
            children: [
              Expanded(
                child: _buildMacroKpiTile(
                  title: 'Rata-rata PTS',
                  value: '${avgScore.toStringAsFixed(1)} pts',
                  subtitle: 'Agregat 4 Pilar',
                  valueColor: const Color(0xFF0284C7),
                  bgColor: const Color(0xFFF0F9FF),
                  borderColor: const Color(0xFFBAE6FD),
                  icon: Icons.emoji_events_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMacroKpiTile(
                  title: 'Rata-rata Capaian',
                  value: '${avgCompliance.toStringAsFixed(1)}%',
                  subtitle: 'Kepatuhan Fisik SAP',
                  valueColor: const Color(0xFF16A34A),
                  bgColor: const Color(0xFFF0FDF4),
                  borderColor: const Color(0xFFBBF7D0),
                  icon: Icons.track_changes_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMacroKpiTile(
                  title: 'Total Laporan K3',
                  value: '$totalSafetyReportsSum Lap',
                  subtitle: 'Hazard, Insp, ST, Obs, Coach',
                  valueColor: const Color(0xFF7C3AED),
                  bgColor: const Color(0xFFF5F3FF),
                  borderColor: const Color(0xFFDDD6FE),
                  icon: Icons.shield_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMacroKpiTile(
                  title: 'Rata-rata Close Rate',
                  value: '${avgCloseRate.toStringAsFixed(1)}%',
                  subtitle: 'Dual Accountability',
                  valueColor: const Color(0xFFD97706),
                  bgColor: const Color(0xFFFFFBEB),
                  borderColor: const Color(0xFFFDE68A),
                  icon: Icons.task_alt_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Action Toolbar: SingleChildScrollView with zero overflow risk
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildActionButton(
                  icon: Icons.copy_rounded,
                  label: 'Salin Format WA',
                  bgColor: const Color(0xFF0284C7),
                  textColor: Colors.white,
                  onTap: _copyExecutiveReport,
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  icon: Icons.assignment_late_rounded,
                  label: 'Rekap Pembinaan',
                  bgColor: const Color(0xFFFFF1F2),
                  textColor: const Color(0xFFE11D48),
                  borderColor: const Color(0xFFFECDD3),
                  onTap: _copyUncompliantReport,
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  icon: Icons.menu_book_rounded,
                  label: 'Panduan SOP',
                  bgColor: const Color(0xFFF8FAFC),
                  textColor: const Color(0xFF0F172A),
                  borderColor: const Color(0xFFCBD5E1),
                  onTap: () => _showSopMethodologyModal(context),
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  icon: Icons.file_download_rounded,
                  label: 'Pusat Ekspor & Excel',
                  bgColor: const Color(0xFFF0FDF4),
                  textColor: const Color(0xFF16A34A),
                  borderColor: const Color(0xFFBBF7D0),
                  onTap: () => routePage(context, '/sap_reports'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color textColor,
    Color? borderColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8.5),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: borderColor != null ? Border.all(color: borderColor) : null,
            boxShadow: bgColor == const Color(0xFF0284C7)
                ? const [
                    BoxShadow(
                      color: Color(0x220284C7),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: textColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMacroKpiTile({
    required String title,
    required String value,
    required String subtitle,
    required Color valueColor,
    required Color bgColor,
    required Color borderColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569),
                ),
              ),
              Icon(icon, size: 14, color: valueColor),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsFilterBar() {
    final topCount = _standings.where((m) => ((m['totalScore'] as num?)?.toDouble() ?? 0.0) >= 80.0).length;
    final uncompliantCount = _standings.where((m) => ((m['complianceRate'] as num?)?.toDouble() ?? 0.0) < 100.0).length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildFilterChip(
            id: 'all',
            label: 'Semua Skuad',
            count: _standings.length,
            icon: Icons.people_outline_rounded,
            activeColor: const Color(0xFF0284C7),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            id: 'top',
            label: 'Top Performer (≥80 pts)',
            count: topCount,
            icon: Icons.workspace_premium_rounded,
            activeColor: const Color(0xFF16A34A),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            id: 'uncompliant',
            label: 'Perlu Pembinaan (<100%)',
            count: uncompliantCount,
            icon: Icons.warning_amber_rounded,
            activeColor: const Color(0xFFE11D48),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String id,
    required String label,
    required int count,
    required IconData icon,
    required Color activeColor,
  }) {
    final isSelected = _activeFilterCategory == id;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() {
            _activeFilterCategory = id;
            _applyFilter();
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7.5),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? activeColor : const Color(0xFFCBD5E1),
              width: 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeColor.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ]
                : const [
                    BoxShadow(
                      color: Color(0x060F172A),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    )
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.22)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUncompliantNoticeBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFE11D48), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Menampilkan ${_filteredStandings.length} personil yang belum tuntas 100% target K3 bulan ini.',
              style: const TextStyle(
                color: Color(0xFF9F1239),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: _copyUncompliantReport,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Salin Rekap',
              style: TextStyle(
                color: Color(0xFFE11D48),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserPillarItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w700,
            color: Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildPillarScoreItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildPillarDivider() {
    return Container(
      width: 1,
      height: 18,
      color: const Color(0xFFE2E8F0),
    );
  }

  void _showSopMethodologyModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.menu_book_rounded,
                      color: Color(0xFF0284C7), size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Panduan SOP & Metodologi Skor PTS',
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5,
                        ),
                      ),
                      Text(
                        'Standar Resmi Safety Accountability Program (SAP) Sesuai Web',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSopGuideContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildSopGuideContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Formula Agregat PTS Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF93C5FD)),
          ),
          child: const Column(
            children: [
              Text(
                'FORMULA AGREGAT SKOR AKHIR (PTS)',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1D4ED8),
                  letterSpacing: 0.4,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Skor = (35% × Capaian) + (30% × Close Rate) + (25% × Kualitas) + (10% × Skala Beban)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 4 SOP Cards
        _buildSopDetailCard(
          icon: Icons.adjust_rounded,
          title: '1. Capaian Target (Volume)',
          badgeText: 'Bobot 35%',
          badgeBg: const Color(0xFFDBEAFE),
          badgeColor: const Color(0xFF1D4ED8),
          desc:
              'Persentase pemenuhan kuota fisik 5 program wajib SAP (Hazard, Inspeksi, Safety Talk, Observasi, Coaching, P5M) dengan batas maksimal 100%.',
          ruleTitle: 'Penyesuaian Hari Kerja (Onsite via Roster):',
          rules: const [
            'Rumus: (Total Realisasi / Total Target) × 100%.',
            'Target disesuaikan proporsional berdasarkan Hari Onsite. Karyawan cuti/off tidak dibebani target saat tidak berada di area kerja.',
          ],
        ),
        const SizedBox(height: 12),

        _buildSopDetailCard(
          icon: Icons.shield_outlined,
          title: '2. Close Rate Action Plan',
          badgeText: 'Bobot 30%',
          badgeBg: const Color(0xFFDCFCE7),
          badgeColor: const Color(0xFF15803D),
          desc:
              'Tingkat penyelesaian dan tindak lanjut temuan bahaya/isu K3LH. Merupakan pilar keselamatan kunci dengan bobot 30 pts.',
          ruleTitle: 'Standar Validasi & Integritas Data (Dual Accountability):',
          rules: const [
            'Dihitung 50% dari sisi Pelapor dan 50% dari sisi PIC yang ditunjuk.',
            'Self-Close Cap 50%: Temuan yang ditutup sendiri oleh pelapor tanpa verifikasi pihak kedua dibatasi maksimal 50% guna memastikan verifikasi silang faktual di lapangan.',
            'Jika tidak ada temuan tertunggak (zero overdue), skor bernilai penuh (100%).',
          ],
        ),
        const SizedBox(height: 12),

        _buildSopDetailCard(
          icon: Icons.stars_rounded,
          title: '3. Kualitas Input (Mutu)',
          badgeText: 'Bobot 25%',
          badgeBg: const Color(0xFFFEF3C7),
          badgeColor: const Color(0xFFB45309),
          desc:
              'Validasi objektif atas standar kelengkapan data laporan SAP (deskripsi spesifik, kejelasan tindakan, bukti foto relevan, dan ketepatan level risiko).',
          ruleTitle: 'Standar Mutu & Penalti:',
          rules: const [
            'Baseline Standar: Bernilai 100% (5.0 / 5.0 bintang) untuk setiap laporan yang memenuhi standar mutu.',
            'Pengurangan nilai (penalti) otomatis terjadi bila laporan ditolak verifikator, foto tidak sesuai, atau deskripsi fiktif.',
          ],
        ),
        const SizedBox(height: 12),

        _buildSopDetailCard(
          icon: Icons.people_alt_outlined,
          title: '4. Skala Beban Operasional',
          badgeText: 'Bobot 10%',
          badgeBg: const Color(0xFFE0E7FF),
          badgeColor: const Color(0xFF4338CA),
          desc:
              'Faktor keadilan operasional yang mengapresiasi pengawas/karyawan yang memikul target tugas lebih tinggi dibanding rekan lain di departemennya.',
          ruleTitle: 'Formula Keadilan Beban Proporsional:',
          rules: const [
            'Rumus Pemain: (Target Individu / Max Target Liga) × 100%. Memberikan apresiasi beban kerja proporsional murni.',
            'Karyawan yang memikul beban target maksimal liga langsung memperoleh 100% (10.0 pts penuh).',
          ],
        ),
        const SizedBox(height: 14),

        // Contoh Simulasi Teoretis (Identik Web line 4451)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.lightbulb_rounded,
                      color: Color(0xFFF59E0B), size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Contoh Simulasi Perhitungan Teoretis:',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 11.5,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Misalkan seorang pengawas memiliki Close Rate 100%, Kualitas 100%, Capaian Target 93.3% (14 dari 15 tugas), dan memegang Target Tertinggi di Dept (100%):',
                style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• Capaian: 35% × 93.3% = 32.7 pts',
                        style: TextStyle(fontSize: 10, color: Color(0xFF334155))),
                    Text('• Close Rate: 30% × 100% = 30.0 pts',
                        style: TextStyle(fontSize: 10, color: Color(0xFF334155))),
                    Text('• Kualitas: 25% × 100% = 25.0 pts',
                        style: TextStyle(fontSize: 10, color: Color(0xFF334155))),
                    Text('• Beban: 10% × 100% = 10.0 pts',
                        style: TextStyle(fontSize: 10, color: Color(0xFF334155))),
                    Divider(height: 12),
                    Text(
                      '➔ Total Skor: 97.7 pts (97.7%)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Syarat Mutlak Juara Banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Syarat Mutlak Kelayakan Juara (Podium): Pengawas wajib Tuntas 100% Seluruh Target Program K3 (Capaian 100% / form dots hijau penuh [W] tanpa ada program yang draw/kurang). Pengawas yang kewajiban programnya belum tuntas tidak berhak menempati podium juara.',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF166534),
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSopDetailCard({
    required IconData icon,
    required String title,
    required String badgeText,
    required Color badgeBg,
    required Color badgeColor,
    required String desc,
    required String ruleTitle,
    required List<String> rules,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x040F172A),
            blurRadius: 6,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: badgeColor),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF64748B),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ruleTitle,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 4),
                ...rules.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ',
                            style: TextStyle(
                                fontSize: 9.5,
                                color: Color(0xFF0284C7),
                                fontWeight: FontWeight.w900)),
                        Expanded(
                          child: Text(
                            r,
                            style: const TextStyle(
                              fontSize: 9.5,
                              color: Color(0xFF64748B),
                              height: 1.3,
                            ),
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
  }

  Widget _buildDepartmentHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2A0F172A),
            blurRadius: 16,
            offset: Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF38BDF8), width: 1.2),
                ),
                child: const Icon(Icons.groups_rounded,
                    color: Color(0xFF38BDF8), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _departmentName.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _companyName,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Text(
                  _period,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: Color(0xFF38BDF8), size: 14),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Peringkat dihitung dari total skor PTS (35% Capaian SAP + 30% Close Rate + 25% Mutu Kualitas + 10% Beban Target).',
                    style: TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 10.5,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentUserCard(dynamic user) {
    final rank = user['rank'] ?? _userRank;
    final pos = user['pos'] ?? _userPos;
    final totalScore = (user['totalScore'] as num?)?.toDouble() ?? 0.0;
    final compliance = (user['complianceRate'] as num?)?.toDouble() ?? 0.0;
    final actual = user['totalActual'] ?? 0;
    final target = user['totalTarget'] ?? 0;
    final actualAll = user['totalActualAll'] ?? actual;
    final onsite = user['onsiteDays'] ?? 0;

    final ptsCapaian = (user['ptsCapaian'] as num?)?.toDouble() ?? ((compliance * 0.35));
    final ptsClose = (user['ptsClose'] as num?)?.toDouble() ?? 0.0;
    final ptsKualitas = (user['ptsKualitas'] as num?)?.toDouble() ?? 0.0;
    final ptsBeban = (user['ptsBeban'] as num?)?.toDouble() ?? 0.0;

    final progressVal = target > 0 ? (actual / target).clamp(0.0, 1.0) : (actual > 0 ? 1.0 : 0.0);
    final isTargetComplete = actual >= target && target > 0;
    final deficit = (target - actual).clamp(0, 999);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showEmployeeDetailModal(user),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.35), width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x330F172A),
                blurRadius: 14,
                offset: Offset(0, 6),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(color: Color(0x22000000), blurRadius: 6)
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'DEPT',
                          style: TextStyle(
                            color: Color(0xFF0369A1),
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '#$rank',
                          style: const TextStyle(
                            color: Color(0xFF0284C7),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        Text(
                          'Pos $pos',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 7.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF38BDF8).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Pos $pos dari $_totalLeaguePlayers Pemain Perusahaan',
                                style: const TextStyle(
                                  color: Color(0xFF7DD3FC),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          user['name']?.toString() ?? 'Saya',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Realisasi: $actual/$target SAP • $onsite Hari Onsite • Capaian ${compliance.toStringAsFixed(0)}% • $actualAll Lap',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        totalScore.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Color(0xFF38BDF8),
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'TOTAL PTS',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Progress Bar Target
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progressVal,
                  minHeight: 6,
                  backgroundColor: Colors.white.withOpacity(0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isTargetComplete ? const Color(0xFF22C55E) : const Color(0xFF38BDF8),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Target Deficit / Status Tag & Detail Link
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isTargetComplete ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                        size: 13,
                        color: isTargetComplete ? const Color(0xFF4ADE80) : const Color(0xFFFBBF24),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isTargetComplete
                            ? 'Target K3 Tuntas 100% (Lolos Syarat Podium)'
                            : (deficit > 0
                                ? 'Kurang $deficit laporan untuk 100% Target K3'
                                : 'Kewajiban target K3 berjalan'),
                        style: TextStyle(
                          color: isTargetComplete ? const Color(0xFF4ADE80) : const Color(0xFFFBBF24),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const Row(
                    children: [
                      Text(
                        'Audit Saya',
                        style: TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFF38BDF8)),
                    ],
                  ),
                ],
              ),

              // 4 Pillar Chips Inside User Card
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildUserPillarItem('Capaian (35%)', ptsCapaian.toStringAsFixed(1), const Color(0xFF38BDF8)),
                    Container(width: 1, height: 16, color: Colors.white12),
                    _buildUserPillarItem('Close Rate (30%)', ptsClose.toStringAsFixed(1), const Color(0xFFFBBF24)),
                    Container(width: 1, height: 16, color: Colors.white12),
                    _buildUserPillarItem('Mutu K3 (25%)', ptsKualitas.toStringAsFixed(1), const Color(0xFF4ADE80)),
                    Container(width: 1, height: 16, color: Colors.white12),
                    _buildUserPillarItem('Beban (10%)', ptsBeban.toStringAsFixed(1), const Color(0xFFA78BFA)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPodiumSection() {
    final first = _standings.isNotEmpty ? _standings[0] : null;
    final second = _standings.length > 1 ? _standings[1] : null;
    final third = _standings.length > 2 ? _standings[2] : null;

    if (first == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C0F172A),
            blurRadius: 14,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.workspace_premium_rounded,
                  color: Color(0xFFEAB308), size: 18),
              SizedBox(width: 6),
              Text(
                'PODIUM TERBAIK DEPARTEMEN',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Juara 2 (Silver)
              if (second != null)
                Expanded(
                  child: _buildPodiumColumn(
                    member: second,
                    rank: 2,
                    color: const Color(0xFF94A3B8),
                    height: 96,
                    label: '🥈 SILVER',
                  ),
                ),
              // Juara 1 (Gold)
              Expanded(
                child: _buildPodiumColumn(
                  member: first,
                  rank: 1,
                  color: const Color(0xFFEAB308),
                  height: 124,
                  label: '🥇 GOLD',
                ),
              ),
              // Juara 3 (Bronze)
              if (third != null)
                Expanded(
                  child: _buildPodiumColumn(
                    member: third,
                    rank: 3,
                    color: const Color(0xFFD97706),
                    height: 82,
                    label: '🥉 BRONZE',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumColumn({
    required dynamic member,
    required int rank,
    required Color color,
    required double height,
    required String label,
  }) {
    final name = member['name']?.toString() ?? 'Karyawan';
    final score = (member['totalScore'] as num?)?.toDouble() ?? 0.0;
    final isCur = member['isCurrentUser'] == true;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: rank == 1 ? 52 : 44,
              height: rank == 1 ? 52 : 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2.5),
                color: color.withOpacity(0.12),
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0] : 'U',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: rank == 1 ? 20 : 16,
                  ),
                ),
              ),
            ),
            if (isCur)
              Positioned(
                bottom: -2,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'SAYA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          name.split(' ').first,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: const Color(0xFF0F172A),
            fontWeight: rank == 1 ? FontWeight.w900 : FontWeight.w700,
            fontSize: 11,
          ),
        ),
        Text(
          '${score.toStringAsFixed(1)} PTS',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 11.5,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.25),
                color.withOpacity(0.08),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '#$rank',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: rank == 1 ? 26 : 20,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmployeeRow(dynamic m) {
    final rank = m['rank'] ?? 0;
    final pos = m['pos'] ?? rank;
    final name = m['name']?.toString() ?? '-';
    final nik = m['nik']?.toString() ?? '-';
    final jabatan = m['jabatan']?.toString() ?? 'Staff';
    final department = m['department']?.toString() ?? _departmentName;
    final companyName = m['companyName']?.toString() ?? _companyName;
    final isCur = m['isCurrentUser'] == true;
    final totalScore = (m['totalScore'] as num?)?.toDouble() ?? 0.0;
    final compliance = (m['complianceRate'] as num?)?.toDouble() ?? 0.0;
    final actual = m['totalActual'] ?? 0;
    final target = m['totalTarget'] ?? 0;
    final actualAll = m['totalActualAll'] ?? actual;
    final onsiteDays = m['onsiteDays'] ?? 0;
    final hasRoster = m['hasRoster'] ?? true;
    final formDots = (m['formDots'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

    final ptsCapaian = (m['ptsCapaian'] as num?)?.toDouble() ?? ((compliance * 0.35));
    final ptsClose = (m['ptsClose'] as num?)?.toDouble() ?? 0.0;
    final ptsKualitas = (m['ptsKualitas'] as num?)?.toDouble() ?? 0.0;
    final ptsBeban = (m['ptsBeban'] as num?)?.toDouble() ?? 0.0;

    Color scoreColor = const Color(0xFF16A34A);
    if (totalScore < 60) {
      scoreColor = const Color(0xFFDC2626);
    } else if (totalScore < 80) {
      scoreColor = const Color(0xFFD97706);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isCur ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCur
              ? const Color(0xFF22C55E).withOpacity(0.7)
              : const Color(0xFFE2E8F0),
          width: isCur ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showEmployeeDetailModal(m),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pos pill (e.g. 20, 171, 184)
                    Container(
                      width: 42,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'POS',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 7.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '$pos',
                            style: const TextStyle(
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Name & Company/Dept Badges
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF1E293B),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              if (isCur) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF22C55E),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'ANDA',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Badges: Company, Dept, NIK
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0F2FE),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: const Color(0xFFBAE6FD), width: 0.8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.business_rounded,
                                        size: 10, color: Color(0xFF0369A1)),
                                    const SizedBox(width: 3),
                                    Text(
                                      companyName,
                                      style: const TextStyle(
                                        color: Color(0xFF0369A1),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: const Color(0xFFE2E8F0), width: 0.8),
                                ),
                                child: Text(
                                  department,
                                  style: const TextStyle(
                                    color: Color(0xFF334155),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                '• $nik',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Subline: Jabatan, Tgt, Onsite
                          Wrap(
                            spacing: 5,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '• $jabatan',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (target > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEEF2FF),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: const Color(0xFFC7D2FE), width: 0.8),
                                  ),
                                  child: Text(
                                    '🎯 Tgt: $target',
                                    style: const TextStyle(
                                      color: Color(0xFF4338CA),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: hasRoster && onsiteDays == 0
                                      ? const Color(0xFF64748B)
                                      : const Color(0xFF0EA5E9),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  hasRoster
                                      ? (onsiteDays == 0
                                          ? '0 Hari Onsite (Cuti)'
                                          : '$onsiteDays Hari Onsite')
                                      : 'Roster belum diseting',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 4 Pilar Skor Micro Grid untuk analisis cepat
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildPillarScoreItem('Capaian (35%)', ptsCapaian.toStringAsFixed(1), const Color(0xFF0284C7)),
                      _buildPillarDivider(),
                      _buildPillarScoreItem('Close (30%)', ptsClose.toStringAsFixed(1), const Color(0xFFD97706)),
                      _buildPillarDivider(),
                      _buildPillarScoreItem('Mutu (25%)', ptsKualitas.toStringAsFixed(1), const Color(0xFF16A34A)),
                      _buildPillarDivider(),
                      _buildPillarScoreItem('Beban (10%)', ptsBeban.toStringAsFixed(1), const Color(0xFF7C3AED)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 8),

                // Bottom Row: PTS & Capaian (Left) + Form (5 Program) + Detail Button (Right)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // PTS & Capaian
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${totalScore.toStringAsFixed(1)} pts',
                          style: TextStyle(
                            color: scoreColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 14.5,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(
                              'Capaian: $compliance%',
                              style: TextStyle(
                                color: scoreColor,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Text(' • ',
                                style: TextStyle(
                                    color: Color(0xFF94A3B8), fontSize: 10)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: const Color(0xFFA7F3D0), width: 0.8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.shield_outlined,
                                      size: 10, color: Color(0xFF047857)),
                                  const SizedBox(width: 2),
                                  Text(
                                    '$actualAll Lap',
                                    style: const TextStyle(
                                      color: Color(0xFF047857),
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Form (5 Program) & Detail Button
                    Row(
                      children: [
                        // 5 Dots
                        Row(
                          children: formDots.map((dot) {
                            Color dotBg = const Color(0xFF16A34A);
                            if (dot == 'D') dotBg = const Color(0xFFF59E0B);
                            if (dot == 'L') dotBg = const Color(0xFFDC2626);
                            if (dot == '-') dotBg = const Color(0xFF94A3B8);

                            return Container(
                              width: 17,
                              height: 17,
                              margin: const EdgeInsets.only(right: 3),
                              decoration: BoxDecoration(
                                color: dotBg,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  dot,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    height: 1,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(width: 8),

                        // Detail Button
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Detail',
                                style: TextStyle(
                                  color: Color(0xFF334155),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 2),
                              Icon(Icons.keyboard_arrow_down_rounded,
                                  size: 14, color: Color(0xFF64748B)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEmployeeDetailModal(dynamic m) {
    final name = m['name']?.toString() ?? '-';
    final nik = m['nik']?.toString() ?? '-';
    final jabatan = m['jabatan']?.toString() ?? 'Staff';
    final companyName = m['companyName']?.toString() ?? _companyName;
    final rank = m['rank'] ?? 0;
    final pos = m['pos'] ?? rank;
    final totalPlayers = m['totalPlayers'] ?? 453;
    final onsiteDays = m['onsiteDays'] ?? 0;
    final actualAll = m['totalActualAll'] ?? 0;
    final totalScore = (m['totalScore'] as num?)?.toDouble() ?? 0.0;
    final compliance = (m['complianceRate'] as num?)?.toDouble() ?? 0.0;
    final closeRate = (m['closeRate'] as num?)?.toDouble() ?? 100.0;
    final crCreator = (m['crCreatorScore'] as num?)?.toDouble() ?? 100.0;
    final crPic = (m['crPicScore'] as num?)?.toDouble() ?? 100.0;
    final quality = (m['qualityScore'] as num?)?.toDouble() ?? 100.0;
    final scaleBeban = (m['scaleBebanScore'] as num?)?.toDouble() ?? 16.7;
    final maxTargetComp = m['maxTargetPlayer'] ?? 30;

    final ptsCapaian = (m['ptsCapaian'] as num?)?.toDouble() ?? 0.0;
    final ptsClose = (m['ptsClose'] as num?)?.toDouble() ?? 0.0;
    final ptsKualitas = (m['ptsKualitas'] as num?)?.toDouble() ?? 0.0;
    final ptsBeban = (m['ptsBeban'] as num?)?.toDouble() ?? 0.0;

    final actual = m['totalActual'] ?? 0;
    final target = m['totalTarget'] ?? 0;

    final hazard = m['hazard'] ?? {};
    final inspeksi = m['inspeksi'] ?? {};
    final safetyTalk = m['safetyTalk'] ?? {};
    final observasi = m['observasi'] ?? {};
    final coaching = m['coaching'] ?? {};
    final p5m = m['p5m'] ?? {};

    int activeModalTab = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.88,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollCtrl) => ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Tab Switcher Header (Identik Tab di Web #leagueScoringModal)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setModalState(() => activeModalTab = 0),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: activeModalTab == 0 ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: activeModalTab == 0
                                ? const [
                                    BoxShadow(
                                      color: Color(0x100F172A),
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    )
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_pin_rounded,
                                size: 16,
                                color: activeModalTab == 0
                                    ? const Color(0xFF0284C7)
                                    : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Kalkulasi Riil (${name.split(' ').first})',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: activeModalTab == 0
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => setModalState(() => activeModalTab = 1),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: activeModalTab == 1 ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: activeModalTab == 1
                                ? const [
                                    BoxShadow(
                                      color: Color(0x100F172A),
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    )
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.menu_book_rounded,
                                size: 16,
                                color: activeModalTab == 1
                                    ? const Color(0xFF0284C7)
                                    : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Panduan SOP & Metodologi',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: activeModalTab == 1
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              if (activeModalTab == 1) ...[
                _buildSopGuideContent(),
              ] else ...[
                // Top Header: Peringkat & Posisi Liga
                Row(
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'POS $pos',
                            style: const TextStyle(
                              color: Color(0xFF0284C7),
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '#$rank Dept ($totalPlayers L)',
                            style: const TextStyle(
                              color: Color(0xFF0369A1),
                              fontWeight: FontWeight.w700,
                              fontSize: 8.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.w900,
                              fontSize: 14.5,
                            ),
                          ),
                          Text(
                            '$nik • $jabatan',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${totalScore.toStringAsFixed(1)} pts',
                            style: const TextStyle(
                              color: Color(0xFF38BDF8),
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          const Text(
                            'TOTAL SKOR',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Header Bar Aktivitas K3
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AKTIVITAS K3 BULAN INI (Realisasi / Target)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF334155),
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFBAE6FD)),
                            ),
                            child: Text(
                              companyName,
                              style: const TextStyle(
                                color: Color(0xFF0369A1),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Text(
                              '📅 $onsiteDays Hari Onsite',
                              style: const TextStyle(
                                color: Color(0xFF1D4ED8),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: Text(
                              '🛡️ Total Laporan: $actualAll',
                              style: const TextStyle(
                                color: Color(0xFF047857),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 7 KPI Summary Strip (Horizontal & Compact)
                const Text(
                  '7 KPI Realisasi Program K3',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildKpiStripItem('Hazard', '${hazard['actual'] ?? 0} / ${hazard['target'] ?? 0}'),
                      const SizedBox(width: 6),
                      _buildKpiStripItem('Inspeksi', '${inspeksi['actual'] ?? 0} / ${inspeksi['target'] ?? 0}'),
                      const SizedBox(width: 6),
                      _buildKpiStripItem('S. Talk', '${safetyTalk['actual'] ?? 0} / ${safetyTalk['target'] ?? 0}'),
                      const SizedBox(width: 6),
                      _buildKpiStripItem('Observasi', '${observasi['actual'] ?? 0} / ${observasi['target'] ?? 0}'),
                      const SizedBox(width: 6),
                      _buildKpiStripItem('Coaching', '${coaching['actual'] ?? 0} / ${coaching['target'] ?? 0}'),
                      const SizedBox(width: 6),
                      _buildKpiStripItem('P5M *', '${p5m['actual'] ?? 0} / ${p5m['target'] ?? 0}', isHighlight: true),
                      const SizedBox(width: 6),
                      _buildKpiStripItem('Close Rate', '$closeRate%', isRate: true),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Section Header Rincian Formula Skor Akhir (PTS)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.calculate_rounded,
                            size: 18, color: Color(0xFF0284C7)),
                        SizedBox(width: 6),
                        Text(
                          'Rincian Formula Skor Akhir (PTS)',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: const Text(
                        'Dual Accountability',
                        style: TextStyle(
                          color: Color(0xFF1D4ED8),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 4 Formula Cards (2x2 Grid)
                Row(
                  children: [
                    Expanded(
                      child: _buildCleanFormulaCard(
                        title: '1. Capaian Target',
                        weight: 'Bobot 35%',
                        weightColor: const Color(0xFF1D4ED8),
                        weightBg: const Color(0xFFDBEAFE),
                        mainValue: '$compliance%',
                        formulaText: '35% × $compliance% = ${ptsCapaian.toStringAsFixed(1)} pts',
                        subInfoLeft: 'Realisasi: $actual',
                        subInfoRight: 'Target: $target',
                        description: 'Kepatuhan kuantitatif 5 program bulanan ($compliance%) sesuai hari onsite.',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildCleanFormulaCard(
                        title: '2. Close Rate',
                        weight: 'Bobot 30%',
                        weightColor: const Color(0xFF15803D),
                        weightBg: const Color(0xFFDCFCE7),
                        mainValue: '$closeRate%',
                        formulaText: '30% × $closeRate% = ${ptsClose.toStringAsFixed(1)} pts',
                        subInfoLeft: 'Pelapor: $crCreator%',
                        subInfoRight: 'PIC: $crPic%',
                        description: 'Penyelesaian temuan K3. Penutupan mandiri dibatasi maks 50% untuk verifikasi silang.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildCleanFormulaCard(
                        title: '3. Kualitas Mutu',
                        weight: 'Bobot 25%',
                        weightColor: const Color(0xFFB45309),
                        weightBg: const Color(0xFFFEF3C7),
                        mainValue: '$quality%',
                        formulaText: '25% × $quality% = ${ptsKualitas.toStringAsFixed(1)} pts',
                        subInfoLeft: 'Standar Mutu SAP',
                        subInfoRight: '5.0 / 5.0 ★',
                        description: 'Mutu deskripsi & bukti validasi SAP (Baseline 100% tanpa penalti).',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildCleanFormulaCard(
                        title: '4. Skala Beban',
                        weight: 'Bobot 10%',
                        weightColor: const Color(0xFF4338CA),
                        weightBg: const Color(0xFFE0E7FF),
                        mainValue: '$scaleBeban%',
                        formulaText: '10% × $scaleBeban% = ${ptsBeban.toStringAsFixed(1)} pts',
                        subInfoLeft: 'Tgt Anda: $target',
                        subInfoRight: 'Max Liga: $maxTargetComp',
                        description: 'Proporsional ($target / $maxTargetComp × 100%): Target tugas lebih banyak mendapat bobot beban lebih besar.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Banner Rangkuman Akumulasi PTS
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x060F172A),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE0F2FE),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.info_rounded,
                            color: Color(0xFF0284C7), size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Akumulasi Skor PTS:',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '(${ptsCapaian.toStringAsFixed(1)} pts) + (${ptsClose.toStringAsFixed(1)} pts) + (${ptsKualitas.toStringAsFixed(1)} pts) + (${ptsBeban.toStringAsFixed(1)} pts) = ${totalScore.toStringAsFixed(1)} pts',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Standar penilaian objektif, akuntabel & terverifikasi sistem.',
                              style: TextStyle(
                                fontSize: 9.5,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Syarat Mutlak Podium Banner
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.verified_rounded,
                          color: Color(0xFF16A34A), size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Syarat Mutlak Kelayakan Juara (Podium): Pengawas wajib Tuntas 100% Seluruh Target Program K3 (Capaian 100% / form dots hijau penuh [W] tanpa ada program yang draw/kurang).',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF166534),
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Button: Salin Rincian Audit Karyawan Ini
                InkWell(
                  onTap: () => _copyEmployeeAuditReport(m),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.copy_rounded, color: Color(0xFF0284C7), size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Salin Rincian Skor Audit (${name.split(' ').first})',
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiStripItem(String label, String value,
      {bool isHighlight = false, bool isRate = false}) {
    Color valColor = const Color(0xFF1E293B);
    if (isHighlight) valColor = const Color(0xFFD97706);
    if (isRate) valColor = const Color(0xFF16A34A);

    return Container(
      width: 74,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              color: valColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCleanFormulaCard({
    required String title,
    required String weight,
    required Color weightColor,
    required Color weightBg,
    required String mainValue,
    required String formulaText,
    required String subInfoLeft,
    required String subInfoRight,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x040F172A),
            blurRadius: 6,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: weightBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  weight,
                  style: TextStyle(
                    color: weightColor,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              mainValue,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: weightColor,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Text(
              formulaText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF334155),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                subInfoLeft,
                style: const TextStyle(
                  fontSize: 8.5,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subInfoRight,
                style: const TextStyle(
                  fontSize: 8.5,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 8,
              color: Color(0xFF94A3B8),
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}


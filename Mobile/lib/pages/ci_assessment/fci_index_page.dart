import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api.dart';
import '../../services/preference.dart';
import '../../widgets/top_bar.dart';
import 'fci_form_page.dart';
import 'fci_model.dart';

class FciIndexPage extends StatefulWidget {
  const FciIndexPage({super.key});

  @override
  State<FciIndexPage> createState() => _FciIndexPageState();
}

class _FciIndexPageState extends State<FciIndexPage> {
  final _api = ApiService();

  List<FciReportItem> _reports = [];
  FciSummaryStats _stats = FciSummaryStats();
  List<String> _pits = [];

  bool _isLoading = true;
  String? _errorMessage;

  String _searchQuery = '';
  String? _selectedPit;
  String? _selectedKategori;

  String _currentUserNik = '';
  String _currentUserNama = '';
  String _currentUserCompany = '';
  int _currentUserCompanyId = 0;
  String _selectedScope = 'my_history'; // 'my_history', 'pic', 'created', 'all'

  static const _tealColor = Color(0xFF0F766E);
  static const _tealAccent = Color(0xFF14B8A6);

  @override
  void initState() {
    super.initState();
    _initLoad();
  }

  Future<void> _initLoad() async {
    await _loadUser();
    _fetchData();
  }

  Future<void> _loadUser() async {
    final profile = PreferenceService.getProfile();
    final nik = profile?.noNik ?? PreferenceService.getUser() ?? '';
    final nama = profile?.namaLengkap ?? '';
    final company = profile?.company ?? '';
    final companyId = profile?.companyId ?? 0;
    if (mounted) {
      setState(() {
        _currentUserNik = nik;
        _currentUserNama = nama;
        _currentUserCompany = company;
        _currentUserCompanyId = companyId;
      });
    }
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _api.getFciList(
        search: _searchQuery.trim().isNotEmpty ? _searchQuery.trim() : null,
        pit: _selectedPit,
        kategori: _selectedKategori,
        userNik: _currentUserNik.isNotEmpty ? _currentUserNik : null,
        userNama: _currentUserNama.isNotEmpty ? _currentUserNama : null,
        companyId: _currentUserCompanyId > 0 ? _currentUserCompanyId : null,
        companyName: _currentUserCompany.isNotEmpty ? _currentUserCompany : null,
        scope: _selectedScope,
      );

      res.fold(
        (err) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = err['message']?.toString() ?? 'Gagal memuat data FCI';
            });
          }
        },
        (data) {
          if (mounted) {
            final rawList = data['data'] as List<dynamic>? ?? [];
            final reports = rawList.map((e) => FciReportItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();

            final statsJson = data['stats'] as Map<String, dynamic>?;
            final stats = FciSummaryStats.fromJson(statsJson);

            final pitsRaw = data['pits'] as List<dynamic>? ?? [];
            final pits = pitsRaw.map((e) => e.toString()).toList();

            setState(() {
              _reports = reports;
              _stats = stats;
              _pits = pits;
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Terjadi kesalahan: $e';
        });
      }
    }
  }

  Future<void> _deleteReport(FciReportItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Color(0xFFF43F5E), size: 28),
            SizedBox(width: 8),
            Text('Hapus Laporan FCI?'),
          ],
        ),
        content: Text(
          'Laporan Front "${item.namaFront ?? item.lokasi}" (${DateFormat('dd MMM yyyy').format(item.tanggal)}) akan dihapus dari sistem. Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF43F5E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await _api.deleteFciReport(item.id);
      res.fold(
        (err) => _showSnack(err['message']?.toString() ?? 'Gagal menghapus laporan'),
        (succ) {
          _showSnack('Laporan FCI berhasil dihapus', isSuccess: true);
          _fetchData();
        },
      );
    } catch (e) {
      _showSnack('Gagal menghapus: $e');
    }
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _openDetailModal(FciReportItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(color: _tealAccent.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.compass_calibration_rounded, color: _tealColor, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Text('Detail Laporan FCI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Header card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  item.namaFront ?? item.lokasi,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getBadgeBg(item.totalScore),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${item.totalScore}% (${item.kategoriIndex})',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _getBadgeColor(item.totalScore)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Area: ${item.area} | Pit: ${item.pit ?? "-"} | Shift: ${item.shift ?? "-"}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          if (item.detilLokasi != null && item.detilLokasi!.isNotEmpty)
                            Text('Benchmark: ${item.detilLokasi}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          Text('Lokasi: ${item.lokasi}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          if (item.latitude != null && item.latitude!.isNotEmpty)
                            Text('GPS: ${item.latitude}, ${item.longitude}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                          const SizedBox(height: 8),
                          Text('Inspektor: ${item.nama} (${item.nik}) | ${DateFormat('dd MMM yyyy').format(item.tanggal)} ${item.waktu}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    const Text('Rincian 8 Parameter Penilaian', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 10),

                    _buildDetailParamRow('1. Lantai Front (15%)', item.skorLantaiFront),
                    _buildDetailParamRow('2. Ruang Manuver & Spotting (15%)', item.skorRuangManuver),
                    _buildDetailParamRow('3. Safety Berm / Tanggul (15%)', item.skorSafetyBerm),
                    _buildDetailParamRow('4. Kondisi Dinding Highwall (15%)', item.skorKondisiDinding),
                    _buildDetailParamRow('5. Drainase & Sump Front (10%)', item.skorDrainaseSump),
                    _buildDetailParamRow('6. Kebersihan Ceceran Material (10%)', item.skorKebersihanSpillage),
                    _buildDetailParamRow('7. Posisi & Ketinggian Alat (10%)', item.skorPosisiAlat),
                    _buildDetailParamRow('8. Rambu & Penerangan (10%)', item.skorRambuPenerangan),

                    const SizedBox(height: 16),

                    if (item.catatan != null && item.catatan!.isNotEmpty) ...[
                      const Text('Catatan Observasi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(12),
                        width: double.infinity,
                        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
                        child: Text(item.catatan!, style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155))),
                      ),
                      const SizedBox(height: 12),
                    ],

                    if (item.tindakanPerbaikan != null && item.tindakanPerbaikan!.isNotEmpty) ...[
                      const Text('Rekomendasi Tindakan Perbaikan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(12),
                        width: double.infinity,
                        decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFDE68A))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.tindakanPerbaikan!, style: const TextStyle(fontSize: 12.5, color: Color(0xFF92400E))),
                            if (item.pic != null && item.pic!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('PIC: ${item.pic}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    if (item.fotoUrl != null && item.fotoUrl!.isNotEmpty) ...[
                      const Text('Foto Dokumentasi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          item.fotoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 140,
                            color: const Color(0xFFF1F5F9),
                            alignment: Alignment.center,
                            child: const Text('Foto tidak dapat dimuat', style: TextStyle(color: Color(0xFF94A3B8))),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // WhatsApp Share
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _shareItemToWhatsApp(item),
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Bagikan Laporan ke WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildDetailParamRow(String label, int score) {
    final color = score == 100
        ? const Color(0xFF10B981)
        : (score == 70 ? const Color(0xFFF59E0B) : const Color(0xFFF43F5E));

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
            child: Text('$score', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)),
          ),
        ],
      ),
    );
  }

  Future<void> _shareItemToWhatsApp(FciReportItem item) async {
    final tglStr = DateFormat('dd MMM yyyy').format(item.tanggal);
    final text = StringBuffer();
    text.writeln('📋 *LAPORAN PENILAIAN FRONT CONDITION INDEX (FCI)*');
    text.writeln('📅 Waktu: $tglStr ${item.waktu} | Shift: ${item.shift ?? "-"}');
    text.writeln('📍 Area: ${item.area} | Front: ${item.namaFront ?? item.lokasi} | Pit: ${item.pit ?? "-"}');
    if (item.detilLokasi != null && item.detilLokasi!.isNotEmpty) text.writeln('📌 Benchmark: ${item.detilLokasi}');
    text.writeln('---------------------------------------');
    text.writeln('⭐ *SKOR FCI: ${item.totalScore}% (${item.kategoriIndex.toUpperCase()})*');
    text.writeln('1. Lantai Front (15%): ${item.skorLantaiFront}');
    text.writeln('2. Ruang Manuver (15%): ${item.skorRuangManuver}');
    text.writeln('3. Safety Berm (15%): ${item.skorSafetyBerm}');
    text.writeln('4. Kondisi Dinding (15%): ${item.skorKondisiDinding}');
    text.writeln('5. Drainase Sump (10%): ${item.skorDrainaseSump}');
    text.writeln('6. Kebersihan Spillage (10%): ${item.skorKebersihanSpillage}');
    text.writeln('7. Posisi Alat Bench (10%): ${item.skorPosisiAlat}');
    text.writeln('8. Rambu & Penerangan (10%): ${item.skorRambuPenerangan}');
    text.writeln('---------------------------------------');
    if (item.catatan != null && item.catatan!.isNotEmpty) text.writeln('📝 *Catatan:* ${item.catatan}');
    if (item.tindakanPerbaikan != null && item.tindakanPerbaikan!.isNotEmpty) {
      text.writeln('🛠️ *Tindakan Perbaikan:* ${item.tindakanPerbaikan} (PIC: ${item.pic ?? "-"})');
    }
    text.writeln('👤 *Inspektor:* ${item.nama} (${item.nik})');
    text.writeln('\n_Dilaporkan via SAP Mobile - Indexsafe Evolution_');

    final uri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(text.toString())}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await Clipboard.setData(ClipboardData(text: text.toString()));
        _showSnack('Teks berhasil disalin ke clipboard!', isSuccess: true);
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text.toString()));
      _showSnack('Teks berhasil disalin ke clipboard!', isSuccess: true);
    }
  }

  Color _getBadgeColor(double score) {
    if (score >= 85) return const Color(0xFF10B981);
    if (score >= 70) return const Color(0xFFF59E0B);
    return const Color(0xFFF43F5E);
  }

  Color _getBadgeBg(double score) {
    if (score >= 85) return const Color(0xFF10B981).withOpacity(0.12);
    if (score >= 70) return const Color(0xFFF59E0B).withOpacity(0.12);
    return const Color(0xFFF43F5E).withOpacity(0.12);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: const TopBar(title: 'Front Condition Index (FCI)'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final res = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const FciFormPage()),
          );
          if (res == true) _fetchData();
        },
        backgroundColor: _tealColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Buat Penilaian FCI', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
          children: [
            // TOP SUMMARY METRICS (30 Days) Matching Web
            _buildTopMetrics(),

            const SizedBox(height: 16),

            // SEARCH & FILTER BAR
            _buildFilterBar(),

            const SizedBox(height: 14),

            // LIST SECTION
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _selectedScope == 'all' && _currentUserCompany.isNotEmpty
                        ? 'Semua Front - $_currentUserCompany (${_reports.length})'
                        : 'Riwayat Inspeksi FCI (${_reports.length})',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: Color(0xFF1E293B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_isLoading)
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _tealColor)),
              ],
            ),

            const SizedBox(height: 10),

            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Column(
                  children: [
                    Text(_errorMessage!, style: const TextStyle(color: Color(0xFFDC2626))),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _fetchData,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              )
            else if (_isLoading && _reports.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(color: _tealColor),
                ),
              )
            else if (_reports.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.inbox_rounded, size: 48, color: Color(0xFF94A3B8)),
                    SizedBox(height: 10),
                    Text('Belum ada data inspeksi FCI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    SizedBox(height: 4),
                    Text('Klik tombol di bawah untuk membuat penilaian front baru', style: TextStyle(color: Color(0xFF64748B), fontSize: 12), textAlign: TextAlign.center),
                  ],
                ),
              )
            else
              ..._reports.map((item) => _buildReportCard(item)),
          ],
        ),
      ),
    );
  }

  Widget _buildTopMetrics() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'Total Inspeksi',
                value: '${_stats.totalReports}',
                subtitle: '30 Hari Terakhir',
                icon: Icons.assignment_turned_in_rounded,
                accentColor: _tealAccent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                title: 'Rata-rata Skor',
                value: '${_stats.avgScore}%',
                subtitle: 'Target: ≥ 85%',
                icon: Icons.speed_rounded,
                accentColor: _stats.avgScore >= 85
                    ? const Color(0xFF10B981)
                    : (_stats.avgScore >= 70 ? const Color(0xFFF59E0B) : const Color(0xFFF43F5E)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'Kondisi Baik',
                value: '${_stats.goodCount}',
                subtitle: 'Skor ≥ 85%',
                icon: Icons.check_circle_rounded,
                accentColor: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                title: 'Perlu Perbaikan',
                value: '${_stats.fairCount + _stats.poorCount}',
                subtitle: '${_stats.poorCount} Kritis, ${_stats.fairCount} Sedang',
                icon: Icons.warning_amber_rounded,
                accentColor: const Color(0xFFF43F5E),
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
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: accentColor)),
                Text(subtitle, style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HISTORY SCOPE SELECTOR TABS
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildScopeTab('Riwayat Saya', 'my_history', Icons.history_rounded),
                _buildScopeTab('Sebagai PIC', 'pic', Icons.assignment_ind_rounded),
                _buildScopeTab('Dibuat Saya', 'created', Icons.edit_note_rounded),
                _buildScopeTab('Semua Front', 'all', Icons.public_rounded),
              ],
            ),
          ),

          if (_selectedScope == 'all' && _currentUserCompany.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _tealAccent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.business_rounded, size: 14, color: _tealColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Menampilkan seluruh front: $_currentUserCompany',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _tealColor),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Search Box
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              onSubmitted: (val) {
                _searchQuery = val;
                _fetchData();
              },
              decoration: InputDecoration(
                hintText: 'Cari front, pit, lokasi, atau nama...',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          setState(() => _searchQuery = '');
                          _fetchData();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Pit & Kategori Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Kategori: Semua
                _buildFilterChip('Semua Kategori', _selectedKategori == null, () {
                  setState(() => _selectedKategori = null);
                  _fetchData();
                }),
                const SizedBox(width: 6),
                _buildFilterChip('Baik (≥85%)', _selectedKategori == 'Baik', () {
                  setState(() => _selectedKategori = _selectedKategori == 'Baik' ? null : 'Baik');
                  _fetchData();
                }),
                const SizedBox(width: 6),
                _buildFilterChip('Sedang (70-84%)', _selectedKategori == 'Sedang', () {
                  setState(() => _selectedKategori = _selectedKategori == 'Sedang' ? null : 'Sedang');
                  _fetchData();
                }),
                const SizedBox(width: 6),
                _buildFilterChip('Kurang (<70%)', _selectedKategori == 'Kurang', () {
                  setState(() => _selectedKategori = _selectedKategori == 'Kurang' ? null : 'Kurang');
                  _fetchData();
                }),

                if (_pits.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Container(width: 1, height: 20, color: const Color(0xFFCBD5E1)),
                  const SizedBox(width: 10),
                  ..._pits.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _buildFilterChip(p, _selectedPit == p, () {
                        setState(() => _selectedPit = _selectedPit == p ? null : p);
                        _fetchData();
                      }),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScopeTab(String label, String value, IconData icon) {
    final isSelected = _selectedScope == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedScope != value) {
            setState(() => _selectedScope = value);
            _fetchData();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? const [BoxShadow(color: Color(0x12000000), blurRadius: 4, offset: Offset(0, 1))]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? _tealColor : const Color(0xFF64748B),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? _tealColor : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? _tealColor : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildReportCard(FciReportItem item) {
    final borderAccent = _getBadgeColor(item.totalScore);

    final cleanNik = _currentUserNik.trim();
    final cleanNama = _currentUserNama.trim().toLowerCase();
    final isAssignedAsPic = (cleanNik.isNotEmpty && (item.pic?.contains(cleanNik) ?? false)) ||
        (cleanNama.isNotEmpty && (item.pic?.toLowerCase().contains(cleanNama) ?? false));
    final isCreator = cleanNik.isNotEmpty && item.nik == cleanNik;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      color: Colors.white,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: borderAccent, width: 4.5)),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PIC Assignment Banner or Creator Badge
            if (isAssignedAsPic) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_rounded, size: 15, color: Color(0xFFB45309)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Anda Ditugaskan Sebagai PIC Perbaikan',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (isCreator) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_rounded, size: 12, color: _tealColor),
                    SizedBox(width: 4),
                    Text(
                      'Laporan Dibuat Oleh Anda',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _tealColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Top Row: Front Name & Score Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.namaFront ?? item.lokasi,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF0F172A)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (item.pit != null && item.pit!.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                              child: Text(item.pit!, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (item.shift != null && item.shift!.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                              child: Text(item.shift!, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getBadgeBg(item.totalScore),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${item.totalScore}%',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: _getBadgeColor(item.totalScore)),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.kategoriIndex,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getBadgeColor(item.totalScore)),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Location
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${item.area} | ${item.lokasi}${item.detilLokasi != null && item.detilLokasi!.isNotEmpty ? " (${item.detilLokasi})" : ""}',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Score Pills Summary
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                _buildScoreMiniPill('Lantai', item.skorLantaiFront),
                _buildScoreMiniPill('Manuver', item.skorRuangManuver),
                _buildScoreMiniPill('Berm', item.skorSafetyBerm),
                _buildScoreMiniPill('Dinding', item.skorKondisiDinding),
                _buildScoreMiniPill('Sump', item.skorDrainaseSump),
                _buildScoreMiniPill('Spillage', item.skorKebersihanSpillage),
                _buildScoreMiniPill('Alat', item.skorPosisiAlat),
                _buildScoreMiniPill('Rambu', item.skorRambuPenerangan),
              ],
            ),

            if (item.catatan != null && item.catatan!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                width: double.infinity,
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
                child: Text('Obs: ${item.catatan}', style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
              ),
            ],

            if (item.tindakanPerbaikan != null && item.tindakanPerbaikan!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(8),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Text(
                  'Perbaikan: ${item.tindakanPerbaikan}${item.pic != null && item.pic!.isNotEmpty ? " (PIC: ${item.pic})" : ""}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                ),
              ),
            ],

            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 8),

            // Footer: Inspector info & Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${item.nama} • ${DateFormat('dd MMM yyyy').format(item.tanggal)} ${item.waktu}',
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Detail Button
                    InkWell(
                      onTap: () => _openDetailModal(item),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                        child: const Row(
                          children: [
                            Icon(Icons.visibility_rounded, size: 13, color: Color(0xFF0284C7)),
                            SizedBox(width: 4),
                            Text('Detail', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // WhatsApp Share
                    InkWell(
                      onTap: () => _shareItemToWhatsApp(item),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(6)),
                        child: const Icon(Icons.share_rounded, size: 14, color: Color(0xFF16A34A)),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Edit Button (if creator)
                    if (isCreator || _currentUserNik.isEmpty) ...[
                      InkWell(
                        onTap: () async {
                          final res = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(builder: (_) => FciFormPage(editData: item)),
                          );
                          if (res == true) _fetchData();
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(6)),
                          child: const Icon(Icons.edit_rounded, size: 14, color: Color(0xFFD97706)),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Delete Button
                      InkWell(
                        onTap: () => _deleteReport(item),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(6)),
                          child: const Icon(Icons.delete_rounded, size: 14, color: Color(0xFFDC2626)),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreMiniPill(String label, int score) {
    final color = score == 100
        ? const Color(0xFF10B981)
        : (score == 70 ? const Color(0xFFF59E0B) : const Color(0xFFF43F5E));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        '$label: $score',
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}

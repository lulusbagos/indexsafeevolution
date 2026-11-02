import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/api.dart';
import '../services/notification.dart';

class ReinductionApprovalPage extends StatefulWidget {
  final int? reinduksiId;
  final Map<String, dynamic>? initialData;

  const ReinductionApprovalPage({
    super.key,
    this.reinduksiId,
    this.initialData,
  });

  @override
  State<ReinductionApprovalPage> createState() => _ReinductionApprovalPageState();
}

class _ReinductionApprovalPageState extends State<ReinductionApprovalPage> {
  final ApiService _api = ApiService();
  final DateFormat _displayFormat = DateFormat('dd MMM yyyy');

  bool _isLoading = true;
  bool _isActioning = false;
  Map<String, dynamic>? _data;
  bool _canApprove = false;

  final List<String> _questions = [
    'Apakah Mine Permit & SIMPER karyawan masih berlaku?',
    'Apakah APD karyawan masih layak digunakan?',
    'Apakah karyawan sudah dijelaskan:\na. Materi Safety Talk terakhir\nb. Peraturan-Ketentuan baru di lingkungan perusahaan\nc. Rambu-rambu Keselamatan yang baru/berubah\nd. Accident-Incident terakhir',
    'Apakah karyawan sudah di-ingatkan lagi tentang Golden Rules?',
    'Apakah karyawan sudah di-ingatkan lagi tentang tata cara komunikasi Radio yang baik, termasuk saat "Penting" dan Emergency?',
    'Apakah karyawan sudah dijelaskan temuan inspeksi HSE terakhir yang belum maupun sudah ditindaklanjuti?',
    'Apakah karyawan sudah memahami ketentuan umum K3LH terlampir?',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _data = widget.initialData;
      _canApprove = _data?['status'] == 'PENDING_APPROVAL';
      _isLoading = false;
    }
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    final id = widget.reinduksiId ?? _data?['id'];
    if (id == null) {
      setState(() => _isLoading = false);
      return;
    }

    final res = await _api.getReinduksiDetail(id);
    if (!mounted) return;

    setState(() => _isLoading = false);
    res.fold(
      (err) {
        if (_data == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(err['message'] ?? 'Gagal memuat detail Re-Induksi'),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      },
      (val) {
        setState(() {
          _data = Map<String, dynamic>.from(val['data'] as Map);
          _canApprove = val['canApprove'] == true;
        });
      },
    );
  }

  Future<void> _processApproval(bool isApprove) async {
    HapticFeedback.mediumImpact();
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isApprove ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: isApprove ? const Color(0xFF10B981) : const Color(0xFFDC2626),
              size: 26,
            ),
            const SizedBox(width: 10),
            Text(
              isApprove ? 'Setujui Re-Induksi?' : 'Tolak Re-Induksi?',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isApprove
                  ? 'Apakah Anda yakin menyetujui hasil Form Re-Induksi dan jadwal dinas karyawan ini?'
                  : 'Harap berikan alasan penolakan agar karyawan dapat merevisi roster/re-induksinya:',
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: isApprove ? 'Catatan persetujuan (opsional)' : 'Alasan penolakan (wajib diisi)...',
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isApprove ? const Color(0xFF10B981) : const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              if (!isApprove && notesController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Alasan penolakan wajib diisi.'),
                    backgroundColor: Color(0xFFDC2626),
                  ),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: Text(isApprove ? 'Setujui' : 'Tolak'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isActioning = true);
    final id = _data?['id'] ?? widget.reinduksiId;

    final res = await _api.actionReinduksi(
      reinduksiId: id,
      action: isApprove ? 'APPROVE' : 'REJECT',
      notes: notesController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isActioning = false);

    res.fold(
      (err) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err['message'] ?? 'Gagal memproses persetujuan'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      },
      (success) {
        NotificationService.display(
          title: isApprove ? 'Re-Induksi Disetujui' : 'Re-Induksi Ditolak',
          body: isApprove
              ? 'Persetujuan Form Re-Induksi & Jadwal Roster berhasil dikonfirmasi.'
              : 'Form Re-Induksi telah ditolak dan dikembalikan ke karyawan.',
          payload: '/roster',
          notifType: 'reinduksi_action_done',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success['message'] ?? 'Berhasil diproses!'),
            backgroundColor: isApprove ? const Color(0xFF10B981) : const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.of(context).pop(true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Detail Re-Induksi', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          backgroundColor: const Color(0xFF0F766E),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF0F766E)),
        ),
      );
    }

    if (_data == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Detail Re-Induksi', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          backgroundColor: const Color(0xFF0F766E),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Data Re-Induksi tidak ditemukan.'),
        ),
      );
    }

    final d = _data!;
    final status = (d['status'] ?? 'PENDING_APPROVAL').toString().toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'VERIFIKASI RE-INDUKSI',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.8),
        ),
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Badge Card
            _buildStatusCard(status),
            const SizedBox(height: 14),

            // Karyawan Info
            _buildEmployeeCard(d),
            const SizedBox(height: 14),

            // Jadwal Roster & Dinas
            _buildRosterScheduleCard(d),
            const SizedBox(height: 18),

            // 7 Pertanyaan Header
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Hasil Jawaban Form Re-Induksi',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Answers
            ...List.generate(7, (idx) => _buildAnswerTile(idx, d)),

            const SizedBox(height: 14),

            // Pernyataan Karyawan
            _buildSignatureCard(d),

            if (d['supervisorNotes'] != null && d['supervisorNotes'].toString().isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Catatan Pengawas:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      d['supervisorNotes'].toString(),
                      style: const TextStyle(fontSize: 13, color: Color(0xFF78350F)),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Supervisor Actions Footer (if can approve)
            if (_canApprove && status == 'PENDING_APPROVAL') ...[
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _isActioning ? null : () => _processApproval(false),
                        icon: const Icon(Icons.close_rounded, color: Color(0xFFDC2626)),
                        label: const Text(
                          'Tolak',
                          style: TextStyle(
                            color: Color(0xFFDC2626),
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isActioning ? null : () => _processApproval(true),
                        icon: _isActioning
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.check_circle_rounded, color: Colors.white),
                        label: Text(
                          _isActioning ? 'Memproses...' : 'Setujui Re-Induksi',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(String status) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (status) {
      case 'APPROVED':
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF059669);
        label = 'DISETUJUI (RE-INDUKSI RESMI AKTIF)';
        icon = Icons.verified_rounded;
        break;
      case 'REJECTED':
        bg = const Color(0xFFFEF2F2);
        fg = const Color(0xFFDC2626);
        label = 'DITOLAK OLEH PENGAWAS';
        icon = Icons.cancel_rounded;
        break;
      default:
        bg = const Color(0xFFFFFBEB);
        fg = const Color(0xFFD97706);
        label = 'MENUNGGU PERSETUJUAN PENGAWAS';
        icon = Icons.hourglass_top_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: fg,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeCard(Map<String, dynamic> d) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFF0F766E),
                radius: 20,
                child: Icon(Icons.person, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d['nama'] ?? '-',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                    ),
                    Text(
                      'NIK: ${d['nik'] ?? "-"} • ${d['perusahaan'] ?? "-"}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          _buildInfoRow('Departemen', d['departemen'] ?? '-'),
          _buildInfoRow('Jabatan', d['jabatan'] ?? '-'),
          _buildInfoRow('Pengawas Ditag', d['namaPengawas'] ?? '-'),
        ],
      ),
    );
  }

  Widget _buildRosterScheduleCard(Map<String, dynamic> d) {
    final awalDinas = _formatDateStr(d['awalDinas']);
    final akhirDinas = _formatDateStr(d['akhirDinas']);
    final awalCuti = _formatDateStr(d['awalCuti']);
    final akhirCuti = _formatDateStr(d['akhirCuti']);

    int daysDinas = 0;
    int daysCuti = 0;

    final dtAwalDinas = DateTime.tryParse(d['awalDinas']?.toString() ?? '');
    final dtAkhirDinas = DateTime.tryParse(d['akhirDinas']?.toString() ?? '');
    final dtAwalCuti = DateTime.tryParse(d['awalCuti']?.toString() ?? '');
    final dtAkhirCuti = DateTime.tryParse(d['akhirCuti']?.toString() ?? '');

    if (dtAwalDinas != null && dtAkhirDinas != null) {
      daysDinas = dtAkhirDinas.difference(dtAwalDinas).inDays + 1;
    }
    if (dtAwalCuti != null && dtAkhirCuti != null) {
      daysCuti = dtAkhirCuti.difference(dtAwalCuti).inDays + 1;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month_rounded, color: Color(0xFF0F766E), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Jadwal Roster & Dinas Karyawan',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFCCFBF1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  d['tipeRoster'] ?? 'REGULER',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0F766E)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildScheduleRow(
            'Periode Dinas (Onsite)',
            '$awalDinas s/d $akhirDinas ($daysDinas Hari)',
            const Color(0xFF0F766E),
          ),
          const SizedBox(height: 6),
          _buildScheduleRow(
            'Periode Cuti (Offsite)',
            '$awalCuti s/d $akhirCuti ($daysCuti Hari)',
            const Color(0xFFD97706),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleRow(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _buildAnswerTile(int index, Map<String, dynamic> d) {
    final qKey = 'q${index + 1}Answer';
    final nKey = 'q${index + 1}Notes';

    final answer = (d[qKey] ?? 'Ya').toString();
    final notes = d[nKey]?.toString();

    final isYa = answer.toLowerCase() == 'ya';

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFF0F766E),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _questions[index],
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B), height: 1.35),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isYa ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isYa ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isYa ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      size: 14,
                      color: isYa ? const Color(0xFF059669) : const Color(0xFFDC2626),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      answer,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: isYa ? const Color(0xFF059669) : const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Penjelasan: $notes',
                style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSignatureCard(Map<String, dynamic> d) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF99F6E4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded, color: Color(0xFF0F766E), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dikonfirmasi & Ditandatangani Karyawan',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F766E)),
                ),
                Text(
                  'Oleh ${d['nama'] ?? "-"} • ${_formatDateStr(d['createdAt'])}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF115E59)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
        ],
      ),
    );
  }

  String _formatDateStr(dynamic val) {
    if (val == null) return '-';
    final s = val.toString();
    final dt = DateTime.tryParse(s);
    if (dt == null) return s;
    return _displayFormat.format(dt);
  }
}


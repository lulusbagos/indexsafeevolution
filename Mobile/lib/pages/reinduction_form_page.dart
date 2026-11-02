import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/profile_model.dart';
import '../services/api.dart';
import '../services/notification.dart';
import '../widgets/sap_form_widgets.dart';

class ReinductionFormPage extends StatefulWidget {
  final Map<String, dynamic> rosterData;
  final ProfileModel? profile;

  const ReinductionFormPage({
    super.key,
    required this.rosterData,
    this.profile,
  });

  @override
  State<ReinductionFormPage> createState() => _ReinductionFormPageState();
}

class _ReinductionFormPageState extends State<ReinductionFormPage> {
  final ApiService _api = ApiService();
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  final DateFormat _displayFormat = DateFormat('dd MMM yyyy');

  bool _isSubmitting = false;
  bool _isExempt = false;

  // Supervisor (if not exempt)
  String? _selectedSupervisorNik;
  String? _selectedSupervisorNama;
  String? _selectedSupervisorDept;
  String? _selectedSupervisorCompany;

  // Dates
  late DateTime _tanggalOffsite;
  late DateTime _tanggalOnsite;

  // 7 Question states: 'Ya' or 'Tidak', and optional notes
  final List<String> _answers = List.filled(7, 'Ya');
  final List<TextEditingController> _noteControllers =
      List.generate(7, (_) => TextEditingController());

  bool _agreementChecked = true;

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
    _checkExemption();
    _initDates();
  }

  void _checkExemption() {
    final jabatan = widget.profile?.jabatan ?? '';
    final posisi = widget.profile?.posisi ?? '';
    final text = '$jabatan $posisi'.trim().toLowerCase();

    final exemptKeywords = [
      'manager',
      'direktur',
      'director',
      'kepala teknik tambang',
      'ktt',
      'depthead',
      'dept head',
      'department head',
      'pjo',
      'project manager',
      'project mmanager',
      'pm',
    ];

    setState(() {
      _isExempt = exemptKeywords.any((k) => text.contains(k));
    });
  }

  void _initDates() {
    final awalCutiStr = widget.rosterData['awalCuti']?.toString() ?? '';
    final awalDinasStr = widget.rosterData['awalDinas']?.toString() ?? '';

    _tanggalOffsite =
        DateTime.tryParse(awalCutiStr) ?? DateTime.now().subtract(const Duration(days: 14));
    _tanggalOnsite = DateTime.tryParse(awalDinasStr) ?? DateTime.now();
  }

  @override
  void dispose() {
    for (final c in _noteControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickSupervisor() async {
    HapticFeedback.lightImpact();
    final picked = await SapEmployeePickerModal.show(
      context,
      title: 'Pilih Pengawas / Atasan Lapangan',
    );
    if (picked != null) {
      setState(() {
        _selectedSupervisorNik = picked.nik;
        _selectedSupervisorNama = picked.nama;
        _selectedSupervisorDept = picked.departemen;
        _selectedSupervisorCompany = picked.perusahaan;
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_isExempt && (_selectedSupervisorNik == null || _selectedSupervisorNik!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih Pengawas terlebih dahulu untuk persetujuan re-induksi.'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!_agreementChecked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap centang konfirmasi pernyataan sebelum mengirim form.'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final payload = <String, dynamic>{
      'id': widget.rosterData['id'],
      'tipeRoster': widget.rosterData['tipeRoster'] ?? 'REGULER',
      'keterangan': widget.rosterData['keterangan'],
      'awalDinas': widget.rosterData['awalDinas'],
      'akhirDinas': widget.rosterData['akhirDinas'],
      'awalCuti': widget.rosterData['awalCuti'],
      'akhirCuti': widget.rosterData['akhirCuti'],

      // Form Re-Induction
      'nama': widget.profile?.namaLengkap ?? '',
      'perusahaan': widget.profile?.company ?? '',
      'jabatan': widget.profile?.jabatan ?? '',
      'departemen': widget.profile?.depart ?? '',
      'nikPengawas': _selectedSupervisorNik,
      'namaPengawas': _selectedSupervisorNama,
      'tanggalMulaiOffsite': _dateFormat.format(_tanggalOffsite),
      'tanggalMulaiOnsite': _dateFormat.format(_tanggalOnsite),

      // 7 Questions
      'q1Answer': _answers[0],
      'q1Notes': _noteControllers[0].text.trim(),
      'q2Answer': _answers[1],
      'q2Notes': _noteControllers[1].text.trim(),
      'q3Answer': _answers[2],
      'q3Notes': _noteControllers[2].text.trim(),
      'q4Answer': _answers[3],
      'q4Notes': _noteControllers[3].text.trim(),
      'q5Answer': _answers[4],
      'q5Notes': _noteControllers[4].text.trim(),
      'q6Answer': _answers[5],
      'q6Notes': _noteControllers[5].text.trim(),
      'q7Answer': _answers[6],
      'q7Notes': _noteControllers[6].text.trim(),

      'signatureKaryawan': 'CONFIRMED_${widget.profile?.namaLengkap}_${DateTime.now().toIso8601String()}',
      'isExempt': _isExempt,
    };

    final res = await _api.saveRosterWithReinduksi(payload);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    res.fold(
      (err) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err['message'] ?? 'Gagal menyimpan Form Re-Induksi'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      (data) {
        NotificationService.display(
          title: _isExempt
              ? 'Roster & Re-Induksi Disetujui'
              : 'Form Re-Induksi Dikirim',
          body: _isExempt
              ? 'Pengaturan roster dan re-induksi aktif (Disetujui otomatis).'
              : 'Form Re-Induksi telah terkirim ke Pengawas ($_selectedSupervisorNama) untuk diverifikasi.',
          payload: '/roster',
          notifType: _isExempt ? 'roster_reinduksi_approved' : 'roster_reinduksi_pending',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Form Re-Induksi berhasil disimpan!'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.of(context).pop(true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'FORM RE-INDUCTION',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.8),
        ),
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Info Card (Form Header)
            _buildHeaderCard(),
            const SizedBox(height: 16),

            // Supervisor Selection Card
            _buildSupervisorCard(),
            const SizedBox(height: 16),

            // Dates & Roster summary card
            _buildScheduleCard(),
            const SizedBox(height: 20),

            // 7 Questions Header
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
                  'Daftar Pertanyaan Re-Induksi',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Questions list
            ...List.generate(7, (idx) => _buildQuestionCard(idx)),

            const SizedBox(height: 16),

            // Confirmation / Signature Card
            _buildAgreementCard(),

            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitForm,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Icon(
                        _isExempt ? Icons.check_circle_outline_rounded : Icons.send_rounded,
                        color: Colors.white,
                      ),
                label: Text(
                  _isSubmitting
                      ? 'Menyimpan Form...'
                      : (_isExempt
                          ? 'Simpan Roster & Form Re-Induksi'
                          : 'Kirim Form ke Pengawas & Simpan Roster'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  disabledBackgroundColor: const Color(0xFF94A3B8),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
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
                  color: const Color(0xFFCCFBF1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.assignment_ind_rounded, color: Color(0xFF0F766E), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.profile?.namaLengkap ?? '-',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'NIK: ${widget.profile?.noNik ?? "-"} • ${widget.profile?.company ?? "-"}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          _buildInfoRow('Departemen', widget.profile?.depart ?? '-'),
          _buildInfoRow('Jabatan', widget.profile?.jabatan ?? '-'),
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

  Widget _buildSupervisorCard() {
    if (_isExempt) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFA7F3D0)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.verified_user_rounded, color: Color(0xFF059669), size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Jabatan Bebas Approval Pengawas',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF065F46),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Berdasarkan jabatan Anda (${widget.profile?.jabatan ?? "Pimpinan"}), Form Re-Induksi langsung disetujui otomatis tanpa memerlukan input nama pengawas.',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF047857), height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _selectedSupervisorNik != null ? const Color(0xFF0F766E) : const Color(0xFFE2E8F0),
          width: _selectedSupervisorNik != null ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
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
              const Text(
                'Nama Pengawas / Atasan',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Wajib Dipilih',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_selectedSupervisorNik != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF99F6E4)),
              ),
              child: Row(
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
                          _selectedSupervisorNama ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                        Text(
                          'NIK: ${_selectedSupervisorNik ?? "-"} • ${_selectedSupervisorDept ?? "-"}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                        ),
                        if (_selectedSupervisorCompany != null)
                          Text(
                            _selectedSupervisorCompany!,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _pickSupervisor,
                    icon: const Icon(Icons.change_circle_rounded, color: Color(0xFF0F766E)),
                    tooltip: 'Ganti Pengawas',
                  ),
                ],
              ),
            ),
          ] else ...[
            InkWell(
              onTap: _pickSupervisor,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_search_rounded, color: Color(0xFF0F766E), size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Pilih Pengawas dari Database (Offline/Online)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScheduleCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.date_range_rounded, color: Color(0xFF0F766E), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Jadwal Roster & Tanggal Re-Induksi',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDateTile(
                  label: 'Mulai Offsite (Cuti)',
                  date: _tanggalOffsite,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _tanggalOffsite,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) setState(() => _tanggalOffsite = picked);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDateTile(
                  label: 'Mulai Onsite (Dinas)',
                  date: _tanggalOnsite,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _tanggalOnsite,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) setState(() => _tanggalOnsite = picked);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateTile({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  _displayFormat.format(date),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                ),
                const Spacer(),
                const Icon(Icons.edit_calendar_rounded, size: 16, color: Color(0xFF0F766E)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(int index) {
    final questionText = _questions[index];
    final answer = _answers[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFF0F766E),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  questionText,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Radio Selection Ya / Tidak
          Row(
            children: [
              Expanded(
                child: _buildChoiceChip(
                  label: 'Ya',
                  isSelected: answer == 'Ya',
                  selectedColor: const Color(0xFF10B981),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _answers[index] = 'Ya');
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildChoiceChip(
                  label: 'Tidak',
                  isSelected: answer == 'Tidak',
                  selectedColor: const Color(0xFFDC2626),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _answers[index] = 'Tidak');
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Penjelasan Input
          TextField(
            controller: _noteControllers[index],
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Penjelasan (opsional jika Ya, wajib jika Tidak)',
              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.5),
              ),
            ),
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool isSelected,
    required Color selectedColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? selectedColor : const Color(0xFFCBD5E1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              size: 16,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgreementCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF99F6E4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: _agreementChecked,
            activeColor: const Color(0xFF0F766E),
            onChanged: (v) => setState(() => _agreementChecked = v ?? false),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pernyataan & Tanda Tangan Digital Karyawan',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F766E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Saya menyatakan bahwa seluruh penjelasan di atas telah saya pahami dan sesuai dengan kondisi sebenarnya pada tanggal ${_displayFormat.format(DateTime.now())}.',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF0F766E), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

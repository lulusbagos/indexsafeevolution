import '../utils/app_date_time_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/profile_model.dart';
import '../services/api.dart';
import '../services/notification.dart';
import '../services/preference.dart';
import '../widgets/sap_form_widgets.dart';

class ReinductionQuestionItem {
  final int number;
  final String title;
  final String questionText;
  final String guidance;
  final IconData icon;

  const ReinductionQuestionItem({
    required this.number,
    required this.title,
    required this.questionText,
    required this.guidance,
    required this.icon,
  });
}

class PermitSimperInfo {
  final bool isAvailable;
  final String title;
  final String nomor;
  final String formattedDate;
  final int? daysLeft;
  final bool isExpired;
  final bool isExpiringSoon;
  final bool isCritical;
  final String statusBadge;
  final Color statusColor;
  final Color bgColor;
  final Color borderColor;
  final String message;

  const PermitSimperInfo({
    required this.isAvailable,
    required this.title,
    required this.nomor,
    required this.formattedDate,
    required this.daysLeft,
    required this.isExpired,
    required this.isExpiringSoon,
    required this.isCritical,
    required this.statusBadge,
    required this.statusColor,
    required this.bgColor,
    required this.borderColor,
    required this.message,
  });
}

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

  ProfileModel? _profile;
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

  // 7 Questions: Initial state is NULL (user must click, no default 'Ya')
  final List<String?> _answers = List.filled(7, null);
  final List<TextEditingController> _noteControllers =
      List.generate(7, (_) => TextEditingController());
  final List<bool> _cardErrors = List.filled(7, false);
  final List<String?> _cardErrorMessages = List.filled(7, null);
  final List<GlobalKey> _questionKeys = List.generate(7, (_) => GlobalKey());

  bool _agreementChecked = false;

  static const List<ReinductionQuestionItem> _questionsList = [
    ReinductionQuestionItem(
      number: 1,
      title: 'Masa Berlaku Mine Permit & SIMPER',
      questionText:
          'Apakah Mine Permit dan SIMPER (jika memiliki wewenang mengemudi/mengoperasikan unit) Anda masih dalam masa berlaku aktif?',
      guidance:
          'Periksa masa aktif fisik kartu. Jika masa berlaku telah kedaluwarsa atau segera habis, wajib dilaporkan ke Pengawas/HSE.',
      icon: Icons.badge_outlined,
    ),
    ReinductionQuestionItem(
      number: 2,
      title: 'Kelaikan Alat Pelindung Diri (APD)',
      questionText:
          'Apakah seluruh APD standar K3LH (Helm Safety, Kacamata, Rompi Reflektif, Sepatu Safety, dll.) dalam kondisi lengkap dan layak pakai?',
      guidance:
          'Pastikan tidak ada retak pada helm, reflektor rompi berfungsi, dan sol sepatu safety tidak rusak atau licin.',
      icon: Icons.health_and_safety_outlined,
    ),
    ReinductionQuestionItem(
      number: 3,
      title: 'Penyegaran Materi K3LH & Insiden Terkini',
      questionText:
          'Apakah Anda telah memahami materi Safety Talk terkini, perubahan peraturan/rambu di area kerja, serta evaluasi insiden terakhir?',
      guidance:
          'Pahami akar penyebab insiden tambang terakhir dan ikuti rambu atau perubahan batas kecepatan di jalur hauling/pit.',
      icon: Icons.campaign_outlined,
    ),
    ReinductionQuestionItem(
      number: 4,
      title: 'Penerapan & Kepatuhan Golden Rules',
      questionText:
          'Apakah Anda telah mengingat kembali dan berkomitmen mematuhi seluruh klausul Golden Rules keselamatan kerja tanpa toleransi pelanggaran?',
      guidance:
          'Golden Rules adalah komitmen harga mati demi keselamatan diri dan rekan kerja di seluruh area tambang.',
      icon: Icons.gavel_outlined,
    ),
    ReinductionQuestionItem(
      number: 5,
      title: 'Protokol Komunikasi Radio Dua Arah',
      questionText:
          'Apakah Anda memahami tata cara komunikasi radio yang baik, termasuk disiplin kanal, panggilan Urgent, dan Emergency?',
      guidance:
          'Gunakan panggilan resmi di frekuensi kerja yang tepat. Segera kosongkan jalur komunikasi jika terdengar panggilan Emergency.',
      icon: Icons.radio_outlined,
    ),
    ReinductionQuestionItem(
      number: 6,
      title: 'Evaluasi & Temuan Inspeksi HSE',
      questionText:
          'Apakah Anda telah dijelaskan terkait temuan inspeksi HSE terakhir di lingkungan kerja, baik yang sudah diselesaikan maupun yang sedang ditindaklanjuti?',
      guidance:
          'Tinjau potensi bahaya di tempat kerja sebelum memulai shift dan pastikan pengendalian bahaya sudah diterapkan.',
      icon: Icons.fact_check_outlined,
    ),
    ReinductionQuestionItem(
      number: 7,
      title: 'Kesiapan Kerja (Fit to Work) & K3LH Terlampir',
      questionText:
          'Apakah Anda menyatakan dalam kondisi sehat fisik dan mental, cukup istirahat, bebas dari pengaruh obat terlarang/alkohol, serta siap bekerja aman?',
      guidance:
          'Kondisi fit to work adalah syarat mutlak. Jika Anda mengalami kelelahan ekstrem (fatigue) atau sakit, wajib melapor ke pengawas.',
      icon: Icons.favorite_outline_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _profile = widget.profile ?? PreferenceService.getProfile();
    _checkExemption();
    _initDates();
    _fetchFreshProfile();
  }

  Future<void> _fetchFreshProfile() async {
    try {
      final res = await _api.getProfile();
      res.fold((_) {}, (p) {
        if (mounted) {
          setState(() {
            _profile = p;
            _checkExemption();
          });
        }
      });
    } catch (_) {}
  }

  void _checkExemption() {
    final jabatan = _profile?.jabatan ?? '';
    final posisi = _profile?.posisi ?? '';
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

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.trim().isEmpty || raw.trim() == '-') return null;
    final clean = raw.trim();
    final parsed = DateTime.tryParse(clean);
    if (parsed != null) return parsed;
    final parts = clean.split(RegExp(r'[-/]'));
    if (parts.length == 3) {
      if (parts[0].length == 4) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final d = int.tryParse(parts[2]);
        if (y != null && m != null && d != null) return DateTime(y, m, d);
      } else if (parts[2].length == 4) {
        final d = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final y = int.tryParse(parts[2]);
        if (y != null && m != null && d != null) return DateTime(y, m, d);
      }
    }
    return null;
  }

  PermitSimperInfo _getPermitInfo() {
    final rawDate = _profile?.masaAktifPermit?.trim() ?? '';
    final nomor = _profile?.permitNomor?.trim() ?? '-';
    final hasPermit = _profile?.hasPermit ?? (nomor.isNotEmpty && nomor != '-');
    final parsedDate = _parseDate(rawDate);

    if (!hasPermit || (nomor == '-' && rawDate.isEmpty)) {
      return const PermitSimperInfo(
        isAvailable: false,
        title: 'Mine Permit',
        nomor: '-',
        formattedDate: 'Belum Terdaftar',
        daysLeft: null,
        isExpired: false,
        isExpiringSoon: false,
        isCritical: false,
        statusBadge: 'Belum Ada',
        statusColor: Color(0xFF64748B),
        bgColor: Color(0xFFF1F5F9),
        borderColor: Color(0xFFCBD5E1),
        message: 'Data Mine Permit belum tercatat di database BIMA.',
      );
    }

    if (parsedDate == null) {
      return PermitSimperInfo(
        isAvailable: true,
        title: 'Mine Permit',
        nomor: nomor,
        formattedDate: rawDate.isNotEmpty ? rawDate : 'Tanggal Tidak Diketahui',
        daysLeft: null,
        isExpired: false,
        isExpiringSoon: false,
        isCritical: false,
        statusBadge: 'Tercatat',
        statusColor: const Color(0xFF0F766E),
        bgColor: const Color(0xFFF0FDFA),
        borderColor: const Color(0xFF99F6E4),
        message: 'Mine Permit terdaftar dengan nomor $nomor.',
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiryDay = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
    final diff = expiryDay.difference(today).inDays;
    final dateStr = _displayFormat.format(parsedDate);

    if (diff < 0) {
      return PermitSimperInfo(
        isAvailable: true,
        title: 'Mine Permit',
        nomor: nomor,
        formattedDate: dateStr,
        daysLeft: diff,
        isExpired: true,
        isExpiringSoon: true,
        isCritical: true,
        statusBadge: 'KEDALUWARSA (${diff.abs()} Hari Lalu)',
        statusColor: const Color(0xFFDC2626),
        bgColor: const Color(0xFFFEF2F2),
        borderColor: const Color(0xFFFECACA),
        message:
            'Mine Permit telah kedaluwarsa sejak $dateStr! Anda dilarang memasuki area operasional tambang sebelum melakukan perpanjangan permit di OHS/HSE.',
      );
    } else if (diff <= 30) {
      return PermitSimperInfo(
        isAvailable: true,
        title: 'Mine Permit',
        nomor: nomor,
        formattedDate: dateStr,
        daysLeft: diff,
        isExpired: false,
        isExpiringSoon: true,
        isCritical: true,
        statusBadge: 'SEGERA HABIS (Sisa $diff Hari)',
        statusColor: const Color(0xFFEA580C),
        bgColor: const Color(0xFFFFF7ED),
        borderColor: const Color(0xFFFED7AA),
        message:
            'Mine Permit akan segera habis dalam $diff hari (berlaku s/d $dateStr). Segera lakukan pengajuan perpanjangan ke pengawas & Departemen HSE.',
      );
    } else if (diff <= 60) {
      return PermitSimperInfo(
        isAvailable: true,
        title: 'Mine Permit',
        nomor: nomor,
        formattedDate: dateStr,
        daysLeft: diff,
        isExpired: false,
        isExpiringSoon: true,
        isCritical: false,
        statusBadge: 'Mendekati Habis (Sisa $diff Hari)',
        statusColor: const Color(0xFFD97706),
        bgColor: const Color(0xFFFFFBEB),
        borderColor: const Color(0xFFFDE68A),
        message:
            'Mine Permit berlaku hingga $dateStr (sisa $diff hari). Persiapkan dokumen perpanjangan.',
      );
    } else {
      return PermitSimperInfo(
        isAvailable: true,
        title: 'Mine Permit',
        nomor: nomor,
        formattedDate: dateStr,
        daysLeft: diff,
        isExpired: false,
        isExpiringSoon: false,
        isCritical: false,
        statusBadge: 'Aktif (Sisa $diff Hari)',
        statusColor: const Color(0xFF059669),
        bgColor: const Color(0xFFECFDF5),
        borderColor: const Color(0xFFA7F3D0),
        message: 'Mine Permit dalam masa aktif resmi hingga $dateStr.',
      );
    }
  }

  PermitSimperInfo _getSimperInfo() {
    final rawDate = _profile?.simperExpiredDate?.trim() ??
        _profile?.simperMasaBerlaku?.trim() ??
        '';
    final nomor = _profile?.simperNomor?.trim() ?? '-';
    final hasSimper = _profile?.hasSimper ?? (nomor.isNotEmpty && nomor != '-');
    final parsedDate = _parseDate(rawDate);

    if (!hasSimper || (nomor == '-' && rawDate.isEmpty)) {
      return const PermitSimperInfo(
        isAvailable: false,
        title: 'SIMPER / KIMPER',
        nomor: 'Non-Driver / Operator',
        formattedDate: 'Tidak Ada SIMPER',
        daysLeft: null,
        isExpired: false,
        isExpiringSoon: false,
        isCritical: false,
        statusBadge: 'Tidak Terdaftar',
        statusColor: Color(0xFF64748B),
        bgColor: Color(0xFFF8FAFC),
        borderColor: Color(0xFFE2E8F0),
        message: 'Karyawan tidak memiliki otorisasi mengemudi/mengoperasikan unit tambang.',
      );
    }

    if (parsedDate == null) {
      return PermitSimperInfo(
        isAvailable: true,
        title: 'SIMPER / KIMPER',
        nomor: nomor,
        formattedDate: rawDate.isNotEmpty ? rawDate : 'Tanggal Tidak Diketahui',
        daysLeft: null,
        isExpired: false,
        isExpiringSoon: false,
        isCritical: false,
        statusBadge: 'Tercatat',
        statusColor: const Color(0xFF0F766E),
        bgColor: const Color(0xFFF0FDFA),
        borderColor: const Color(0xFF99F6E4),
        message: 'SIMPER terdaftar dengan nomor $nomor.',
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiryDay = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
    final diff = expiryDay.difference(today).inDays;
    final dateStr = _displayFormat.format(parsedDate);

    if (diff < 0) {
      return PermitSimperInfo(
        isAvailable: true,
        title: 'SIMPER / KIMPER',
        nomor: nomor,
        formattedDate: dateStr,
        daysLeft: diff,
        isExpired: true,
        isExpiringSoon: true,
        isCritical: true,
        statusBadge: 'KEDALUWARSA (${diff.abs()} Hari Lalu)',
        statusColor: const Color(0xFFDC2626),
        bgColor: const Color(0xFFFEF2F2),
        borderColor: const Color(0xFFFECACA),
        message:
            'SIMPER Anda telah habis masa berlakunya sejak $dateStr! Dilarang keras mengoperasikan unit atau kendaraan di area tambang.',
      );
    } else if (diff <= 30) {
      return PermitSimperInfo(
        isAvailable: true,
        title: 'SIMPER / KIMPER',
        nomor: nomor,
        formattedDate: dateStr,
        daysLeft: diff,
        isExpired: false,
        isExpiringSoon: true,
        isCritical: true,
        statusBadge: 'SEGERA HABIS (Sisa $diff Hari)',
        statusColor: const Color(0xFFEA580C),
        bgColor: const Color(0xFFFFF7ED),
        borderColor: const Color(0xFFFED7AA),
        message:
            'SIMPER akan habis dalam $diff hari (s/d $dateStr). Segera ikuti re-test atau perpanjangan SIMPER di Dept HSE.',
      );
    } else if (diff <= 60) {
      return PermitSimperInfo(
        isAvailable: true,
        title: 'SIMPER / KIMPER',
        nomor: nomor,
        formattedDate: dateStr,
        daysLeft: diff,
        isExpired: false,
        isExpiringSoon: true,
        isCritical: false,
        statusBadge: 'Mendekati Habis (Sisa $diff Hari)',
        statusColor: const Color(0xFFD97706),
        bgColor: const Color(0xFFFFFBEB),
        borderColor: const Color(0xFFFDE68A),
        message:
            'Masa aktif SIMPER tersisa $diff hari (berlaku s/d $dateStr).',
      );
    } else {
      return PermitSimperInfo(
        isAvailable: true,
        title: 'SIMPER / KIMPER',
        nomor: nomor,
        formattedDate: dateStr,
        daysLeft: diff,
        isExpired: false,
        isExpiringSoon: false,
        isCritical: false,
        statusBadge: 'Aktif (Sisa $diff Hari)',
        statusColor: const Color(0xFF059669),
        bgColor: const Color(0xFFECFDF5),
        borderColor: const Color(0xFFA7F3D0),
        message: 'SIMPER dalam masa aktif resmi hingga $dateStr.',
      );
    }
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
    HapticFeedback.mediumImpact();

    // 1. Check Supervisor
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

    // 2. Strict Validation: Check every question answer & explanation
    for (int i = 0; i < 7; i++) {
      final answer = _answers[i];
      final notes = _noteControllers[i].text.trim();

      if (answer == null) {
        setState(() {
          _cardErrors[i] = true;
          _cardErrorMessages[i] = 'Wajib memilih jawaban (Ya atau Tidak).';
        });
        _scrollToQuestion(i);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Pertanyaan #${i + 1} (${_questionsList[i].title}) belum dijawab! Pilih "Ya" atau "Tidak".',
            ),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (notes.isEmpty) {
        setState(() {
          _cardErrors[i] = true;
          _cardErrorMessages[i] = 'Wajib mengisi penjelasan/catatan kondisi riil sebelum kirim.';
        });
        _scrollToQuestion(i);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Pertanyaan #${i + 1} (${_questionsList[i].title}): Penjelasan wajib diisi.',
            ),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    // 3. Agreement Confirmation
    if (!_agreementChecked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap centang konfirmasi pernyataan digital sebelum mengirim formulir.'),
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
      'nama': _profile?.namaLengkap ?? '',
      'perusahaan': _profile?.company ?? '',
      'jabatan': _profile?.jabatan ?? '',
      'departemen': _profile?.depart ?? '',
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

      'signatureKaryawan':
          'CONFIRMED_${_profile?.namaLengkap}_${DateTime.now().toIso8601String()}',
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
              : 'Form Re-Induksi Berhasil Dikirim',
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

  void _scrollToQuestion(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final keyContext = _questionKeys[index].currentContext;
      if (keyContext != null) {
        Scrollable.ensureVisible(
          keyContext,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          alignment: 0.15,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final permitInfo = _getPermitInfo();
    final simperInfo = _getSimperInfo();
    final hasWarning = permitInfo.isExpiringSoon || simperInfo.isExpiringSoon;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'FORMULIR RE-INDUKSI K3LH',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.8),
        ),
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Employee Profile Header
            _buildHeaderCard(),
            const SizedBox(height: 14),

            // 2. Permit & SIMPER Alert Banner (if expiring soon or expired)
            if (hasWarning) ...[
              _buildPermitSimperAlertBanner(permitInfo, simperInfo),
              const SizedBox(height: 14),
            ],

            // 3. Status Permit & SIMPER Card
            _buildPermitSimperOverviewCard(permitInfo, simperInfo),
            const SizedBox(height: 14),

            // 4. Supervisor Picker Card
            _buildSupervisorCard(),
            const SizedBox(height: 14),

            // 5. Schedule & Roster Dates
            _buildScheduleCard(),
            const SizedBox(height: 20),

            // 6. 7 Questions Section Header
            _buildQuestionsHeader(),
            const SizedBox(height: 12),

            // 7. Question Cards
            ...List.generate(
              _questionsList.length,
              (idx) => _buildProfessionalQuestionCard(
                idx,
                permitInfo: idx == 0 ? permitInfo : null,
                simperInfo: idx == 0 ? simperInfo : null,
              ),
            ),

            const SizedBox(height: 16),

            // 8. Digital Agreement Card
            _buildAgreementCard(),

            const SizedBox(height: 24),

            // 9. Submit Button
            _buildSubmitButton(),
            const SizedBox(height: 36),
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
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFCCFBF1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF99F6E4)),
                ),
                child: const Icon(Icons.shield_rounded, color: Color(0xFF0F766E), size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _profile?.namaLengkap ?? 'Karyawan',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'NIK: ${_profile?.noNik ?? "-"} • ${_profile?.company ?? "-"}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 22, color: Color(0xFFF1F5F9)),
          _buildInfoRow('Departemen', _profile?.depart ?? '-'),
          _buildInfoRow('Jabatan', _profile?.jabatan ?? '-'),
          _buildInfoRow('Status Kerja', 'Pasca Offsite / Siap Onsite'),
        ],
      ),
    );
  }

  Widget _buildPermitSimperAlertBanner(
    PermitSimperInfo permitInfo,
    PermitSimperInfo simperInfo,
  ) {
    final bool isCritical = permitInfo.isCritical || simperInfo.isCritical;
    final alertColor = isCritical ? const Color(0xFFDC2626) : const Color(0xFFD97706);
    final alertBg = isCritical ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB);
    final alertBorder = isCritical ? const Color(0xFFFECACA) : const Color(0xFFFDE68A);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: alertBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: alertBorder, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCritical ? Icons.warning_rounded : Icons.info_outline_rounded,
            color: alertColor,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCritical ? 'PERINGATAN MASA BERLAKU PERMIT / SIMPER' : 'PEMBERITAHUAN MASA BERLAKU',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: alertColor,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                if (permitInfo.isExpiringSoon)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '• Permit: ${permitInfo.statusBadge} (Berlaku s/d ${permitInfo.formattedDate})',
                      style: TextStyle(fontSize: 12, color: alertColor, fontWeight: FontWeight.w600),
                    ),
                  ),
                if (simperInfo.isExpiringSoon)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '• SIMPER: ${simperInfo.statusBadge} (Berlaku s/d ${simperInfo.formattedDate})',
                      style: TextStyle(fontSize: 12, color: alertColor, fontWeight: FontWeight.w600),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  'Harap segera laporkan ke Pengawas atau bagian OHS/HSE untuk penjadwalan perpanjangan.',
                  style: TextStyle(fontSize: 11, color: alertColor.withValues(alpha: 0.9), height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermitSimperOverviewCard(
    PermitSimperInfo permitInfo,
    PermitSimperInfo simperInfo,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.card_membership_rounded, color: Color(0xFF0F766E), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Status Validitas Mine Permit & SIMPER',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF99F6E4)),
                ),
                child: const Text(
                  'Database BIMA',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F766E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Sub-cards for Permit & SIMPER
          Row(
            children: [
              Expanded(child: _buildDocStatusTile(permitInfo, icon: Icons.badge_outlined)),
              const SizedBox(width: 10),
              Expanded(child: _buildDocStatusTile(simperInfo, icon: Icons.drive_eta_rounded)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocStatusTile(PermitSimperInfo info, {required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: info.bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: info.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: info.statusColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  info.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: info.statusColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            info.nomor,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            'Exp: ${info.formattedDate}',
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: info.borderColor),
            ),
            child: Text(
              info.statusBadge,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: info.statusColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
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
                    'Berdasarkan jabatan Anda (${_profile?.jabatan ?? "Pimpinan"}), Form Re-Induksi langsung disetujui otomatis tanpa memerlukan input nama pengawas.',
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
                'Pengawas / Atasan Lapangan',
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
                  'Wajib Dipilih *',
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
                  border: Border.all(color: const Color(0xFFCBD5E1)),
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
          const Row(
            children: [
              Icon(Icons.date_range_rounded, color: Color(0xFF0F766E), size: 20),
              SizedBox(width: 8),
              Text(
                'Periode Offsite & Tanggal Re-Induksi Onsite',
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
                      cancelText: 'BATAL',
                      confirmText: 'PILIH',
                      builder: (ctx, child) => Theme(
                        data: AppDateTimePicker.getDatePickerTheme(ctx),
                        child: child ?? const SizedBox(),
                      ),
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
                      cancelText: 'BATAL',
                      confirmText: 'PILIH',
                      builder: (ctx, child) => Theme(
                        data: AppDateTimePicker.getDatePickerTheme(ctx),
                        child: child ?? const SizedBox(),
                      ),
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

  Widget _buildQuestionsHeader() {
    final answeredCount = _answers.where((a) => a != null).length;
    final notesFilledCount = _noteControllers.where((c) => c.text.trim().isNotEmpty).length;

    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            color: const Color(0xFF0F766E),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '7 Komitmen & Pertanyaan Re-Induksi',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                'Wajib dijawab dan diisi penjelasan untuk setiap butir pertanyaan.',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: answeredCount == 7 && notesFilledCount == 7
                ? const Color(0xFFECFDF5)
                : const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: answeredCount == 7 && notesFilledCount == 7
                  ? const Color(0xFFA7F3D0)
                  : const Color(0xFFFDE68A),
            ),
          ),
          child: Text(
            '$answeredCount/7 Terjawab',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: answeredCount == 7 && notesFilledCount == 7
                  ? const Color(0xFF059669)
                  : const Color(0xFFD97706),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfessionalQuestionCard(
    int index, {
    PermitSimperInfo? permitInfo,
    PermitSimperInfo? simperInfo,
  }) {
    final item = _questionsList[index];
    final answer = _answers[index];
    final hasError = _cardErrors[index];
    final errorMessage = _cardErrorMessages[index];

    return Container(
      key: _questionKeys[index],
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasError
              ? const Color(0xFFEF4444)
              : answer != null
                  ? const Color(0xFF99F6E4)
                  : const Color(0xFFE2E8F0),
          width: hasError ? 1.8 : (answer != null ? 1.2 : 1),
        ),
        boxShadow: [
          BoxShadow(
            color: hasError
                ? const Color(0xFFEF4444).withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Number + Title + Icon
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: answer == 'Ya'
                      ? const Color(0xFF0F766E)
                      : answer == 'Tidak'
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF64748B),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${item.number}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: answer == null
                                ? const Color(0xFFF1F5F9)
                                : answer == 'Ya'
                                    ? const Color(0xFFECFDF5)
                                    : const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            answer == null
                                ? 'Belum Diisi *'
                                : (answer == 'Ya' ? 'Pilihan: Ya' : 'Pilihan: Tidak'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: answer == null
                                  ? const Color(0xFF94A3B8)
                                  : (answer == 'Ya'
                                      ? const Color(0xFF059669)
                                      : const Color(0xFFDC2626)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.questionText,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Embedded Context Card for Question 1 (Permit & SIMPER Live Data)
          if (index == 0 && permitInfo != null && simperInfo != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF0F766E)),
                      SizedBox(width: 6),
                      Text(
                        'Ringkasan Validitas Izin Kerja Anda Saat Ini:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '• ${permitInfo.title}: ${permitInfo.nomor} — ${permitInfo.statusBadge}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: permitInfo.statusColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '• ${simperInfo.title}: ${simperInfo.nomor} — ${simperInfo.statusBadge}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: simperInfo.statusColor,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Guidance Box
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline_rounded, size: 15, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.guidance,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF475569),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Radio Selection Ya / Tidak (No default, click required)
          Row(
            children: [
              Expanded(
                child: _buildChoiceChip(
                  label: 'Ya',
                  isSelected: answer == 'Ya',
                  selectedColor: const Color(0xFF10B981),
                  unselectedColor: const Color(0xFFF8FAFC),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _answers[index] = 'Ya';
                      _cardErrors[index] = false;
                      _cardErrorMessages[index] = null;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildChoiceChip(
                  label: 'Tidak',
                  isSelected: answer == 'Tidak',
                  selectedColor: const Color(0xFFDC2626),
                  unselectedColor: const Color(0xFFF8FAFC),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _answers[index] = 'Tidak';
                      _cardErrors[index] = false;
                      _cardErrorMessages[index] = null;
                    });
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Mandatory Penjelasan Field
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text(
                    'Penjelasan / Tindakan Nyata',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF334155),
                    ),
                  ),
                  SizedBox(width: 4),
                  Text(
                    '* (Wajib Diisi)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _noteControllers[index],
                maxLines: 2,
                onChanged: (val) {
                  if (val.trim().isNotEmpty && _cardErrors[index]) {
                    setState(() {
                      _cardErrors[index] = false;
                      _cardErrorMessages[index] = null;
                    });
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Tuliskan penjelasan detail kondisi di lapangan (wajib)...',
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
                    borderSide: BorderSide(
                      color: hasError ? const Color(0xFFEF4444) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.8),
                  ),
                ),
                style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 4),
                Text(
                  errorMessage,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool isSelected,
    required Color selectedColor,
    required Color unselectedColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : unselectedColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? selectedColor : const Color(0xFFCBD5E1),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected
                  ? (label == 'Ya' ? Icons.check_circle_rounded : Icons.cancel_rounded)
                  : Icons.radio_button_unchecked,
              size: 18,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
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
                  'Pernyataan Integritas & Tanda Tangan Digital Karyawan *',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F766E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Saya menyatakan dengan sesungguhnya bahwa seluruh pernyataan, status perizinan, dan jawaban yang saya berikan adalah benar sesuai kondisi aktual pada tanggal ${_displayFormat.format(DateTime.now())}. Saya siap bertanggung jawab penuh atas integritas data ini.',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF0F766E), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSubmitting ? null : _submitForm,
        icon: _isSubmitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : Icon(
                _isExempt ? Icons.check_circle_outline_rounded : Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
        label: Text(
          _isSubmitting
              ? 'Menyimpan Form...'
              : (_isExempt
                  ? 'Simpan Roster & Form Re-Induksi'
                  : 'Kirim Form ke Pengawas & Simpan Roster'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.2,
          ),
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          backgroundColor: const Color(0xFF0F766E),
          disabledBackgroundColor: const Color(0xFF94A3B8),
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
          ),
        ],
      ),
    );
  }
}

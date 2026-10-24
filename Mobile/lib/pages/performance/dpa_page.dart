import 'package:flutter/material.dart';

import '../../models/profile_model.dart';
import '../../services/api.dart';
import '../../services/preference.dart';

class DpaQuestionItem {
  final int id;
  final String category; // 'safety', 'skill', 'behavior', 'service'
  final String question;
  int score;

  DpaQuestionItem({
    required this.id,
    required this.category,
    required this.question,
    this.score = 5,
  });

  String get scoreLabel {
    switch (score) {
      case 5:
        return 'Sangat Baik';
      case 4:
        return 'Baik';
      case 3:
        return 'Cukup';
      case 2:
        return 'Kurang';
      case 1:
        return 'Sangat Kurang';
      default:
        return 'Sangat Baik';
    }
  }

  Color get scoreColor {
    switch (score) {
      case 5:
        return const Color(0xFF10B981);
      case 4:
        return const Color(0xFF0284C7);
      case 3:
        return const Color(0xFF38BDF8);
      case 2:
        return const Color(0xFFF59E0B);
      case 1:
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF10B981);
    }
  }
}

class DpaPage extends StatefulWidget {
  const DpaPage({super.key});

  @override
  State<DpaPage> createState() => _DpaPageState();
}

class _DpaPageState extends State<DpaPage> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  ProfileModel? _profile;

  late TabController _tabController;

  // Form State
  int? _editingId;

  final TextEditingController _driverSearchCtrl = TextEditingController();
  final TextEditingController _ruteCtrl = TextEditingController();
  final TextEditingController _noLambungCtrl = TextEditingController();
  final TextEditingController _keteranganCtrl = TextEditingController();

  String _driverNik = '';
  String _driverNama = '';
  String? _driverDepartemen;

  DateTime _tanggalPenilaian = DateTime.now();
  String _jenisPerjalanan = 'Perjalanan Dinas';

  final List<String> _jenisPerjalananOptions = const [
    'Perjalanan Dinas',
    'Keberangkatan Cuti',
    'Kepulangan Cuti',
    'Operasional Harian',
  ];

  bool _isSearchingDriver = false;
  List<dynamic> _driverSearchResults = [];
  bool _showDriverDropdown = false;

  bool _isSubmitting = false;

  // 10 Standard Questions matching Web MBS_SAP/Controllers/DpaController.cs
  late List<DpaQuestionItem> _safetyQuestions;
  late List<DpaQuestionItem> _skillQuestions;
  late List<DpaQuestionItem> _behaviorQuestions;
  late List<DpaQuestionItem> _serviceQuestions;

  // History State
  bool _isLoadingHistory = true;
  String? _historyErrorMessage;
  List<dynamic> _historyList = [];
  String _historySearchQuery = '';
  final TextEditingController _historySearchCtrl = TextEditingController();
  String _historyScope = 'mine'; // 'mine' (default) or 'all'
  String _selectedCategoryFilter = 'all'; // 'all', 'excellent', 'good', 'satisfactory', 'action'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _profile = PreferenceService.getProfile();
    _initQuestions();
    _loadHistory();
  }

  void _initQuestions() {
    _safetyQuestions = [
      DpaQuestionItem(
        id: 1,
        category: 'safety',
        question: 'Bagaimana kemampuan driver menjaga kecepatan yang aman selama perjalanan?',
      ),
      DpaQuestionItem(
        id: 2,
        category: 'safety',
        question: 'Bagaimana kemampuan driver mengantisipasi kondisi jalan dan potensi bahaya?',
      ),
      DpaQuestionItem(
        id: 3,
        category: 'safety',
        question: 'Bagaimana kemampuan driver melakukan pengereman dan akselerasi secara halus?',
      ),
    ];

    _skillQuestions = [
      DpaQuestionItem(
        id: 1,
        category: 'skill',
        question: 'Bagaimana kemampuan driver menjaga fokus dan konsentrasi selama perjalanan?',
      ),
      DpaQuestionItem(
        id: 2,
        category: 'skill',
        question: 'Bagaimana kemampuan driver mengendalikan kendaraan dalam berbagai kondisi jalan?',
      ),
    ];

    _behaviorQuestions = [
      DpaQuestionItem(
        id: 1,
        category: 'behavior',
        question: 'Bagaimana sikap dan keramahan driver terhadap penumpang?',
      ),
      DpaQuestionItem(
        id: 2,
        category: 'behavior',
        question: 'Bagaimana kemampuan komunikasi driver selama perjalanan?',
      ),
    ];

    _serviceQuestions = [
      DpaQuestionItem(
        id: 1,
        category: 'service',
        question: 'Bagaimana tingkat kebersihan dan kerapihan kendaraan?',
      ),
      DpaQuestionItem(
        id: 2,
        category: 'service',
        question: 'Bagaimana ketepatan waktu driver dalam penjemputan dan pengantaran?',
      ),
      DpaQuestionItem(
        id: 3,
        category: 'service',
        question: 'Bagaimana penilaian Anda terhadap performa driver secara keseluruhan?',
      ),
    ];
  }

  @override
  void dispose() {
    _tabController.dispose();
    _driverSearchCtrl.dispose();
    _ruteCtrl.dispose();
    _noLambungCtrl.dispose();
    _keteranganCtrl.dispose();
    _historySearchCtrl.dispose();
    super.dispose();
  }

  // ==========================================
  // SCORE & CATEGORY CALCULATION
  // ==========================================
  double get _calculatedScore {
    final allQuestions = [
      ..._safetyQuestions,
      ..._skillQuestions,
      ..._behaviorQuestions,
      ..._serviceQuestions,
    ];
    if (allQuestions.isEmpty) return 0.0;
    final total = allQuestions.fold<int>(0, (sum, q) => sum + q.score);
    return double.parse(((total / (allQuestions.length * 5.0)) * 100.0).toStringAsFixed(1));
  }

  String get _calculatedCategory {
    final s = _calculatedScore;
    if (s >= 90) return 'Excellent Driver';
    if (s >= 80) return 'Good Driver';
    if (s >= 70) return 'Satisfactory Driver';
    if (s >= 60) return 'Need Improvement';
    return 'Corrective Action Required';
  }

  Color get _calculatedCategoryColor {
    final s = _calculatedScore;
    if (s >= 90) return const Color(0xFF10B981);
    if (s >= 80) return const Color(0xFF0284C7);
    if (s >= 70) return const Color(0xFFF59E0B);
    if (s >= 60) return const Color(0xFFF97316);
    return const Color(0xFFEF4444);
  }

  // ==========================================
  // DRIVER SEARCH & ADD MANUAL
  // ==========================================
  Future<void> _searchDriver(String query) async {
    if (query.trim().length < 2) {
      setState(() {
        _driverSearchResults = [];
        _showDriverDropdown = false;
      });
      return;
    }

    setState(() => _isSearchingDriver = true);

    final res = await _api.searchDpaDriver(query);

    if (!mounted) return;

    res.fold(
      (err) {
        setState(() {
          _isSearchingDriver = false;
          _driverSearchResults = [];
          _showDriverDropdown = false;
        });
      },
      (data) {
        setState(() {
          _isSearchingDriver = false;
          _driverSearchResults = data;
          _showDriverDropdown = data.isNotEmpty;
        });
      },
    );
  }

  void _selectDriver(dynamic driver) {
    setState(() {
      _driverNik = driver['nik']?.toString() ?? 'MANUAL';
      _driverNama = driver['nama']?.toString() ?? '';
      _driverDepartemen = driver['departemen']?.toString();
      _driverSearchCtrl.text = '$_driverNama (${_driverNik == "MANUAL" ? "Master Driver" : _driverNik})';
      _showDriverDropdown = false;
    });
  }

  void _showAddDriverDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        bool isAdding = false;
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.person_add_rounded, color: Color(0xFF0284C7)),
                  SizedBox(width: 8),
                  Text('Tambah Driver Baru', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Masukkan nama lengkap driver yang belum terdaftar di database perusahaan:',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Nama Lengkap Driver *',
                      hintText: 'Misal: Budi Santoso',
                      prefixIcon: const Icon(Icons.person_rounded, size: 20, color: Color(0xFF0284C7)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isAdding ? null : () => Navigator.pop(ctx),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: isAdding
                      ? null
                      : () async {
                          final name = ctrl.text.trim();
                          if (name.length < 2) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Nama driver minimal 2 karakter.')),
                            );
                            return;
                          }

                          setDlgState(() => isAdding = true);

                          final userNik = _profile?.noNik?.trim() ?? '';
                          final res = await _api.addDpaDriver(name, createdByNik: userNik);

                          if (!mounted) return;

                          res.fold(
                            (err) {
                              setDlgState(() => isAdding = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(err['message']?.toString() ?? 'Gagal menambahkan driver.'),
                                  backgroundColor: const Color(0xFFEF4444),
                                ),
                              );
                            },
                            (resp) {
                              Navigator.pop(ctx);
                              final data = resp['data'] as Map<String, dynamic>? ?? {};
                              _selectDriver(data);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Driver berhasil ditambahkan ke master!'),
                                  backgroundColor: Color(0xFF10B981),
                                ),
                              );
                            },
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isAdding
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Simpan Driver'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================
  // SUBMIT FORM (CREATE / UPDATE)
  // ==========================================
  Future<void> _submitForm() async {
    if (_driverNik.isEmpty || _driverNama.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih atau tambahkan driver terlebih dahulu.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final chosenDate = DateTime(_tanggalPenilaian.year, _tanggalPenilaian.month, _tanggalPenilaian.day);
    if ((_editingId == null || _editingId == 0) && chosenDate.isBefore(today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tanggal Penilaian DPA tidak boleh backdate (kurang dari hari ini).'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final userNik = _profile?.noNik?.trim() ?? '';
    final userName = _profile?.namaLengkap?.trim() ?? 'User Penilai';
    final userDept = _profile?.depart ?? 'General';

    final payload = {
      if (_editingId != null && _editingId! > 0) 'id': _editingId,
      'assessorNik': userNik,
      'assessorNama': userName,
      'assessorDepartemen': userDept,
      'driverNik': _driverNik,
      'driverNama': _driverNama,
      'driverDepartemen': _driverDepartemen,
      'tanggalPenilaian': _tanggalPenilaian.toIso8601String(),
      'jenisPerjalanan': _jenisPerjalanan,
      'rute': _ruteCtrl.text.trim(),
      'noLambung': _noLambungCtrl.text.trim().toUpperCase(),
      'keterangan': _keteranganCtrl.text.trim(),
      'safetyScores': _safetyQuestions.map((q) => {'id': q.id, 'score': q.score, 'label': q.scoreLabel, 'question': q.question}).toList(),
      'skillScores': _skillQuestions.map((q) => {'id': q.id, 'score': q.score, 'label': q.scoreLabel, 'question': q.question}).toList(),
      'behaviorScores': _behaviorQuestions.map((q) => {'id': q.id, 'score': q.score, 'label': q.scoreLabel, 'question': q.question}).toList(),
      'serviceScores': _serviceQuestions.map((q) => {'id': q.id, 'score': q.score, 'label': q.scoreLabel, 'question': q.question}).toList(),
    };

    final res = await _api.saveDpaReport(payload);

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    res.fold(
      (err) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err['message']?.toString() ?? 'Gagal menyimpan penilaian driver.'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      },
      (resp) {
        final isEdit = _editingId != null;
        _cancelEdit();
        _loadHistory();
        _tabController.animateTo(1); // switch to history tab

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 52),
            title: Text(
              isEdit ? 'Penilaian Diperbarui' : 'Penilaian Berhasil Dikirim',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            content: Text(
              'Evaluasi performa driver $_driverNama telah tersimpan ke sistem dengan skor akhir ${resp["scoreFinal"] ?? _calculatedScore} (${resp["kategori"] ?? _calculatedCategory}).',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Tutup'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _cancelEdit() {
    setState(() {
      _editingId = null;
      _driverNik = '';
      _driverNama = '';
      _driverDepartemen = null;
      _driverSearchCtrl.clear();
      _ruteCtrl.clear();
      _noLambungCtrl.clear();
      _keteranganCtrl.clear();
      _tanggalPenilaian = DateTime.now();
      _jenisPerjalanan = 'Perjalanan Dinas';
      _initQuestions();
    });
  }

  void _loadRecordForEdit(dynamic item) {
    setState(() {
      _editingId = item['id'] as int?;
      _driverNik = item['driverNik']?.toString() ?? '';
      _driverNama = item['driverNama']?.toString() ?? '';
      _driverDepartemen = item['driverDepartemen']?.toString();
      _driverSearchCtrl.text = '$_driverNama (${_driverNik == "MANUAL" ? "Master Driver" : _driverNik})';

      try {
        _tanggalPenilaian = DateTime.parse(item['tanggalPenilaian']?.toString() ?? '');
      } catch (_) {
        _tanggalPenilaian = DateTime.now();
      }

      _jenisPerjalanan = item['jenisPerjalanan']?.toString() ?? 'Perjalanan Dinas';
      _ruteCtrl.text = item['rute']?.toString() == '-' ? '' : (item['rute']?.toString() ?? '');
      _noLambungCtrl.text = item['noLambung']?.toString() == '-' ? '' : (item['noLambung']?.toString() ?? '');
      _keteranganCtrl.text = item['keterangan']?.toString() ?? '';

      _tabController.animateTo(0); // switch to form tab
    });

    // Also fetch full detail if question breakdown is needed
    if (_editingId != null) {
      _fetchAndPopulateDetailScores(_editingId!);
    }
  }

  Future<void> _fetchAndPopulateDetailScores(int id) async {
    final res = await _api.getDpaDetail(id);
    if (!mounted) return;
    res.fold(
      (_) {},
      (resp) {
        final data = resp['data'] as Map<String, dynamic>? ?? {};
        setState(() {
          final safety = (data['safety'] as List?) ?? [];
          for (var i = 0; i < safety.length && i < _safetyQuestions.length; i++) {
            _safetyQuestions[i].score = (safety[i]['score'] as num?)?.toInt() ?? 5;
          }

          final skill = (data['skill'] as List?) ?? [];
          for (var i = 0; i < skill.length && i < _skillQuestions.length; i++) {
            _skillQuestions[i].score = (skill[i]['score'] as num?)?.toInt() ?? 5;
          }

          final behavior = (data['behavior'] as List?) ?? [];
          for (var i = 0; i < behavior.length && i < _behaviorQuestions.length; i++) {
            _behaviorQuestions[i].score = (behavior[i]['score'] as num?)?.toInt() ?? 5;
          }

          final service = (data['service'] as List?) ?? [];
          for (var i = 0; i < service.length && i < _serviceQuestions.length; i++) {
            _serviceQuestions[i].score = (service[i]['score'] as num?)?.toInt() ?? 5;
          }
        });
      },
    );
  }

  // ==========================================
  // HISTORY CRUD OPERATIONS
  // ==========================================
  Future<void> _loadHistory() async {
    setState(() {
      _isLoadingHistory = true;
      _historyErrorMessage = null;
    });

    final userNik = _profile?.noNik?.trim() ?? '';
    final queryNik = _historyScope == 'mine' ? (userNik.isNotEmpty ? userNik : null) : 'all';

    final res = await _api.getDpaList(nik: queryNik);

    if (!mounted) return;

    res.fold(
      (err) {
        setState(() {
          _isLoadingHistory = false;
          _historyErrorMessage = err['message']?.toString() ?? 'Gagal memuat histori penilaian DPA.';
        });
      },
      (resp) {
        setState(() {
          _isLoadingHistory = false;
          _historyList = (resp['data'] as List?) ?? [];
        });
      },
    );
  }

  Future<void> _deleteRecord(int id, String driverName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Penilaian Driver?', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text('Apakah Anda yakin ingin menghapus penilaian untuk driver $driverName?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final res = await _api.deleteDpaReport(id);

    if (!mounted) return;

    res.fold(
      (err) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err['message']?.toString() ?? 'Gagal menghapus penilaian.'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      },
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Penilaian driver berhasil dihapus.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        _loadHistory();
      },
    );
  }

  void _showDetailModal(int id) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return FutureBuilder(
          future: _api.getDpaDetail(id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.all(32),
                height: 250,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(color: Color(0xFF0284C7)),
              );
            }

            final res = snapshot.data;
            if (res == null || res.isLeft()) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.all(24),
                child: const Text('Gagal memuat detail penilaian.'),
              );
            }

            final data = res.getOrElse(() => {})['data'] as Map<String, dynamic>? ?? {};

            final safety = (data['safety'] as List?) ?? [];
            final skill = (data['skill'] as List?) ?? [];
            final behavior = (data['behavior'] as List?) ?? [];
            final service = (data['service'] as List?) ?? [];

            final score = (data['scoreFinal'] as num?)?.toDouble() ?? 0.0;
            final category = data['kategori']?.toString() ?? '-';

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(20),
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
              child: ListView(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF0284C7), size: 22),
                          SizedBox(width: 8),
                          Text('Rincian Penilaian DPA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Driver info banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['driverNama']?.toString() ?? '-',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'NIK: ${data['driverNik']} • ${data['driverDepartemen'] ?? "MASTER DRIVER"}',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                        ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Tanggal: ${data['tanggalPenilaianFormatted']}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                            ),
                            Text(
                              'Jenis: ${data['jenisPerjalanan']}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0284C7)),
                            ),
                          ],
                        ),
                        if (data['rute'] != null && data['rute'].toString().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('Rute: ${data['rute']} • Unit: ${data['noLambung'] ?? "-"}', style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Skor: $score / 100',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                category,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF059669)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Question details
                  const Text('Rincian 10 Evaluasi Pertanyaan:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),

                  ...safety.map((q) => _buildDetailQuestionTile(q)),
                  ...skill.map((q) => _buildDetailQuestionTile(q)),
                  ...behavior.map((q) => _buildDetailQuestionTile(q)),
                  ...service.map((q) => _buildDetailQuestionTile(q)),

                  if (data['keterangan'] != null && data['keterangan'].toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Catatan / Feedback Tambahan:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF334155))),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Text(
                        data['keterangan'].toString(),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailQuestionTile(dynamic q) {
    final score = (q['score'] as num?)?.toInt() ?? 5;
    final label = q['label']?.toString() ?? 'Sangat Baik';
    final question = q['question']?.toString() ?? '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '⭐ $score',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF0284C7)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(question, style: const TextStyle(fontSize: 11.5, color: Color(0xFF1E293B), fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
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
              'Driver Performance (DPA)',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Penilaian & Evaluasi Driver • Followup LKS 2026',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF38BDF8),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF94A3B8),
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          tabs: [
            Tab(
              icon: Icon(_editingId != null ? Icons.edit_note_rounded : Icons.speed_rounded, size: 20),
              text: _editingId != null ? 'Edit Penilaian (#$_editingId)' : 'Form Penilaian',
            ),
            Tab(
              icon: const Icon(Icons.history_rounded, size: 20),
              text: 'Histori Penilaian (${_historyList.length})',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Form
          _buildFormTab(),

          // Tab 2: History
          _buildHistoryTab(),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: FORM PENILAIAN DRIVER
  // ==========================================
  Widget _buildFormTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        // LKS Banner Note
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F2FE),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFBAE6FD)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_rounded, color: Color(0xFF0284C7), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Formulir ini digunakan untuk mengevaluasi kompetensi, keselamatan, dan keramahan driver selama perjalanan. Hasil penilaian merupakan tindak lanjut meeting LKS Juni 2026.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF0369A1), height: 1.35, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (_editingId != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF59E0B)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.edit_rounded, color: Color(0xFFD97706), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Mode Edit Penilaian #$_editingId',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _cancelEdit,
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  child: const Text('Batal Edit', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w800, fontSize: 11)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Assessor Info Row (Readonly)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('IDENTITAS PENILAI (ASSESSOR)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5)),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.person_pin_rounded, size: 20, color: Color(0xFF0284C7)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _profile?.namaLengkap ?? 'User Penilai',
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'NIK: ${_profile?.noNik ?? "0000"} • ${_profile?.depart ?? "General"}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Driver Selection Box
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('NAMA DRIVER *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF334155))),
                  ElevatedButton.icon(
                    onPressed: _showAddDriverDialog,
                    icon: const Icon(Icons.add_rounded, size: 15),
                    label: const Text('Add Driver'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Search input
              TextField(
                controller: _driverSearchCtrl,
                onChanged: _searchDriver,
                decoration: InputDecoration(
                  hintText: 'Ketik nama driver untuk mencari...',
                  hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.person_search_rounded, color: Color(0xFF0284C7), size: 20),
                  suffixIcon: _isSearchingDriver
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0284C7))),
                        )
                      : (_driverSearchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 16),
                              onPressed: () {
                                _driverSearchCtrl.clear();
                                setState(() {
                                  _driverNik = '';
                                  _driverNama = '';
                                  _driverDepartemen = null;
                                  _showDriverDropdown = false;
                                });
                              },
                            )
                          : null),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),

              // Dropdown results overlay
              if (_showDriverDropdown && _driverSearchResults.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                    boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 10, offset: Offset(0, 4))],
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _driverSearchResults.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final item = _driverSearchResults[i];
                      return ListTile(
                        dense: true,
                        title: Text(item['nama']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                        subtitle: Text('${item['nik']} • ${item['departemen'] ?? "Driver"}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                        onTap: () => _selectDriver(item),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 4),
              const Text('Pilih dari database atau gunakan tombol Add Driver untuk nama baru.', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Tanggal & Trip Context
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
              const Text('KONTEKS PERJALANAN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF334155), letterSpacing: 0.3)),
              const SizedBox(height: 12),

              // Tanggal Penilaian
              InkWell(
                onTap: () async {
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final initial = _tanggalPenilaian.isBefore(today) ? today : _tanggalPenilaian;
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: initial,
                    firstDate: today, // STRICT: Tidak bisa backdate
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                    helpText: 'PILIH TANGGAL PENILAIAN DPA',
                  );
                  if (picked != null) {
                    setState(() => _tanggalPenilaian = picked);
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF0284C7)),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Tanggal Penilaian *', style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                              Text(
                                '${_tanggalPenilaian.day} ${_monthName(_tanggalPenilaian.month)} ${_tanggalPenilaian.year}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF64748B)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Jenis Perjalanan Dropdown
              DropdownButtonFormField<String>(
                initialValue: _jenisPerjalanan,
                decoration: InputDecoration(
                  labelText: 'Jenis Perjalanan *',
                  labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  prefixIcon: const Icon(Icons.alt_route_rounded, color: Color(0xFF0284C7), size: 20),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                items: _jenisPerjalananOptions
                    .map((opt) => DropdownMenuItem(value: opt, child: Text(opt, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700))))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _jenisPerjalanan = val);
                },
              ),
              const SizedBox(height: 12),

              // Rute & No Lambung Row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ruteCtrl,
                      decoration: InputDecoration(
                        labelText: 'Rute Perjalanan',
                        hintText: 'Misal: Site - BJM',
                        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        prefixIcon: const Icon(Icons.location_on_rounded, color: Color(0xFFEF4444), size: 18),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _noLambungCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: 'No. Lambung',
                        hintText: 'Misal: LV-001',
                        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        prefixIcon: const Icon(Icons.directions_car_rounded, color: Color(0xFF0284C7), size: 18),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Live Score Card Banner
        _buildLiveScoreCard(),
        const SizedBox(height: 16),

        // SECTION 1: Safety & Skill Driving (5 Pertanyaan)
        _buildSectionCard(
          number: 1,
          title: 'Safety & Skill Driving',
          subtitle: 'Kecepatan, antisipasi bahaya, pengereman halus, fokus & pengendalian',
          badgeColor: const Color(0xFFF97316),
          questions: [..._safetyQuestions, ..._skillQuestions],
        ),
        const SizedBox(height: 16),

        // SECTION 2: Behavior & Servis (5 Pertanyaan)
        _buildSectionCard(
          number: 2,
          title: 'Behavior & Servis',
          subtitle: 'Keramahan, komunikasi, kebersihan, ketepatan waktu & performa umum',
          badgeColor: const Color(0xFF6366F1),
          questions: [..._behaviorQuestions, ..._serviceQuestions],
        ),
        const SizedBox(height: 16),

        // Keterangan / Catatan Tambahan
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
              const Text('CATATAN / KOMENTAR TAMBAHAN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF334155), letterSpacing: 0.3)),
              const SizedBox(height: 8),
              TextField(
                controller: _keteranganCtrl,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Tuliskan catatan tambahan mengenai performa driver (opsional)...',
                  hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Submit Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _submitForm,
            icon: _isSubmitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(_editingId != null ? Icons.save_rounded : Icons.send_rounded, size: 20),
            label: Text(
              _isSubmitting
                  ? 'Menyimpan...'
                  : (_editingId != null ? 'PERBARUI PENILAIAN DRIVER' : 'KIRIM PENILAIAN DRIVER'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.5),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLiveScoreCard() {
    final score = _calculatedScore;
    final cat = _calculatedCategory;
    final color = _calculatedCategoryColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.12),
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x060F172A), blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ESTIMASI SKOR PENILAIAN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.4)),
                const SizedBox(height: 4),
                Text(
                  cat,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color),
                ),
                const SizedBox(height: 2),
                const Text('Berdasarkan rata-rata 10 pertanyaan evaluasi', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  score.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                const Text('Skor / 100', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required int number,
    required String title,
    required String subtitle,
    required Color badgeColor,
    required List<DpaQuestionItem> questions,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x060F172A), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                  ),
                  child: Text('$number', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                      Text(subtitle, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Questions List
          ...questions.map((q) => _buildQuestionRow(q)),
        ],
      ),
    );
  }

  Widget _buildQuestionRow(DpaQuestionItem q) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            q.question,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B), height: 1.35),
          ),
          const SizedBox(height: 8),

          // Rating chips (1 to 5)
          Row(
            children: [1, 2, 3, 4, 5].map((val) {
              final isSelected = q.score == val;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: InkWell(
                    onTap: () => setState(() => q.score = val),
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected ? q.scoreColor : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? q.scoreColor : const Color(0xFFE2E8F0),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '⭐ $val',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                          color: isSelected ? Colors.white : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 4),

          // Selected Label Indicator
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Rating: ${q.scoreLabel} (${q.score}/5)',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: q.scoreColor),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: HISTORI PENILAIAN DRIVER
  // ==========================================
  Widget _buildHistoryTab() {
    if (_isLoadingHistory) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF0284C7)),
            const SizedBox(height: 16),
            Text(
              _historyScope == 'mine' ? 'Memuat Riwayat Penilaian Saya...' : 'Memuat Seluruh Evaluasi Driver...',
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
    }

    if (_historyErrorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFEE2E2)),
              boxShadow: const [BoxShadow(color: Color(0x060F172A), blurRadius: 10, offset: Offset(0, 4))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEE2E2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cloud_off_rounded, size: 36, color: Color(0xFFEF4444)),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Koneksi Server DPA Terputus',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 6),
                Text(
                  _historyErrorMessage!,
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: _loadHistory,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Hubungkan Ulang & Coba Lagi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Calculations for KPI Summary
    final totalCount = _historyList.length;
    final avgScore = totalCount > 0
        ? (_historyList.fold<double>(0.0, (sum, item) => sum + ((item['scoreFinal'] as num?)?.toDouble() ?? 0.0)) / totalCount)
        : 0.0;
    final excellentCount = _historyList.where((item) => ((item['scoreFinal'] as num?)?.toDouble() ?? 0.0) >= 90).length;
    final goodCount = _historyList.where((item) {
      final s = ((item['scoreFinal'] as num?)?.toDouble() ?? 0.0);
      return s >= 80 && s < 90;
    }).length;
    final satisfactoryCount = _historyList.where((item) {
      final s = ((item['scoreFinal'] as num?)?.toDouble() ?? 0.0);
      return s >= 70 && s < 80;
    }).length;
    final actionCount = _historyList.where((item) => ((item['scoreFinal'] as num?)?.toDouble() ?? 0.0) < 70).length;

    final excellenceRate = totalCount > 0 ? ((excellentCount / totalCount) * 100).toStringAsFixed(0) : '0';

    // Apply Filter & Search
    List<dynamic> list = List.from(_historyList);

    if (_selectedCategoryFilter == 'excellent') {
      list = list.where((item) => ((item['scoreFinal'] as num?)?.toDouble() ?? 0.0) >= 90).toList();
    } else if (_selectedCategoryFilter == 'good') {
      list = list.where((item) {
        final s = ((item['scoreFinal'] as num?)?.toDouble() ?? 0.0);
        return s >= 80 && s < 90;
      }).toList();
    } else if (_selectedCategoryFilter == 'satisfactory') {
      list = list.where((item) {
        final s = ((item['scoreFinal'] as num?)?.toDouble() ?? 0.0);
        return s >= 70 && s < 80;
      }).toList();
    } else if (_selectedCategoryFilter == 'action') {
      list = list.where((item) => ((item['scoreFinal'] as num?)?.toDouble() ?? 0.0) < 70).toList();
    }

    if (_historySearchQuery.trim().isNotEmpty) {
      final q = _historySearchQuery.toLowerCase().trim();
      list = list.where((item) {
        final name = (item['driverNama'] ?? '').toString().toLowerCase();
        final nik = (item['driverNik'] ?? '').toString().toLowerCase();
        final rute = (item['rute'] ?? '').toString().toLowerCase();
        final unit = (item['noLambung'] ?? '').toString().toLowerCase();
        final jenis = (item['jenisPerjalanan'] ?? '').toString().toLowerCase();
        final assessor = (item['assessorNama'] ?? '').toString().toLowerCase();
        return name.contains(q) || nik.contains(q) || rute.contains(q) || unit.contains(q) || jenis.contains(q) || assessor.contains(q);
      }).toList();
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      color: const Color(0xFF0284C7),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
        children: [
          // ─── 1. Scope Segmented Bar (Penilaian Saya vs Semua Driver) ───
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
                  child: GestureDetector(
                    onTap: () {
                      if (_historyScope != 'mine') {
                        setState(() => _historyScope = 'mine');
                        _loadHistory();
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: _historyScope == 'mine' ? const Color(0xFF0284C7) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _historyScope == 'mine'
                            ? [BoxShadow(color: const Color(0xFF0284C7).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_pin_rounded,
                            size: 16,
                            color: _historyScope == 'mine' ? Colors.white : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Penilaian Saya',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: _historyScope == 'mine' ? Colors.white : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (_historyScope != 'all') {
                        setState(() => _historyScope = 'all');
                        _loadHistory();
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: _historyScope == 'all' ? const Color(0xFF0F172A) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _historyScope == 'all'
                            ? [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.groups_rounded,
                            size: 16,
                            color: _historyScope == 'all' ? Colors.white : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Semua Driver',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: _historyScope == 'all' ? Colors.white : const Color(0xFF64748B),
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

          // ─── 2. Executive KPI Summary Banner ───
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.analytics_rounded, color: Color(0xFF38BDF8), size: 16),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _historyScope == 'mine' ? 'Evaluasi Driver oleh Saya' : 'Statistik Evaluasi Driver Perusahaan',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$totalCount Total',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF38BDF8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Rata-rata Skor', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  avgScore > 0 ? avgScore.toStringAsFixed(1) : '-',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: avgScore >= 90
                                        ? const Color(0xFF10B981)
                                        : (avgScore >= 80 ? const Color(0xFF38BDF8) : const Color(0xFFF59E0B)),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text('pts', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Tingkat Prima', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  '$excellenceRate%',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF10B981)),
                                ),
                                const SizedBox(width: 4),
                                const Text('driver', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Excellent', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                            const SizedBox(height: 2),
                            Text(
                              '$excellentCount Driver',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF38BDF8)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ─── 3. Search Bar & Count ───
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [BoxShadow(color: Color(0x060F172A), blurRadius: 8, offset: Offset(0, 2))],
            ),
            child: TextField(
              controller: _historySearchCtrl,
              onChanged: (val) => setState(() => _historySearchQuery = val),
              decoration: InputDecoration(
                hintText: 'Cari driver, NIK, rute, atau unit lambung...',
                hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                suffixIcon: _historySearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _historySearchCtrl.clear();
                          setState(() => _historySearchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ─── 4. Category Filter Chips ───
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCategoryFilterChip('all', 'Semua (${_historyList.length})', const Color(0xFF0F172A)),
                const SizedBox(width: 6),
                _buildCategoryFilterChip('excellent', 'Excellent ($excellentCount)', const Color(0xFF10B981)),
                const SizedBox(width: 6),
                _buildCategoryFilterChip('good', 'Good ($goodCount)', const Color(0xFF0284C7)),
                const SizedBox(width: 6),
                _buildCategoryFilterChip('satisfactory', 'Satisfactory ($satisfactoryCount)', const Color(0xFFF59E0B)),
                const SizedBox(width: 6),
                _buildCategoryFilterChip('action', 'Need Action ($actionCount)', const Color(0xFFEF4444)),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ─── 5. Assessment Cards List or Empty State ───
          if (list.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [BoxShadow(color: Color(0x060F172A), blurRadius: 8, offset: Offset(0, 2))],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF0F9FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.drive_eta_rounded, size: 40, color: Color(0xFF0284C7)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _historySearchQuery.isNotEmpty
                        ? 'Tidak ada hasil untuk "$_historySearchQuery"'
                        : (_historyScope == 'mine'
                            ? 'Anda belum memiliki riwayat penilaian driver.'
                            : 'Belum ada penilaian driver yang tercatat di sistem.'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _historyScope == 'mine'
                        ? 'Gunakan tab "Form Penilaian" untuk mengevaluasi driver perjalanan Anda sekarang.'
                        : 'Klik tab Form Penilaian untuk mengirim evaluasi baru.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), height: 1.3),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      _tabController.animateTo(0);
                    },
                    icon: const Icon(Icons.add_task_rounded, size: 16),
                    label: const Text('Mulai Penilaian Driver'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    ),
                  ),
                ],
              ),
            )
          else
            ...list.map((item) => _buildHistoryCard(item)),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterChip(String key, String label, Color color) {
    final isSelected = _selectedCategoryFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategoryFilter = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? color : const Color(0xFFCBD5E1)),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2))]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(dynamic item) {
    final int id = item['id'] as int? ?? 0;
    final String driverName = item['driverNama']?.toString() ?? '-';
    final String driverNik = item['driverNik']?.toString() ?? '-';
    final String driverDept = item['driverDepartemen']?.toString() ?? 'OPERASIONAL';
    final String tanggal = item['tanggalPenilaianFormatted']?.toString() ?? (item['tanggalPenilaian']?.toString() ?? '-');
    final String jenis = item['jenisPerjalanan']?.toString() ?? 'Perjalanan Dinas';
    final String rute = item['rute']?.toString() ?? '-';
    final String noLambung = item['noLambung']?.toString() ?? '-';
    final double score = (item['scoreFinal'] as num?)?.toDouble() ?? 0.0;
    final String kategori = item['kategori']?.toString() ?? '-';
    final String? keterangan = item['keterangan']?.toString();
    final String assessorNik = item['assessorNik']?.toString() ?? '';
    final String assessorNama = item['assessorNama']?.toString() ?? 'Penilai';
    final String assessorDept = item['assessorDepartemen']?.toString() ?? 'General';

    final double safetyAvg = (item['safetyAvg'] as num?)?.toDouble() ?? 5.0;
    final double skillAvg = (item['skillAvg'] as num?)?.toDouble() ?? 5.0;
    final double behaviorAvg = (item['behaviorAvg'] as num?)?.toDouble() ?? 5.0;
    final double serviceAvg = (item['serviceAvg'] as num?)?.toDouble() ?? 5.0;

    final userNik = _profile?.noNik?.trim() ?? '';
    final isMine = assessorNik.isNotEmpty && (assessorNik == userNik || userNik == '0002');

    Color badgeColor;
    if (score >= 90) {
      badgeColor = const Color(0xFF10B981);
    } else if (score >= 80) {
      badgeColor = const Color(0xFF0284C7);
    } else if (score >= 70) {
      badgeColor = const Color(0xFFF59E0B);
    } else if (score >= 60) {
      badgeColor = const Color(0xFFF97316);
    } else {
      badgeColor = const Color(0xFFEF4444);
    }

    // Driver Initials
    final nameParts = driverName.trim().split(RegExp(r'\s+'));
    final initials = nameParts.length >= 2
        ? '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase()
        : (nameParts.isNotEmpty && nameParts[0].isNotEmpty ? nameParts[0].substring(0, 1).toUpperCase() : 'DR');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x060F172A), blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Bar with Score Badge & Driver Avatar
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar with score color gradient
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [badgeColor, badgeColor.withValues(alpha: 0.75)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(color: badgeColor.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driverName,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'NIK: $driverNik • $driverDept',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                // Score Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$score pts',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: badgeColor),
                      ),
                      Text(
                        kategori,
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: badgeColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Trip Info Strip
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.alt_route_rounded, size: 14, color: Color(0xFF0284C7)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          rute != '-' && rute.isNotEmpty ? '$rute ($jenis)' : jenis,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (noLambung != '-' && noLambung.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          noLambung,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      tanggal,
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 4-Dimension Mini Rating Meters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                _buildDimensionPill('Safety', safetyAvg, Icons.shield_rounded, const Color(0xFF10B981)),
                const SizedBox(width: 6),
                _buildDimensionPill('Skill', skillAvg, Icons.speed_rounded, const Color(0xFF0284C7)),
                const SizedBox(width: 6),
                _buildDimensionPill('Sikap', behaviorAvg, Icons.favorite_rounded, const Color(0xFFA855F7)),
                const SizedBox(width: 6),
                _buildDimensionPill('Servis', serviceAvg, Icons.star_rounded, const Color(0xFFF59E0B)),
              ],
            ),
          ),

          // Remarks Quote Box (if any)
          if (keterangan != null && keterangan.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFEF3C7)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.format_quote_rounded, size: 14, color: Color(0xFFD97706)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        keterangan,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Footer: Assessor Info & Action Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Oleh: $assessorNama ($assessorDept)',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => _showDetailModal(id),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.visibility_rounded, size: 13, color: Color(0xFF0284C7)),
                            SizedBox(width: 4),
                            Text('Detail', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0284C7))),
                          ],
                        ),
                      ),
                    ),
                    if (isMine) ...[
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => _loadRecordForEdit(item),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.edit_rounded, size: 13, color: Color(0xFFD97706)),
                              SizedBox(width: 4),
                              Text('Edit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFD97706))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                        tooltip: 'Hapus Penilaian',
                        onPressed: () => _deleteRecord(id, driverName),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDimensionPill(String label, double score, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 10, color: color),
                const SizedBox(width: 3),
                Text(
                  label,
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: color),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${score.toStringAsFixed(1)} ★',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: color),
            ),
          ],
        ),
      ),
    );
  }

  String _monthName(int month) {
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    if (month >= 1 && month <= 12) return names[month - 1];
    return '';
  }
}
